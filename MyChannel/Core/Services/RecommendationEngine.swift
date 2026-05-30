import Foundation
import FirebaseFirestore

/// Phase 19: Algorithmic Recommendation Engine
/// Uses client-side heuristic scoring based on tag overlap and watch history.
@MainActor
final class RecommendationEngine {
    static let shared = RecommendationEngine()
    private let db = Firestore.firestore()
    
    // Simple mock watch history graph for heuristics
    private var localWatchHistory: [String: Double] = [:] // Video ID -> Watch Time (seconds)
    
    private init() {}
    
    /// Records user watch time for the heuristic model
    func recordWatchActivity(videoId: String, watchTime: Double) {
        let current = localWatchHistory[videoId] ?? 0
        localWatchHistory[videoId] = current + watchTime
    }
    
    /// Scores a list of candidate videos against the current video's category/tags
    /// and the user's recent watch history.
    func getUpNextRecommendations(currentVideo: Video, candidates: [Video], limit: Int = 10) -> [Video] {
        var scoredCandidates: [(video: Video, score: Double)] = []
        
        for candidate in candidates where candidate.id != currentVideo.id {
            var score = 0.0
            
            // 1. Same category boost (Huge weight)
            if candidate.category == currentVideo.category {
                score += 50.0
            }
            
            // 2. Same creator boost
            if candidate.creator.id == currentVideo.creator.id {
                score += 30.0
            }
            
            // 3. Watch history novelty penalty (if already fully watched, penalize heavily)
            let previousWatchTime = localWatchHistory[candidate.id] ?? 0.0
            if previousWatchTime > candidate.duration * 0.9 {
                score -= 100.0 // Likely won't recommend watched content
            } else if previousWatchTime > 0 {
                // partially watched
                score += 10.0
            }
            
            // 4. View count momentum boost
            score += Double(min(candidate.viewCount, 1_000_000)) / 100_000.0 // max +10 points for virality
            
            scoredCandidates.append((candidate, score))
        }
        
        // Sort by score descending and return top `limit`
        let recommendations = scoredCandidates
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.video }
            
        // 🔥 Phase 20: Pre-fetch the top recommendation into RAM
        if let topRec = recommendations.first {
            PlayerPoolManager.shared.preloadNextVideoBytes(urlString: topRec.videoURL)
        }
        
        return recommendations
    }
}
