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
final class VSMatchComplianceService: ObservableObject {
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
    
    /// Check if user is age-verified for wagering
    func isAgeVerified(userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_compliance").document(userId).getDocument()
            return doc.data()?["ageVerified"] as? Bool ?? false
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    // MARK: - 🆔 KYC (Know Your Customer) Verification
    
    /// Complete KYC verification (ID document upload).
    /// Creates a Stripe Identity VerificationSession via Cloud Function, persists
    /// pending status locally, and returns a client secret the UI can use to present
    /// `IdentityVerificationSheet` once StripeIdentityKit is linked.
    func completeKYC(userId: String, idDocument: IDDocument) async throws -> KYCResult {
        guard idDocument.isValid else {
            throw ComplianceError.invalidDocument
        }

        let session = try await createStripeIdentitySession(userId: userId)

        #if canImport(FirebaseFirestore)
        try await db.collection("vs_match_compliance").document(userId).setData([
            "kycStatus": "pending",
            "kycSubmittedAt": FieldValue.serverTimestamp(),
            "stripeIdentitySessionId": session.sessionId,
            "idDocumentType": idDocument.type.rawValue,
            "idDocumentNumber": idDocument.number,
            "idDocumentCountry": idDocument.country
        ], merge: true)
        #endif

        return KYCResult(
            userId: userId,
            status: .pending,
            submittedAt: Date(),
            stripeIdentityClientSecret: session.clientSecret,
            stripeIdentitySessionId: session.sessionId
        )
    }

    /// Asks the authenticated backend to create a Stripe Identity VerificationSession.
    /// Secret key never leaves the server.
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
            "userId": userId,
            "returnUrl": "mychannel://kyc-complete"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ComplianceError.kycSessionFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(body)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sessionId = json["sessionId"] as? String,
            let clientSecret = json["clientSecret"] as? String,
            !sessionId.isEmpty,
            !clientSecret.isEmpty
        else {
            throw ComplianceError.kycSessionFailed("Malformed Identity session response")
        }

        return StripeIdentitySession(sessionId: sessionId, clientSecret: clientSecret)
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
    
    /// Check if user can create/accept VS match (all compliance checks)
    func canUserWager(userId: String, amount: Double) async throws -> ComplianceCheckResult {
        var errors: [ComplianceError] = []
        
        // 1. Age verification (18+)
        let ageVerified = await isAgeVerified(userId: userId)
        if !ageVerified {
            errors.append(.ageNotVerified)
        }
        
        // 2. KYC verification (for amounts > $500)
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
        
        if !errors.isEmpty {
            throw ComplianceError.multipleErrors(errors)
        }
        
        return ComplianceCheckResult(
            userId: userId,
            isCompliant: true,
            checkedAt: Date()
        )
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
    
    /// Check if user has accepted terms
    func hasAcceptedTerms(userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_compliance").document(userId).getDocument()
            return doc.data()?["termsAccepted"] as? Bool ?? false
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
    
    private func getUserRegion(userId: String) async -> String {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()?["region"] as? String ?? "US-CA"
        } catch {
            return "US-CA"
        }
        #else
        return "US-CA"
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
    /// Present with Stripe IdentityVerificationSheet when StripeIdentityKit is linked.
    var stripeIdentityClientSecret: String? = nil
    var stripeIdentitySessionId: String? = nil
}

struct StripeIdentitySession {
    let sessionId: String
    let clientSecret: String
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
    
    var errorDescription: String? {
        switch self {
        case .underage(let message):
            return message
        case .ageNotVerified:
            return "Age verification required (18+)"
        case .kycRequired:
            return "KYC verification required for wagers over $500"
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

