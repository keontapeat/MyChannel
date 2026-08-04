//
//  VSMatchComplianceService.swift
//  MyChannel
//
//  💰 ENTERPRISE-LEVEL COMPLIANCE SYSTEM FOR REAL MONEY VS MATCHES
//  Age verification, KYC, legal checks, fraud prevention 🔥
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class VSMatchComplianceService: ObservableObject, ComplianceChecking {
    static let shared = VSMatchComplianceService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    // MARK: - 🔒 AGE VERIFICATION (18+ Required)
    
    /// Verify user is 18+ for real money wagering
    func verifyAgeForWagering(userId: String, dateOfBirth: Date) async throws -> AgeVerificationResult {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        
        guard WagerPolicy.isOfAge(age) else {
            throw ComplianceError.underage("Must be 18+ to wager real money")
        }
        
        #if canImport(FirebaseFirestore)
        // Save age verification
        try await db.collection("vs_match_compliance").document(userId).setData([
            "dateOfBirth": Timestamp(date: dateOfBirth),
            "age": age,
            "ageVerified": true,
            "verifiedAt": FieldValue.serverTimestamp(),
            "verificationMethod": "dateOfBirth"
        ], merge: true)
        #endif
        
        return AgeVerificationResult(
            userId: userId,
            age: age,
            isVerified: true,
            verifiedAt: Date()
        )
    }
    
    /// Check if user is age-verified for wagering.
    /// Reads `ageVerified` from Firestore; also treats approved Stripe Identity KYC as
    /// age-verified because the webhook confirms document DOB server-side.
    func isAgeVerified(userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_compliance").document(userId).getDocument()
            let data = doc.data() ?? [:]
            if data["ageVerified"] as? Bool == true { return true }
            let kyc = data["kycStatus"] as? String ?? ""
            return kyc == KYCStatus.approved.rawValue
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    // MARK: - 🆔 KYC (Know Your Customer) Verification
    
    /// Start KYC via Stripe Identity (document collected in-sheet — no local ID fields required).
    /// Returns session id + ephemeral key for `IdentityVerificationSheet`.
    func startKYCVerification(userId: String) async throws -> KYCResult {
        let session = try await createStripeIdentitySession(userId: userId)

        #if canImport(FirebaseFirestore)
        try await db.collection("vs_match_compliance").document(userId).setData([
            "kycStatus": "pending",
            "kycSubmittedAt": FieldValue.serverTimestamp(),
            "stripeIdentitySessionId": session.sessionId,
            "verificationMethod": "stripe_identity"
        ], merge: true)
        #endif

        return KYCResult(
            userId: userId,
            status: .pending,
            submittedAt: Date(),
            stripeIdentitySessionId: session.sessionId,
            stripeIdentityEphemeralKeySecret: session.ephemeralKeySecret
        )
    }

    /// Legacy entry that starts Stripe Identity without writing document PII to Firestore.
    /// Document numbers must never be stored client-side — Identity holds verified data server-side.
    @available(*, deprecated, message: "Use startKYCVerification — do not collect or persist ID document numbers on device")
    func completeKYC(userId: String, idDocument: IDDocument) async throws -> KYCResult {
        guard idDocument.isValid else {
            throw ComplianceError.invalidDocument
        }
        // Intentionally discard document number/country — Stripe Identity is the source of truth.
        return try await startKYCVerification(userId: userId)
    }

    /// Asks the authenticated backend to create a Stripe Identity VerificationSession
    /// plus an ephemeral key for the iOS SDK. Secret key never leaves the server.
    /// SECURITY: Never log `ephemeralKeySecret` — treat like a password.
    func createStripeIdentitySession(userId: String) async throws -> StripeIdentitySession {
        let base = "https://us-central1-mychannel-ca26d.cloudfunctions.net"
        guard let url = URL(string: "\(base)/create_stripe_identity_session") else {
            throw ComplianceError.kycSessionFailed("Invalid backend URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "userId": userId
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ComplianceError.kycSessionFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(body)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sessionId = json["sessionId"] as? String,
            let ephemeralKeySecret = json["ephemeralKeySecret"] as? String,
            !sessionId.isEmpty,
            !ephemeralKeySecret.isEmpty
        else {
            throw ComplianceError.kycSessionFailed("Malformed Identity session response")
        }

        return StripeIdentitySession(sessionId: sessionId, ephemeralKeySecret: ephemeralKeySecret)
    }
    
    /// Check KYC status
    func getKYCStatus(userId: String) async -> KYCStatus {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_compliance").document(userId).getDocument()
            let statusString = doc.data()?["kycStatus"] as? String ?? "not_started"
            return KYCStatus(rawValue: statusString) ?? .notStarted
        } catch {
            return .notStarted
        }
        #else
        return .notStarted
        #endif
    }
    
    // MARK: - ⚖️ LEGAL COMPLIANCE CHECKS
    
    /// Non-throwing preflight that returns human-readable block reasons for UI surfaces.
    func wagerBlockReasons(userId: String, amount: Double) async -> [String] {
        ComplianceError.aggregatedReasons(from: await collectWagerErrors(userId: userId, amount: amount))
    }

    /// Check if user can create/accept VS match (all compliance checks)
    func canUserWager(userId: String, amount: Double) async throws -> ComplianceCheckResult {
        let errors = await collectWagerErrors(userId: userId, amount: amount)
        if !errors.isEmpty {
            await logWagerComplianceFailure(userId: userId, amount: amount, errors: errors)
            throw ComplianceError.multipleErrors(errors)
        }

        return ComplianceCheckResult(
            userId: userId,
            isCompliant: true,
            checkedAt: Date()
        )
    }

    private func collectWagerErrors(userId: String, amount: Double) async -> [ComplianceError] {
        var errors: [ComplianceError] = []
        
        // 1. Age verification (18+)
        let ageVerified = await isAgeVerified(userId: userId)
        if !ageVerified {
            errors.append(.ageNotVerified)
        }
        
        // 2. KYC verification (for amounts of $500 or more)
        if WagerPolicy.requiresKYC(amountDollars: amount) {
            let kycStatus = await getKYCStatus(userId: userId)
            if kycStatus != .approved {
                errors.append(.kycRequired)
            }
        }
        
        // 3. Terms of Service acceptance
        let tosAccepted = await hasAcceptedTerms(userId: userId)
        if !tosAccepted {
            errors.append(.termsNotAccepted)
        }
        
        // 4. Region check (gambling laws vary by state/country)
        let regionAllowed = await isRegionAllowed(userId: userId)
        if !regionAllowed {
            errors.append(.regionRestricted)
        }
        
        // 5. Account status (not banned/suspended)
        let accountStatus = await getAccountStatus(userId: userId)
        if accountStatus != .active {
            errors.append(.accountSuspended)
        }
        
        // 6. Daily wager limit check
        let dailyWagered = await getDailyWagerAmount(userId: userId)
        let dailyLimit = await getDailyWagerLimit(userId: userId)
        if !WagerPolicy.isWithinDailyLimit(alreadyWagered: dailyWagered, newWager: amount, limit: dailyLimit) {
            errors.append(.dailyLimitExceeded)
        }

        return errors
    }
    
    // MARK: - 📋 TERMS OF SERVICE
    
    /// Accept VS Match Terms of Service
    func acceptTermsOfService(userId: String, version: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("vs_match_compliance").document(userId).setData([
            "termsAccepted": true,
            "termsVersion": version,
            "termsAcceptedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }
    
    /// Check if user has accepted the *current* terms version (stale versions fail closed).
    func hasAcceptedTerms(userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_compliance").document(userId).getDocument()
            let data = doc.data() ?? [:]
            let accepted = data["termsAccepted"] as? Bool ?? false
            let version = data["termsVersion"] as? String ?? ""
            return WagerPolicy.isTermsAcceptanceValid(accepted: accepted, version: version)
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    // MARK: - 🌍 REGION COMPLIANCE
    
    /// Check if user's region allows real money wagering
    func isRegionAllowed(userId: String) async -> Bool {
        // Get user's region from their Firestore profile
        let userRegion = await getUserRegion(userId: userId)
        return WagerPolicy.isRegionAllowed(userRegion)
    }

    /// Persist a US state region code (e.g. `US-CA`) on the user profile.
    func saveUserRegion(userId: String, region: String) async throws {
        let normalized = region.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard WagerPolicy.isRegionAllowed(normalized) else {
            throw ComplianceError.regionRestricted
        }
        #if canImport(FirebaseFirestore)
        try await db.collection("users").document(userId).setData([
            "region": normalized,
            "regionUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }
    
    // MARK: - 🚫 ACCOUNT STATUS
    
    func getAccountStatus(userId: String) async -> AccountStatus {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let statusString = doc.data()?["accountStatus"] as? String ?? "active"
            return AccountStatus(rawValue: statusString) ?? .active
        } catch {
            return .active
        }
        #else
        return .active
        #endif
    }
    
    // MARK: - 💰 WAGER LIMITS
    
    func getDailyWagerLimit(userId: String) async -> Double {
        // Default limits based on account tier
        let accountTier = await getAccountTier(userId: userId)
        return WagerPolicy.dailyLimitDollars(tier: accountTier)
    }
    
    func getDailyWagerAmount(userId: String) async -> Double {
        #if canImport(FirebaseFirestore)
        do {
            // Local start-of-day for UX preview; authoritative gate uses UTC in escrow index.js.
            let today = Calendar.current.startOfDay(for: Date())
            let snapshot = try await db.collection("vs_match_transactions")
                .whereField("userId", isEqualTo: userId)
                .whereField("type", isEqualTo: "wager")
                .whereField("createdAt", isGreaterThan: Timestamp(date: today))
                .getDocuments()
            
            return snapshot.documents.reduce(0.0) { sum, doc in
                sum + (doc.data()["amount"] as? Double ?? 0.0)
            }
        } catch {
            return 0.0
        }
        #else
        return 0.0
        #endif
    }
    
    // MARK: - Helper Functions
    
    /// Returns the user's verified region, or empty when unset (fail closed — never invent US-CA).
    private func getUserRegion(userId: String) async -> String {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return (doc.data()?["region"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
        #else
        return ""
        #endif
    }
    
    /// Writes a denied wager attempt to `compliance_audit_logs` (best-effort, non-blocking).
    private func logWagerComplianceFailure(userId: String, amount: Double, errors: [ComplianceError]) async {
        #if canImport(FirebaseFirestore)
        let reasons = errors.compactMap(\.localizedDescription)
        try? await db.collection("compliance_audit_logs").addDocument(data: [
            "userId": userId,
            "action": "canUserWager_denied",
            "wagerAmount": amount,
            "reasons": reasons,
            "source": "ios",
            "timestamp": FieldValue.serverTimestamp()
        ])
        #endif
    }

    private func getAccountTier(userId: String) async -> AccountTier {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let tierString = doc.data()?["accountTier"] as? String ?? "new"
            return AccountTier(rawValue: tierString) ?? .new
        } catch {
            return .new
        }
        #else
        return .new
        #endif
    }
}

// MARK: - Models

struct AgeVerificationResult {
    let userId: String
    let age: Int
    let isVerified: Bool
    let verifiedAt: Date
}

struct IDDocument {
    let type: DocumentType
    let number: String
    let country: String
    let expirationDate: Date?
    let frontImageURL: String?
    let backImageURL: String?
    
    var isValid: Bool {
        !number.isEmpty && !country.isEmpty
    }
    
    enum DocumentType: String {
        case driversLicense = "drivers_license"
        case passport = "passport"
        case stateId = "state_id"
        case nationalId = "national_id"
    }
}

struct KYCResult {
    let userId: String
    let status: KYCStatus
    let submittedAt: Date
    /// Present with Stripe IdentityVerificationSheet (session id + ephemeral key).
    var stripeIdentitySessionId: String? = nil
    var stripeIdentityEphemeralKeySecret: String? = nil
}

struct StripeIdentitySession {
    let sessionId: String
    let ephemeralKeySecret: String
}

enum KYCStatus: String {
    case notStarted = "not_started"
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case expired = "expired"
}

struct ComplianceCheckResult {
    let userId: String
    let isCompliant: Bool
    let checkedAt: Date
}

enum AccountStatus: String {
    case active = "active"
    case suspended = "suspended"
    case banned = "banned"
    case restricted = "restricted"
}

enum AccountTier: String {
    case new = "new"
    case verified = "verified"
    case premium = "premium"
    case vip = "vip"
}

enum ComplianceError: LocalizedError {
    case underage(String)
    case ageNotVerified
    case kycRequired
    case termsNotAccepted
    case regionRestricted
    case accountSuspended
    case dailyLimitExceeded
    case invalidDocument
    case kycSessionFailed(String)
    case multipleErrors([ComplianceError])

    /// Stable, user-facing reason strings for compliance sheets and alerts.
    static func aggregatedReasons(from errors: [ComplianceError]) -> [String] {
        errors.compactMap { $0.localizedDescription }
    }
    
    var errorDescription: String? {
        switch self {
        case .underage(let message):
            return message
        case .ageNotVerified:
            return "Age verification required (18+)"
        case .kycRequired:
            return "KYC verification required for wagers of $500 or more"
        case .termsNotAccepted:
            return "Terms of Service must be accepted"
        case .regionRestricted:
            return "Real money wagering not available in your region"
        case .accountSuspended:
            return "Account is suspended"
        case .dailyLimitExceeded:
            return "Daily wager limit exceeded"
        case .invalidDocument:
            return "Invalid ID document"
        case .kycSessionFailed(let detail):
            return "KYC session failed: \(detail)"
        case .multipleErrors(let errors):
            return errors.map { $0.localizedDescription ?? "Unknown error" }.joined(separator: ", ")
        }
    }
}

