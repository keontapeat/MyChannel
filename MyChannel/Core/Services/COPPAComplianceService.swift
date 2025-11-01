import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct AgeVerification: Codable {
    let userId: String
    let dateOfBirth: Date?
    let verificationMethod: VerificationMethod
    let parentalConsent: Bool
    let verifiedAt: Date
    let isMinor: Bool
    
    enum VerificationMethod: String, Codable {
        case parentEmail, creditCard, idDocument, thirdParty
    }
}

struct ContentRating: Codable {
    let videoId: String
    let rating: Rating
    let ageGate: Int? // Minimum age required
    let restrictedRegions: [String]
    let coppaCompliant: Bool
    let reviewedBy: String?
    let reviewedAt: Date?
    
    enum Rating: String, Codable, CaseIterable {
        case allAges = "all"
        case teens = "13+"
        case mature = "18+"
        case restricted = "21+"
        
        var displayName: String {
            switch self {
            case .allAges: return "All Ages"
            case .teens: return "13+"
            case .mature: return "18+"
            case .restricted: return "21+"
            }
        }
        
        var minimumAge: Int {
            switch self {
            case .allAges: return 0
            case .teens: return 13
            case .mature: return 18
            case .restricted: return 21
            }
        }
    }
}

@MainActor
final class COPPAComplianceService: ObservableObject {
    static let shared = COPPAComplianceService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    func verifyUserAge(userId: String, dateOfBirth: Date, verificationMethod: AgeVerification.VerificationMethod, parentalConsent: Bool = false) async -> AgeVerification? {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        let isMinor = age < 13
        
        // COPPA requires parental consent for under 13
        if isMinor && !parentalConsent {
            return nil // Cannot proceed without parental consent
        }
        
        let verification = AgeVerification(
            userId: userId,
            dateOfBirth: dateOfBirth,
            verificationMethod: verificationMethod,
            parentalConsent: parentalConsent,
            verifiedAt: Date(),
            isMinor: isMinor
        )
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("age_verifications").document(userId).setData([
                "dateOfBirth": Timestamp(date: dateOfBirth),
                "verificationMethod": verificationMethod.rawValue,
                "parentalConsent": parentalConsent,
                "verifiedAt": FieldValue.serverTimestamp(),
                "isMinor": isMinor
            ])
            
            // Update user document with COPPA flags
            try await db.collection("users").document(userId).setData([
                "ageVerified": true,
                "isMinor": isMinor,
                "parentalConsent": parentalConsent,
                "coppaCompliant": true
            ], merge: true)
        } catch { }
        #endif
        
        return verification
    }
    
    func rateContent(videoId: String, rating: ContentRating.Rating, reviewerId: String? = nil) async -> ContentRating {
        let contentRating = ContentRating(
            videoId: videoId,
            rating: rating,
            ageGate: rating.minimumAge > 0 ? rating.minimumAge : nil,
            restrictedRegions: await getRestrictedRegions(for: rating),
            coppaCompliant: rating == .allAges,
            reviewedBy: reviewerId,
            reviewedAt: reviewerId != nil ? Date() : nil
        )
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_ratings").document(videoId).setData([
                "rating": rating.rawValue,
                "ageGate": contentRating.ageGate as Any,
                "restrictedRegions": contentRating.restrictedRegions,
                "coppaCompliant": contentRating.coppaCompliant,
                "reviewedBy": reviewerId as Any,
                "reviewedAt": reviewerId != nil ? FieldValue.serverTimestamp() : nil,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            // Update video document
            try await db.collection("videos").document(videoId).setData([
                "contentRating": rating.rawValue,
                "ageRestricted": rating.minimumAge > 13,
                "coppaCompliant": contentRating.coppaCompliant
            ], merge: true)
        } catch { }
        #endif
        
        return contentRating
    }
    
    func canUserAccessContent(userId: String?, videoId: String, userRegion: String = "US") async -> Bool {
        // Get content rating
        guard let contentRating = await getContentRating(videoId: videoId) else {
            return false // No rating = restricted by default
        }
        
        // Check region restrictions
        if contentRating.restrictedRegions.contains(userRegion) {
            return false
        }
        
        // Check age requirements
        if let ageGate = contentRating.ageGate, ageGate > 0 {
            guard let userId = userId else { return false } // Age-gated requires login
            
            let userAge = await getUserAge(userId: userId)
            if userAge < ageGate {
                return false
            }
        }
        
        return true
    }
    
    func enableRestrictedMode(userId: String, enabled: Bool, parentalPin: String? = nil) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            var data: [String: Any] = [
                "restrictedModeEnabled": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            if let pin = parentalPin {
                data["parentalPin"] = pin
            }
            
            try await db.collection("users").document(userId).setData(data, merge: true)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func reportCOPPAViolation(videoId: String, reporterId: String?, reason: String, evidence: [String]) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("coppa_reports").document()
            try await ref.setData([
                "videoId": videoId,
                "reporterId": reporterId as Any,
                "reason": reason,
                "evidence": evidence,
                "status": "submitted",
                "submittedAt": FieldValue.serverTimestamp(),
                "priority": "high" // COPPA violations are high priority
            ])
            
            // Immediately age-gate content pending review
            try await db.collection("videos").document(videoId).setData([
                "ageRestricted": true,
                "restrictionReason": "COPPA compliance review",
                "restrictedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    private func getContentRating(videoId: String) async -> ContentRating? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("content_ratings").document(videoId).getDocument()
            guard let data = doc.data() else { return nil }
            
            return ContentRating(
                videoId: videoId,
                rating: ContentRating.Rating(rawValue: data["rating"] as? String ?? "all") ?? .allAges,
                ageGate: data["ageGate"] as? Int,
                restrictedRegions: data["restrictedRegions"] as? [String] ?? [],
                coppaCompliant: data["coppaCompliant"] as? Bool ?? false,
                reviewedBy: data["reviewedBy"] as? String,
                reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue()
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    private func getUserAge(userId: String) async -> Int {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("age_verifications").document(userId).getDocument()
            if let data = doc.data(),
               let dob = (data["dateOfBirth"] as? Timestamp)?.dateValue() {
                return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            }
        } catch { }
        #endif
        return 0 // Default to 0 if age unknown (restrict access)
    }
    
    private func getRestrictedRegions(for rating: ContentRating.Rating) async -> [String] {
        // Different countries have different content policies
        switch rating {
        case .allAges:
            return [] // Available everywhere
        case .teens:
            return ["CN"] // China blocks teen content without local license
        case .mature:
            return ["CN", "SA", "AE", "IN"] // Conservative regions
        case .restricted:
            return ["CN", "SA", "AE", "IN", "PK", "BD"] // Most conservative regions
        }
    }
}


