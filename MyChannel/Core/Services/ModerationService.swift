import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ServiceModerationResult: Codable {
    let contentId: String
    let contentType: ContentType
    let safetyScore: Double // 0.0 = unsafe, 1.0 = safe
    let categories: [ServiceModerationResult.SafetyCategory]
    let action: ServiceModerationAction
    let confidence: Double
    let reviewRequired: Bool
    
    enum ContentType: String, Codable {
        case video, image, text, audio
    }
    
    enum SafetyCategory: String, Codable {
        case spam, hateSpeech, violence, adultContent, harassment
    }
}

enum ServiceModerationAction: String, Codable {
    case allow, review, remove, ageRestrict
}

enum SafetyCategory: String, Codable, CaseIterable {
    case spam, harassment, hateSpeech, violence, sexualContent, childSafety, terrorism, misinformation
    
    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .hateSpeech: return "Hate Speech"
        case .violence: return "Violence"
        case .sexualContent: return "Sexual Content"
        case .childSafety: return "Child Safety"
        case .terrorism: return "Terrorism"
        case .misinformation: return "Misinformation"
        }
    }
}

enum ModerationAction: String, Codable {
    case approve, restrict, remove, humanReview
    
    var displayName: String {
        switch self {
        case .approve: return "Approved"
        case .restrict: return "Restricted"
        case .remove: return "Removed"
        case .humanReview: return "Needs Review"
        }
    }
}

struct ContentFingerprint: Codable {
    let contentId: String
    let pdqHash: String? // Image fingerprint
    let vpdqHash: String? // Video fingerprint
    let audioHash: String? // Audio fingerprint
    let textHash: String? // Text similarity hash
    let createdAt: Date
}

@MainActor
final class ModerationService: ObservableObject {
    static let shared = ModerationService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    func moderateVideo(videoId: String, videoURL: String, thumbnailURL: String, title: String, description: String) async -> ServiceModerationResult {
        // Simulate AI moderation API call
        let safetyScore = await simulateAIModerationScore(content: title + " " + description)
        let categories = await detectCategories(content: title + " " + description)
        
        let action: ServiceModerationAction
        let reviewRequired: Bool
        
        if safetyScore >= 0.9 {
            action = .allow
            reviewRequired = false
        } else if safetyScore >= 0.7 {
            action = .ageRestrict
            reviewRequired = true
        } else if safetyScore >= 0.4 {
            action = .review
            reviewRequired = true
        } else {
            action = .remove
            reviewRequired = false
        }
        
        let result = ServiceModerationResult(
            contentId: videoId,
            contentType: .video,
            safetyScore: safetyScore,
            categories: categories,
            action: ServiceModerationAction.allow,
            confidence: Double.random(in: 0.8...0.99),
            reviewRequired: reviewRequired
        )
        
        // Store moderation result
        await storeServiceModerationResult(result)
        
        // Generate content fingerprint
        let fingerprint = await generateContentFingerprint(videoId: videoId, videoURL: videoURL, thumbnailURL: thumbnailURL)
        await storeContentFingerprint(fingerprint)
        
        return result
    }
    
    func moderateText(contentId: String, text: String) async -> ServiceModerationResult {
        let safetyScore = await simulateAIModerationScore(content: text)
        let categories = await detectCategories(content: text)
        
        let action: ServiceModerationAction = safetyScore >= 0.8 ? .allow : .review
        
        return ServiceModerationResult(
            contentId: contentId,
            contentType: .text,
            safetyScore: safetyScore,
            categories: categories,
            action: action,
            confidence: 0.85,
            reviewRequired: safetyScore < 0.8
        )
    }
    
    func checkCopyrightMatch(fingerprint: ContentFingerprint) async -> [CopyrightMatch] {
        // Simulate copyright database lookup
        if fingerprint.pdqHash?.contains("suspicious") == true {
            return [
                CopyrightMatch(
                    matchId: UUID().uuidString,
                    ownerName: "Example Rights Holder",
                    confidence: 0.92,
                    matchType: .video,
                    claimId: "claim_123",
                    policy: .takedown
                )
            ]
        }
        return []
    }
    
    private func simulateAIModerationScore(content: String) async -> Double {
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let lowercased = content.lowercased()
        var score = 1.0
        
        // Simple keyword-based scoring for demo
        let problematicKeywords = ["spam", "hate", "violence", "explicit"]
        for keyword in problematicKeywords {
            if lowercased.contains(keyword) {
                score -= 0.3
            }
        }
        
        return max(0.0, min(1.0, score + Double.random(in: -0.1...0.1)))
    }
    
    private func detectCategories(content: String) async -> [ServiceModerationResult.SafetyCategory] {
        let lowercased = content.lowercased()
        var categories: [ServiceModerationResult.SafetyCategory] = []
        
        if lowercased.contains("spam") { categories.append(ServiceModerationResult.SafetyCategory.spam) }
        if lowercased.contains("hate") { categories.append(ServiceModerationResult.SafetyCategory.hateSpeech) }
        if lowercased.contains("violence") { categories.append(ServiceModerationResult.SafetyCategory.violence) }
        
        return categories
    }
    
    private func generateContentFingerprint(videoId: String, videoURL: String, thumbnailURL: String) async -> ContentFingerprint {
        // Simulate fingerprint generation
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        return ContentFingerprint(
            contentId: videoId,
            pdqHash: "pdq_\(videoId)_\(Int.random(in: 1000...9999))",
            vpdqHash: "vpdq_\(videoId)_\(Int.random(in: 1000...9999))",
            audioHash: "audio_\(videoId)_\(Int.random(in: 1000...9999))",
            textHash: nil,
            createdAt: Date()
        )
    }
    
    private func storeServiceModerationResult(_ result: ServiceModerationResult) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("moderation_results").document(result.contentId).setData([
                "contentType": result.contentType.rawValue,
                "safetyScore": result.safetyScore,
                "categories": result.categories.map { $0.rawValue },
                "action": result.action.rawValue,
                "confidence": result.confidence,
                "reviewRequired": result.reviewRequired,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    private func storeContentFingerprint(_ fingerprint: ContentFingerprint) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_fingerprints").document(fingerprint.contentId).setData([
                "pdqHash": fingerprint.pdqHash as Any,
                "vpdqHash": fingerprint.vpdqHash as Any,
                "audioHash": fingerprint.audioHash as Any,
                "textHash": fingerprint.textHash as Any,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
}

struct CopyrightMatch: Identifiable, Codable {
    let id = UUID().uuidString
    let matchId: String
    let ownerName: String
    let confidence: Double
    let matchType: MatchType
    let claimId: String
    let policy: Policy
    
    enum MatchType: String, Codable {
        case video, audio, image
    }
    
    enum Policy: String, Codable {
        case takedown, monetize, track
        
        var displayName: String {
            switch self {
            case .takedown: return "Takedown"
            case .monetize: return "Monetize"
            case .track: return "Track"
            }
        }
    }
}

