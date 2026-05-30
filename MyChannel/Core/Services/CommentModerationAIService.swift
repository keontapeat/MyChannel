import Foundation
import FirebaseAI
import FirebaseFirestore

/// AI-powered service for moderating user comments to ensure they
/// adhere to community guidelines using Firebase Vertex AI.
final class CommentModerationAIService {
    static let shared = CommentModerationAIService()
    
    // Use gemini-1.5-flash for very fast, low-latency text classification
    private lazy var model = FirebaseAI.firebaseAI().generativeModel(
        modelName: "gemini-1.5-flash",
        generationConfig: GenerationConfig(temperature: 0.1) // Low temperature for consistent classification
    )
    
    private init() {}
    
    enum ModerationResult {
        case safe
        case toxic(reason: String)
        case reviewRequired
    }
    
    /// Analyzes a comment to check for toxicity, hate speech, or spam.
    func analyzeComment(text: String) async throws -> ModerationResult {
        let prompt = """
        You are a strict automated content moderator for a video streaming platform.
        Analyze the following comment and determine if it violates community guidelines
        (hate speech, severe toxicity, spam, self-harm, harassment).
        
        Respond ONLY in the following JSON format:
        {
          "isToxic": true/false,
          "reason": "Brief reason if toxic, or null if safe",
          "confidenceScore": 0.0 to 1.0
        }
        
        Comment to analyze:
        "\(text)"
        """
        
        let response = try await model.generateContent(prompt)
        guard let responseText = response.text else {
            return .reviewRequired // Fallback if AI fails to respond
        }
        
        // Strip markdown backticks if Gemini wraps the JSON response
        let cleanedJson = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedJson.data(using: .utf8) else {
            return .reviewRequired
        }
        
        struct ModerationResponse: Decodable {
            let isToxic: Bool
            let reason: String?
            let confidenceScore: Double
        }
        
        do {
            let result = try JSONDecoder().decode(ModerationResponse.self, from: data)
            
            if result.isToxic {
                return .toxic(reason: result.reason ?? "Violates community guidelines")
            } else if result.confidenceScore < 0.7 {
                return .reviewRequired
            } else {
                return .safe
            }
        } catch {
            print("Failed to decode AI moderation response: \(error)")
            return .reviewRequired
        }
    }
    
    /// Processes a new comment before writing to Firestore
    /// Returns true if the comment was published, false if blocked.
    func submitCommentSafe(videoId: String, userId: String, text: String) async -> Bool {
        do {
            let moderation = try await analyzeComment(text: text)
            
            let db = Firestore.firestore()
            let commentData: [String: Any] = [
                "videoId": videoId,
                "userId": userId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            switch moderation {
            case .safe:
                // Instantly publish safe comment
                try await db.collection("videos").document(videoId)
                    .collection("comments").addDocument(data: commentData)
                return true
                
            case .toxic(let reason):
                print("Comment blocked by AI: \(reason)")
                // Optionally log to a 'flagged_comments' collection for auditing
                var flaggedData = commentData
                flaggedData["reason"] = reason
                try await db.collection("flagged_comments").addDocument(data: flaggedData)
                return false
                
            case .reviewRequired:
                print("Comment flagged for manual review.")
                // Save but mark as hidden
                var reviewData = commentData
                reviewData["isHidden"] = true
                reviewData["needsReview"] = true
                try await db.collection("videos").document(videoId)
                    .collection("comments").addDocument(data: reviewData)
                return true // Pretend it published to the user, but it's hidden (shadowban effect)
            }
        } catch {
            print("Error during comment moderation: \(error)")
            return false // Fail safe
        }
    }
}
