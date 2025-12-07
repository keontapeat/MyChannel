//
//  RealMLAgentsService.swift
//  MyChannel
//
//  🔥 REAL ML AGENTS CLIENT
//  Calls production ML models via REST API
//
//  Created by Keonta on 11/30/25.
//

import Foundation
import Combine

/// 🔥 Real ML Agents Service - Calls actual trained ML models
@MainActor
final class RealMLAgentsService: ObservableObject {
    static let shared = RealMLAgentsService()
    
    private let baseURL: String
    private let session = URLSession.shared
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {
        // Use Cloud Run URL in production, localhost for development
        #if DEBUG
        self.baseURL = ProcessInfo.processInfo.environment["ML_AGENTS_URL"] ?? "http://localhost:8000"
        #else
        self.baseURL = AppConfig.API.mlAgentsURL ?? "https://ml-agents-xxxxx.run.app"
        #endif
    }
    
    // MARK: - Viral Prediction
    
    struct ViralPredictionRequest: Codable {
        let title: String
        let description: String
        let duration_seconds: Int
        let thumbnail_score: Double
        let creator_subscriber_count: Int
        let creator_avg_views: Double
        let creator_upload_frequency: Double
        let category: String
        let tags: [String]
        let hour_of_day: Int
        let day_of_week: Int
        let is_shorts: Bool
    }
    
    struct ViralPredictionResponse: Codable {
        let viral_probability: Double
        let expected_views_24h: Int
        let expected_views_7d: Int
        let expected_views_30d: Int
        let confidence: Double
        let top_factors: [[String]]
        let recommendations: [String]
    }
    
    /// Predict viral probability for a video
    func predictViral(
        title: String,
        description: String = "",
        durationSeconds: Int,
        thumbnailScore: Double,
        subscriberCount: Int,
        avgViews: Double,
        category: String = "Entertainment",
        tags: [String] = [],
        isShorts: Bool = false
    ) async throws -> ViralPredictionResponse {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1
        
        let request = ViralPredictionRequest(
            title: title,
            description: description,
            duration_seconds: durationSeconds,
            thumbnail_score: thumbnailScore,
            creator_subscriber_count: subscriberCount,
            creator_avg_views: avgViews,
            creator_upload_frequency: 2.0,
            category: category,
            tags: tags,
            hour_of_day: hour,
            day_of_week: weekday,
            is_shorts: isShorts
        )
        
        return try await post("/predict/viral", body: request)
    }
    
    // MARK: - Churn Prediction
    
    struct ChurnPredictionRequest: Codable {
        let user_id: String
        let days_since_signup: Int
        let days_since_last_visit: Int
        let total_watch_time_hours: Double
        let avg_session_duration_minutes: Double
        let sessions_last_7_days: Int
        let sessions_last_30_days: Int
        let videos_watched_last_7_days: Int
        let videos_watched_last_30_days: Int
        let likes_given: Int
        let comments_made: Int
        let shares_made: Int
        let subscriptions_count: Int
        let notifications_enabled: Bool
        let is_premium: Bool
        let premium_days_remaining: Int
        let content_categories_watched: [String]
        let device_types_used: [String]
        let avg_video_completion_rate: Double
        let creator_subscriptions: Int
    }
    
    struct ChurnPredictionResponse: Codable {
        let churn_probability: Double
        let risk_level: String
        let days_until_likely_churn: Int
        let confidence: Double
        let risk_factors: [[String]]
        let retention_actions: [String]
        let predicted_ltv_if_retained: Double
    }
    
    /// Predict churn probability for a user
    func predictChurn(
        userId: String,
        daysSinceSignup: Int,
        daysSinceLastVisit: Int,
        totalWatchTimeHours: Double,
        avgSessionMinutes: Double,
        sessionsLast7Days: Int,
        sessionsLast30Days: Int,
        videosLast7Days: Int,
        videosLast30Days: Int,
        isPremium: Bool = false,
        notificationsEnabled: Bool = true
    ) async throws -> ChurnPredictionResponse {
        let request = ChurnPredictionRequest(
            user_id: userId,
            days_since_signup: daysSinceSignup,
            days_since_last_visit: daysSinceLastVisit,
            total_watch_time_hours: totalWatchTimeHours,
            avg_session_duration_minutes: avgSessionMinutes,
            sessions_last_7_days: sessionsLast7Days,
            sessions_last_30_days: sessionsLast30Days,
            videos_watched_last_7_days: videosLast7Days,
            videos_watched_last_30_days: videosLast30Days,
            likes_given: 0,
            comments_made: 0,
            shares_made: 0,
            subscriptions_count: 0,
            notifications_enabled: notificationsEnabled,
            is_premium: isPremium,
            premium_days_remaining: 0,
            content_categories_watched: [],
            device_types_used: ["iOS"],
            avg_video_completion_rate: 0.5,
            creator_subscriptions: 0
        )
        
        return try await post("/predict/churn", body: request)
    }
    
    // MARK: - Fraud Detection
    
    struct FraudDetectionRequest: Codable {
        let click_id: String
        let timestamp: Double
        let ip_address: String
        let user_agent: String
        let device_type: String
        let os: String
        let browser: String
        let screen_resolution: String
        let timezone: String
        let language: String
        let time_on_page_before_click: Double
        let mouse_movement_entropy: Double
        let scroll_depth_before_click: Double
        let click_position_x: Double
        let click_position_y: Double
        let session_id: String
        let clicks_in_session: Int
        let time_since_session_start: Double
        let pages_visited_in_session: Int
        let clicks_from_ip_last_hour: Int
        let clicks_from_ip_last_day: Int
        let unique_ads_clicked_by_ip: Int
        let conversion_rate_from_ip: Double
        let is_vpn: Bool
        let is_datacenter: Bool
        let is_proxy: Bool
        let ip_reputation_score: Double
    }
    
    struct FraudDetectionResponse: Codable {
        let fraud_probability: Double
        let is_fraud: Bool
        let fraud_type: String
        let confidence: Double
        let risk_score: Double
        let anomaly_score: Double
        let should_block: Bool
        let should_review: Bool
        let fraud_signals: [[String]]
        let recommended_action: String
    }
    
    /// Detect fraud for an ad click
    func detectFraud(
        clickId: String,
        ipAddress: String,
        userAgent: String,
        timeOnPage: Double,
        mouseEntropy: Double,
        scrollDepth: Double,
        clicksFromIP: Int,
        isVPN: Bool = false
    ) async throws -> FraudDetectionResponse {
        let request = FraudDetectionRequest(
            click_id: clickId,
            timestamp: Date().timeIntervalSince1970,
            ip_address: ipAddress,
            user_agent: userAgent,
            device_type: "mobile",
            os: "iOS",
            browser: "Safari",
            screen_resolution: "390x844",
            timezone: TimeZone.current.identifier,
            language: Locale.current.language.languageCode?.identifier ?? "en",
            time_on_page_before_click: timeOnPage,
            mouse_movement_entropy: mouseEntropy,
            scroll_depth_before_click: scrollDepth,
            click_position_x: 0.5,
            click_position_y: 0.5,
            session_id: UUID().uuidString,
            clicks_in_session: 1,
            time_since_session_start: 60,
            pages_visited_in_session: 3,
            clicks_from_ip_last_hour: clicksFromIP,
            clicks_from_ip_last_day: clicksFromIP * 5,
            unique_ads_clicked_by_ip: min(clicksFromIP, 10),
            conversion_rate_from_ip: 0.05,
            is_vpn: isVPN,
            is_datacenter: false,
            is_proxy: false,
            ip_reputation_score: 0.1
        )
        
        return try await post("/predict/fraud", body: request)
    }
    
    // MARK: - Recommendations
    
    struct RecommendationRequest: Codable {
        let user_id: String
        let watched_video_ids: [String]
        let liked_video_ids: [String]
        let watch_time_per_video: [String: Double]
        let subscribed_channels: [String]
        let preferred_categories: [String]
        let preferred_duration: String
        let n_recommendations: Int
        let diversity_weight: Double
    }
    
    struct RecommendationItem: Codable {
        let video_id: String
        let score: Double
        let reason: String
        let predicted_watch_time: Double
    }
    
    struct RecommendationResponse: Codable {
        let recommendations: [RecommendationItem]
        let diversity_score: Double
        let personalization_score: Double
        let cold_start_mode: Bool
    }
    
    /// Get personalized video recommendations
    func getRecommendations(
        userId: String,
        watchedVideos: [String] = [],
        likedVideos: [String] = [],
        preferredCategories: [String] = [],
        count: Int = 20
    ) async throws -> RecommendationResponse {
        let request = RecommendationRequest(
            user_id: userId,
            watched_video_ids: watchedVideos,
            liked_video_ids: likedVideos,
            watch_time_per_video: [:],
            subscribed_channels: [],
            preferred_categories: preferredCategories,
            preferred_duration: "medium",
            n_recommendations: count,
            diversity_weight: 0.2
        )
        
        return try await post("/predict/recommendations", body: request)
    }
    
    // MARK: - Watch Time Prediction
    
    struct WatchTimeRequest: Codable {
        let video_id: String
        let title: String
        let description: String
        let duration_seconds: Int
        let category: String
        let tags: [String]
        let channel_subscriber_count: Int
        let channel_avg_watch_time: Double
        let channel_avg_retention: Double
        let has_intro: Bool
        let has_outro: Bool
        let has_chapters: Bool
        let thumbnail_ctr: Double
        let is_tutorial: Bool
        let is_entertainment: Bool
        let is_news: Bool
        let is_shorts: Bool
        let hour_of_upload: Int
        let day_of_week: Int
    }
    
    struct WatchTimeResponse: Codable {
        let predicted_watch_time_seconds: Int
        let predicted_retention_rate: Double
        let predicted_avg_view_duration: Double
        let confidence: Double
        let retention_curve: [Double]
        let drop_off_points: [[String]]
        let optimization_tips: [String]
    }
    
    /// Predict watch time for a video
    func predictWatchTime(
        videoId: String,
        title: String,
        durationSeconds: Int,
        category: String,
        subscriberCount: Int,
        hasChapters: Bool = false
    ) async throws -> WatchTimeResponse {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1
        
        let request = WatchTimeRequest(
            video_id: videoId,
            title: title,
            description: "",
            duration_seconds: durationSeconds,
            category: category,
            tags: [],
            channel_subscriber_count: subscriberCount,
            channel_avg_watch_time: 180,
            channel_avg_retention: 0.5,
            has_intro: true,
            has_outro: false,
            has_chapters: hasChapters,
            thumbnail_ctr: 0.05,
            is_tutorial: false,
            is_entertainment: true,
            is_news: false,
            is_shorts: durationSeconds < 60,
            hour_of_upload: hour,
            day_of_week: weekday
        )
        
        return try await post("/predict/watch-time", body: request)
    }
    
    // MARK: - Health Check
    
    struct HealthResponse: Codable {
        let status: String
        let timestamp: String
        let models_loaded: [String]
        let version: String
    }
    
    /// Check ML agents service health
    func healthCheck() async throws -> HealthResponse {
        return try await get("/health")
    }
    
    // MARK: - Private Helpers
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw MLAgentsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MLAgentsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw MLAgentsError.apiError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw MLAgentsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MLAgentsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            await MainActor.run {
                lastError = errorMessage
            }
            throw MLAgentsError.apiError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Error Types

enum MLAgentsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(Int)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ML Agents URL"
        case .invalidResponse:
            return "Invalid response from ML Agents"
        case .apiError(let code):
            return "ML Agents error (code: \(code))"
        case .serviceUnavailable:
            return "ML Agents service unavailable"
        }
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
extension RealMLAgentsService {
    /// Mock data for previews
    static var mockViralPrediction: ViralPredictionResponse {
        ViralPredictionResponse(
            viral_probability: 0.75,
            expected_views_24h: 50000,
            expected_views_7d: 250000,
            expected_views_30d: 1000000,
            confidence: 0.85,
            top_factors: [["thumbnail_score", "0.25"], ["is_shorts", "0.20"]],
            recommendations: ["Add more engaging thumbnail", "Post during prime time"]
        )
    }
    
    static var mockChurnPrediction: ChurnPredictionResponse {
        ChurnPredictionResponse(
            churn_probability: 0.35,
            risk_level: "medium",
            days_until_likely_churn: 45,
            confidence: 0.82,
            risk_factors: [["days_since_last_visit", "0.3"], ["session_frequency", "0.25"]],
            retention_actions: ["Send re-engagement email", "Offer premium trial"],
            predicted_ltv_if_retained: 156.00
        )
    }
}
#endif







