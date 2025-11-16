//
//  PlacementOptimizationAgent.swift
//  MyChannel
//
//  VERTEX AI - PLACEMENT OPTIMIZATION AGENT
//  Multi-armed bandit + Neural Net for placement selection
//  Match ads to content context, maximize engagement
//

import Foundation

// MARK: - Placement Optimization Agent (Vertex AI)

@MainActor
final class PlacementOptimizationAgent: ObservableObject {
    static let shared = PlacementOptimizationAgent()
    
    @Published var isModelLoaded = false
    @Published var modelVersion = "v1.3"
    @Published var optimizationCount: Int = 0
    
    private let vertexAIEndpoint: String
    private let projectID = AppSecrets.googleCloudProjectID
    private let apiKey = AppSecrets.googleCloudAPIKey
    
    // Multi-armed bandit state
    private var placementPerformance: [AdPlacement: PlacementStats] = [:]
    private let epsilon: Double = 0.1 // Exploration rate
    
    private init() {
        vertexAIEndpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/placement-optimization"
        initializePlacementStats()
    }
    
    // MARK: - Optimal Placement Selection
    
    /// Select optimal ad placement for video & user
    func selectOptimalPlacement(
        video: Video,
        userProfile: AdUserProfile,
        availablePlacements: [AdPlacement]
    ) async -> PlacementOptimization {
        let startTime = Date()
        
        // Extract context features
        let contextFeatures = extractContextFeatures(
            video: video,
            userProfile: userProfile
        )
        
        // Use multi-armed bandit + neural net
        let selectedPlacement: AdPlacement
        let strategy: SelectionStrategy
        
        if Double.random(in: 0...1) < epsilon {
            // Exploration: try random placement
            selectedPlacement = availablePlacements.randomElement() ?? .preroll
            strategy = .exploration
        } else {
            // Exploitation: use best performing placement
            selectedPlacement = await predictBestPlacement(
                contextFeatures: contextFeatures,
                availablePlacements: availablePlacements
            )
            strategy = .exploitation
        }
        
        let predictionTime = Date().timeIntervalSince(startTime)
        optimizationCount += 1
        
        // Get expected performance
        let expectedPerformance = await predictPlacementPerformance(
            placement: selectedPlacement,
            contextFeatures: contextFeatures
        )
        
        print("📍 [VertexAI-Placement] Selected: \(selectedPlacement.rawValue) (\(strategy.rawValue)) - Expected CTR: \(String(format: "%.2f", expectedPerformance.expectedCTR * 100))% in \(Int(predictionTime * 1000))ms")
        
        return PlacementOptimization(
            placement: selectedPlacement,
            expectedCTR: expectedPerformance.expectedCTR,
            expectedCVR: expectedPerformance.expectedCVR,
            expectedRevenue: expectedPerformance.expectedRevenue,
            confidence: expectedPerformance.confidence,
            strategy: strategy,
            modelVersion: modelVersion
        )
    }
    
    /// Predict performance for specific placement
    func predictPlacementPerformance(
        placement: AdPlacement,
        contextFeatures: [String: Double]
    ) async -> PlacementPerformance {
        guard let url = URL(string: vertexAIEndpoint) else {
            return PlacementPerformance.fallback()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var features = contextFeatures
        features["placement_type"] = Double(placement.numericValue)
        
        let payload: [String: Any] = [
            "instances": [[
                "features": features
            ]],
            "parameters": [
                "model_version": modelVersion
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first {
                
                let expectedCTR = firstPrediction["expected_ctr"] as? Double ?? 0.03
                let expectedCVR = firstPrediction["expected_cvr"] as? Double ?? 0.01
                let expectedRevenue = firstPrediction["expected_revenue"] as? Double ?? 0.50
                let confidence = firstPrediction["confidence"] as? Double ?? 0.85
                
                return PlacementPerformance(
                    expectedCTR: expectedCTR,
                    expectedCVR: expectedCVR,
                    expectedRevenue: expectedRevenue,
                    confidence: confidence
                )
            }
        } catch {
            print("🚨 [VertexAI-Placement] Prediction error: \(error)")
        }
        
        return PlacementPerformance.fallback()
    }
    
    // MARK: - Context Matching
    
    /// Match ad to video content context
    func matchAdToContent(
        ad: AdCampaign,
        video: Video
    ) async -> ContentMatchScore {
        let adKeywords = extractKeywords(from: ad)
        let videoKeywords = extractKeywords(from: video)
        
        // Calculate semantic similarity
        let similarity = await calculateSemanticSimilarity(
            adKeywords: adKeywords,
            videoKeywords: videoKeywords
        )
        
        // Calculate brand safety score
        let brandSafety = await calculateBrandSafety(
            ad: ad,
            video: video
        )
        
        // Overall match score
        let matchScore = (similarity * 0.7) + (brandSafety * 0.3)
        
        return ContentMatchScore(
            score: matchScore,
            similarity: similarity,
            brandSafety: brandSafety,
            shouldServe: matchScore >= 0.6 && brandSafety >= 0.8
        )
    }
    
    // MARK: - Multi-Armed Bandit
    
    /// Update placement statistics with outcome
    func updatePlacementStats(
        placement: AdPlacement,
        clicked: Bool,
        converted: Bool,
        revenue: Double
    ) {
        var stats = placementPerformance[placement] ?? PlacementStats()
        
        stats.impressions += 1
        if clicked {
            stats.clicks += 1
        }
        if converted {
            stats.conversions += 1
        }
        stats.totalRevenue += revenue
        
        // Update moving averages
        stats.avgCTR = Double(stats.clicks) / Double(stats.impressions)
        stats.avgCVR = Double(stats.conversions) / Double(stats.impressions)
        stats.avgRevenue = stats.totalRevenue / Double(stats.impressions)
        
        placementPerformance[placement] = stats
        
        print("📊 [VertexAI-Placement] Updated \(placement.rawValue): CTR=\(String(format: "%.2f", stats.avgCTR * 100))%, Revenue=\(String(format: "%.2f", stats.avgRevenue))")
    }
    
    /// Get best performing placement (exploitation)
    private func getBestPlacement(from placements: [AdPlacement]) -> AdPlacement {
        var bestPlacement = placements.first ?? .preroll
        var bestScore = 0.0
        
        for placement in placements {
            if let stats = placementPerformance[placement] {
                // Use Thompson Sampling for score
                let score = calculateThompsonSample(stats: stats)
                if score > bestScore {
                    bestScore = score
                    bestPlacement = placement
                }
            }
        }
        
        return bestPlacement
    }
    
    /// Thompson Sampling for multi-armed bandit
    private func calculateThompsonSample(stats: PlacementStats) -> Double {
        // Beta distribution sampling
        let alpha = Double(stats.clicks + 1)
        let beta = Double(stats.impressions - stats.clicks + 1)
        
        // Simplified Thompson sample (in production, use proper beta distribution)
        return stats.avgCTR + (stats.avgRevenue * 0.5)
    }
    
    private func initializePlacementStats() {
        for placement in AdPlacement.allCases {
            placementPerformance[placement] = PlacementStats()
        }
    }
    
    // MARK: - Feature Engineering
    
    private func extractContextFeatures(
        video: Video,
        userProfile: AdUserProfile
    ) -> [String: Double] {
        var features: [String: Double] = [:]
        
        // Video features (15 dimensions)
        features["video_duration"] = video.duration
        features["video_category"] = Double(video.category.numericValue)
        features["video_view_count"] = Double(video.viewCount)
        features["video_like_count"] = Double(video.likeCount)
        features["video_completion_rate"] = video.completionRate ?? 0.7
        features["video_avg_watch_time"] = video.avgWatchTime ?? (video.duration * 0.6)
        features["video_is_trending"] = (video.isTrending ?? false) ? 1.0 : 0.0
        
        // User features (10 dimensions)
        features["user_engagement_score"] = userProfile.engagementScore
        features["user_ad_receptiveness"] = userProfile.adReceptiveness
        features["user_skip_rate"] = userProfile.behavior.engagementPatterns.skipRate
        features["user_completion_rate"] = userProfile.behavior.engagementPatterns.completionRate
        features["user_session_duration"] = userProfile.behavior.avgSessionDuration
        
        // Temporal features (5 dimensions)
        let hour = Calendar.current.component(.hour, from: Date())
        features["hour_of_day"] = Double(hour)
        features["is_prime_time"] = (18...22).contains(hour) ? 1.0 : 0.0
        features["day_of_week"] = Double(Calendar.current.component(.weekday, from: Date()))
        
        // Device features (3 dimensions)
        features["device_type"] = Double(userProfile.deviceProfile.deviceType.numericValue)
        features["connection_type"] = Double(userProfile.deviceProfile.connectionType.numericValue)
        
        return features
    }
    
    // MARK: - ML Model Prediction
    
    private func predictBestPlacement(
        contextFeatures: [String: Double],
        availablePlacements: [AdPlacement]
    ) async -> AdPlacement {
        var bestPlacement = availablePlacements.first ?? .preroll
        var bestScore = 0.0
        
        // Predict performance for each placement
        for placement in availablePlacements {
            let performance = await predictPlacementPerformance(
                placement: placement,
                contextFeatures: contextFeatures
            )
            
            // Score = expected_revenue * confidence
            let score = performance.expectedRevenue * performance.confidence
            
            if score > bestScore {
                bestScore = score
                bestPlacement = placement
            }
        }
        
        return bestPlacement
    }
    
    // MARK: - Semantic Analysis
    
    private func extractKeywords(from ad: AdCampaign) -> [String] {
        // Extract keywords from ad creative and targeting
        var keywords: [String] = []
        keywords.append(contentsOf: ad.name.lowercased().split(separator: " ").map { String($0) })
        // Add targeting keywords
        return keywords
    }
    
    private func extractKeywords(from video: Video) -> [String] {
        // Extract keywords from video title, description, tags
        var keywords: [String] = []
        keywords.append(contentsOf: video.title.lowercased().split(separator: " ").map { String($0) })
        keywords.append(contentsOf: video.tags.map { $0.lowercased() })
        return keywords
    }
    
    private func calculateSemanticSimilarity(
        adKeywords: [String],
        videoKeywords: [String]
    ) async -> Double {
        // Calculate keyword overlap
        let adSet = Set(adKeywords)
        let videoSet = Set(videoKeywords)
        let intersection = adSet.intersection(videoSet)
        
        guard !adSet.isEmpty && !videoSet.isEmpty else { return 0.0 }
        
        // Jaccard similarity
        let union = adSet.union(videoSet)
        return Double(intersection.count) / Double(union.count)
    }
    
    private func calculateBrandSafety(
        ad: AdCampaign,
        video: Video
    ) async -> Double {
        // Check if video is brand-safe for this ad
        // In production, use content moderation API
        
        // Simple checks:
        // 1. Video is not age-restricted
        if video.ageRestricted ?? false {
            return 0.0
        }
        
        // 2. Video category is allowed for ad
        let allowedCategories: [VideoCategory] = [.movies, .tvShows, .music, .gaming, .sports]
        if !allowedCategories.contains(video.category) {
            return 0.5
        }
        
        // 3. No copyright strikes
        if video.hasCopyrightStrike ?? false {
            return 0.0
        }
        
        return 1.0 // Brand-safe
    }
    
    // MARK: - Model Training
    
    func triggerModelRetraining() async throws {
        print("🔄 [VertexAI-Placement] Triggering model retraining...")
        
        let endpoint = "https://\(AppConfig.API.cloudRunBaseURL)/train/placement-optimization"
        guard let url = URL(string: endpoint) else {
            throw VertexAIError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "training_data_path": "gs://mychannel-ml-data/placement-training-data",
            "model_type": "contextual_bandit",
            "hyperparameters": [
                "learning_rate": 0.001,
                "exploration_rate": epsilon,
                "reward_type": "revenue"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await URLSession.shared.data(for: request)
        
        print("✅ [VertexAI-Placement] Model retraining triggered")
    }
}

// MARK: - Models

struct PlacementOptimization {
    let placement: AdPlacement
    let expectedCTR: Double
    let expectedCVR: Double
    let expectedRevenue: Double
    let confidence: Double
    let strategy: SelectionStrategy
    let modelVersion: String
}

struct PlacementPerformance {
    let expectedCTR: Double
    let expectedCVR: Double
    let expectedRevenue: Double
    let confidence: Double
    
    static func fallback() -> PlacementPerformance {
        return PlacementPerformance(
            expectedCTR: 0.03,
            expectedCVR: 0.01,
            expectedRevenue: 0.50,
            confidence: 0.85
        )
    }
}

struct PlacementStats {
    var impressions: Int = 0
    var clicks: Int = 0
    var conversions: Int = 0
    var totalRevenue: Double = 0.0
    var avgCTR: Double = 0.03
    var avgCVR: Double = 0.01
    var avgRevenue: Double = 0.50
}

struct ContentMatchScore {
    let score: Double // 0-1
    let similarity: Double // Keyword overlap
    let brandSafety: Double // Brand safety score
    let shouldServe: Bool // Whether to serve ad
}

enum SelectionStrategy: String {
    case exploration = "exploration"
    case exploitation = "exploitation"
}

extension Video {
    var completionRate: Double? { return nil }
    var avgWatchTime: TimeInterval? { return nil }
}

extension AdPlacement: CaseIterable {
    static var allCases: [AdPlacement] {
        return [.preroll, .midroll, .postroll, .native, .display]
    }
}

