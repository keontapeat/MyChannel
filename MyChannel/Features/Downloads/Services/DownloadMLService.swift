import Foundation
import FirebaseAuth

@MainActor
class DownloadMLService: ObservableObject {
    static let shared = DownloadMLService()
    
    @Published var recommendedDownloads: [RecommendedDownload] = []
    @Published var isLoadingRecommendations = false
    
    private let recommendationsURL = "https://recommendations-fkri6ifojq-uc.a.run.app/recommend-downloads"
    private let watchTimePredictorURL = "https://watch-time-predictor-fkri6ifojq-uc.a.run.app/predict-download-value"
    private let feedPersonalizationURL = "https://feed-personalization-fkri6ifojq-uc.a.run.app/personalized-downloads"
    
    private init() {}
    
    func fetchRecommendedDownloads(limit: Int = 10) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        
        do {
            let recommendations = try await fetchFromRecommendationsML(userId: userId, limit: limit)
            let watchTimeScores = try await fetchWatchTimePredictions(for: recommendations, userId: userId)
            let personalizedResults = try await fetchPersonalizedRankings(
                recommendations: recommendations,
                watchTimeScores: watchTimeScores,
                userId: userId
            )
            
            recommendedDownloads = personalizedResults
        } catch {
            print("Error fetching recommended downloads: \(error)")
            recommendedDownloads = []
        }
    }
    
    private func fetchFromRecommendationsML(userId: String, limit: Int) async throws -> [RecommendedDownload] {
        guard let url = URL(string: recommendationsURL) else {
            throw MLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "user_id": userId,
            "limit": limit,
            "context": "downloads",
            "include_offline_suitable": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MLError.invalidResponse
        }
        
        let mlResponse = try JSONDecoder().decode(MLRecommendationsResponse.self, from: data)
        
        return mlResponse.recommendations.map { rec in
            RecommendedDownload(
                videoId: rec.videoId,
                title: rec.title,
                channelName: rec.channelName,
                channelId: rec.channelId,
                thumbnailUrl: rec.thumbnailUrl,
                duration: rec.duration,
                viewCount: rec.viewCount,
                mlScore: rec.score,
                recommendationReason: rec.reason
            )
        }
    }
    
    private func fetchWatchTimePredictions(for recommendations: [RecommendedDownload], userId: String) async throws -> [String: Double] {
        guard let url = URL(string: watchTimePredictorURL) else {
            throw MLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let videoIds = recommendations.map { $0.videoId }
        let requestBody: [String: Any] = [
            "user_id": userId,
            "video_ids": videoIds,
            "context": "download_prediction"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return [:]
        }
        
        let mlResponse = try JSONDecoder().decode(WatchTimePredictionResponse.self, from: data)
        return mlResponse.predictions
    }
    
    private func fetchPersonalizedRankings(recommendations: [RecommendedDownload], 
                                          watchTimeScores: [String: Double],
                                          userId: String) async throws -> [RecommendedDownload] {
        guard let url = URL(string: feedPersonalizationURL) else {
            throw MLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let items = recommendations.map { rec -> [String: Any] in
            return [
                "video_id": rec.videoId,
                "title": rec.title,
                "channel_name": rec.channelName,
                "channel_id": rec.channelId,
                "thumbnail_url": rec.thumbnailUrl,
                "duration": rec.duration,
                "view_count": rec.viewCount,
                "ml_score": rec.mlScore,
                "watch_time_score": watchTimeScores[rec.videoId] ?? 0.5
            ]
        }
        
        let requestBody: [String: Any] = [
            "user_id": userId,
            "items": items,
            "context": "downloads",
            "personalization_factors": [
                "watch_history",
                "download_history",
                "engagement_patterns",
                "offline_viewing_habits"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return recommendations
        }
        
        let mlResponse = try JSONDecoder().decode(PersonalizedRankingResponse.self, from: data)
        
        return mlResponse.rankedItems.map { item in
            RecommendedDownload(
                videoId: item.videoId,
                title: item.title,
                channelName: item.channelName,
                channelId: item.channelId,
                thumbnailUrl: item.thumbnailUrl,
                duration: item.duration,
                viewCount: item.viewCount,
                mlScore: item.personalizedScore,
                recommendationReason: item.reason
            )
        }
    }
}

struct MLRecommendationsResponse: Codable {
    let recommendations: [MLRecommendation]
}

struct MLRecommendation: Codable {
    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let score: Double
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case title
        case channelName = "channel_name"
        case channelId = "channel_id"
        case thumbnailUrl = "thumbnail_url"
        case duration
        case viewCount = "view_count"
        case score
        case reason
    }
}

struct WatchTimePredictionResponse: Codable {
    let predictions: [String: Double]
}

struct PersonalizedRankingResponse: Codable {
    let rankedItems: [PersonalizedItem]
    
    enum CodingKeys: String, CodingKey {
        case rankedItems = "ranked_items"
    }
}

struct PersonalizedItem: Codable {
    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let personalizedScore: Double
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case title
        case channelName = "channel_name"
        case channelId = "channel_id"
        case thumbnailUrl = "thumbnail_url"
        case duration
        case viewCount = "view_count"
        case personalizedScore = "personalized_score"
        case reason
    }
}

enum MLError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ML service URL"
        case .invalidResponse:
            return "Invalid response from ML service"
        case .decodingError:
            return "Failed to decode ML response"
        }
    }
}
