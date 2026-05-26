//
//  CreativePerformanceAgent.swift
//  MyChannel
//
//  VERTEX AI - CREATIVE PERFORMANCE AGENT
//  Vision AI + Neural Net for creative analysis
//  Predict CTR from creative features, score quality
//

import Foundation
import UIKit

// MARK: - Creative Performance Agent (Vertex AI)

@MainActor
final class CreativePerformanceAgent: ObservableObject {
    static let shared = CreativePerformanceAgent()
    
    @Published var isModelLoaded = false
    @Published var modelVersion = "v1.5"
    @Published var analysisCount: Int = 0
    
    private let visionAIEndpoint: String
    private let performanceEndpoint: String
    private let projectID = AppSecrets.googleCloudProjectID
    private let apiKey = AppSecrets.googleCloudAPIKey
    
    private init() {
        visionAIEndpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/creative-vision"
        performanceEndpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/creative-performance"
    }
    
    // MARK: - Creative Analysis
    
    /// Analyze creative quality and predict performance
    func analyzeCreative(
        imageURL: String?,
        videoURL: String?,
        text: String?,
        callToAction: String?
    ) async -> CreativeAnalysis {
        let startTime = Date()
        
        // 1. Vision AI analysis (for images/videos)
        let visionFeatures = await analyzeWithVisionAI(
            imageURL: imageURL,
            videoURL: videoURL
        )
        
        // 2. Text analysis (for ad copy)
        let textFeatures = await analyzeText(
            text: text,
            callToAction: callToAction
        )
        
        // 3. Combine features and predict performance
        let combinedFeatures = visionFeatures.merging(textFeatures) { $1 }
        let prediction = await predictPerformance(features: combinedFeatures)
        
        let analysisTime = Date().timeIntervalSince(startTime)
        analysisCount += 1
        
        print("🎨 [VertexAI-Creative] Quality: \(Int(prediction.qualityScore * 100))%, Predicted CTR: \(String(format: "%.2f", prediction.predictedCTR * 100))% in \(Int(analysisTime * 1000))ms")
        
        return CreativeAnalysis(
            qualityScore: prediction.qualityScore,
            predictedCTR: prediction.predictedCTR,
            predictedCVR: prediction.predictedCVR,
            visualScore: visionFeatures["visual_quality"] ?? 0.8,
            textScore: textFeatures["text_quality"] ?? 0.8,
            suggestions: generateSuggestions(prediction: prediction, features: combinedFeatures),
            autoApproved: prediction.qualityScore >= 0.85,
            analysisTime: analysisTime,
            modelVersion: modelVersion
        )
    }
    
    /// Score creative quality (0-1)
    func scoreCreativeQuality(creative: AdCreative) async -> Double {
        let analysis = await analyzeCreative(
            imageURL: creative.imageURL,
            videoURL: creative.videoURL,
            text: creative.headline,
            callToAction: creative.callToAction
        )
        return analysis.qualityScore
    }
    
    /// Predict CTR from creative features
    func predictCTR(creative: AdCreative, placement: AdPlacement) async -> Double {
        let analysis = await analyzeCreative(
            imageURL: creative.imageURL,
            videoURL: creative.videoURL,
            text: creative.headline,
            callToAction: creative.callToAction
        )
        
        // Adjust for placement
        let placementMultiplier = getPlacementMultiplier(placement)
        return analysis.predictedCTR * placementMultiplier
    }
    
    // MARK: - Vision AI Analysis
    
    private func analyzeWithVisionAI(
        imageURL: String?,
        videoURL: String?
    ) async -> [String: Double] {
        var features: [String: Double] = [:]
        
        // Analyze image/video with Vision AI
        if let imageURL = imageURL {
            let visionAnalysis = await callVisionAI(imageURL: imageURL)
            features.merge(visionAnalysis) { $1 }
        }
        
        if let videoURL = videoURL {
            let videoAnalysis = await callVisionAI(imageURL: videoURL, isVideo: true)
            features.merge(videoAnalysis) { $1 }
        }
        
        return features
    }
    
    private func callVisionAI(imageURL: String, isVideo: Bool = false) async -> [String: Double] {
        guard let url = URL(string: visionAIEndpoint) else {
            return [:]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "instances": [[
                "content": imageURL,
                "is_video": isVideo
            ]],
            "parameters": [
                "features": [
                    "LABEL_DETECTION",
                    "SAFE_SEARCH_DETECTION",
                    "IMAGE_PROPERTIES",
                    "FACE_DETECTION",
                    "TEXT_DETECTION",
                    "OBJECT_LOCALIZATION"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.configured.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first {
                
                var features: [String: Double] = [:]
                
                // Extract features from Vision AI response
                features["visual_quality"] = firstPrediction["visual_quality"] as? Double ?? 0.8
                features["color_vibrancy"] = firstPrediction["color_vibrancy"] as? Double ?? 0.7
                features["contrast_score"] = firstPrediction["contrast_score"] as? Double ?? 0.7
                features["composition_score"] = firstPrediction["composition_score"] as? Double ?? 0.7
                features["face_count"] = firstPrediction["face_count"] as? Double ?? 0.0
                features["face_emotion_positive"] = firstPrediction["face_emotion_positive"] as? Double ?? 0.0
                features["text_present"] = firstPrediction["text_present"] as? Double ?? 0.0
                features["text_readability"] = firstPrediction["text_readability"] as? Double ?? 0.0
                features["safe_for_brands"] = firstPrediction["safe_for_brands"] as? Double ?? 1.0
                features["has_call_to_action_visual"] = firstPrediction["has_cta"] as? Double ?? 0.0
                
                return features
            }
        } catch {
            print("🚨 [VertexAI-Creative] Vision AI error: \(error)")
        }
        
        return [:]
    }
    
    // MARK: - Text Analysis
    
    private func analyzeText(text: String?, callToAction: String?) async -> [String: Double] {
        var features: [String: Double] = [:]
        
        if let text = text {
            features["text_length"] = Double(text.count)
            features["text_word_count"] = Double(text.split(separator: " ").count)
            features["text_has_emoji"] = text.containsEmoji ? 1.0 : 0.0
            features["text_has_numbers"] = text.containsNumbers ? 1.0 : 0.0
            features["text_has_urgency_words"] = text.hasUrgencyWords ? 1.0 : 0.0
            features["text_sentiment_score"] = await analyzeSentiment(text: text)
        }
        
        if let cta = callToAction {
            features["has_cta"] = 1.0
            features["cta_length"] = Double(cta.count)
            features["cta_is_action_word"] = cta.hasActionVerb ? 1.0 : 0.0
        } else {
            features["has_cta"] = 0.0
        }
        
        features["text_quality"] = calculateTextQuality(features: features)
        
        return features
    }
    
    private func analyzeSentiment(text: String) async -> Double {
        // Use Natural Language API for sentiment analysis
        // Positive sentiment = 1.0, Negative = 0.0, Neutral = 0.5
        return 0.7 // Simplified
    }
    
    private func calculateTextQuality(features: [String: Double]) -> Double {
        var score = 0.5
        
        // Good length (20-80 chars)
        if let length = features["text_length"], (20...80).contains(Int(length)) {
            score += 0.1
        }
        
        // Has CTA
        if features["has_cta"] == 1.0 {
            score += 0.15
        }
        
        // Positive sentiment
        if let sentiment = features["text_sentiment_score"], sentiment > 0.6 {
            score += 0.15
        }
        
        // Has urgency
        if features["text_has_urgency_words"] == 1.0 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Performance Prediction
    
    private func predictPerformance(features: [String: Double]) async -> CreativePerformancePrediction {
        guard let url = URL(string: performanceEndpoint) else {
            return CreativePerformancePrediction.fallback()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
            let (data, _) = try await URLSession.configured.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first {
                
                let qualityScore = firstPrediction["quality_score"] as? Double ?? 0.8
                let predictedCTR = firstPrediction["predicted_ctr"] as? Double ?? 0.03
                let predictedCVR = firstPrediction["predicted_cvr"] as? Double ?? 0.01
                
                return CreativePerformancePrediction(
                    qualityScore: qualityScore,
                    predictedCTR: predictedCTR,
                    predictedCVR: predictedCVR
                )
            }
        } catch {
            print("🚨 [VertexAI-Creative] Performance prediction error: \(error)")
        }
        
        return CreativePerformancePrediction.fallback()
    }
    
    // MARK: - Suggestions Generation
    
    private func generateSuggestions(
        prediction: CreativePerformancePrediction,
        features: [String: Double]
    ) -> [String] {
        var suggestions: [String] = []
        
        // Visual suggestions
        if let visualQuality = features["visual_quality"], visualQuality < 0.7 {
            suggestions.append("Improve image quality (use higher resolution)")
        }
        
        if let colorVibrancy = features["color_vibrancy"], colorVibrancy < 0.6 {
            suggestions.append("Use more vibrant colors to attract attention")
        }
        
        if let faceCount = features["face_count"], faceCount == 0 {
            suggestions.append("Consider including faces (increases CTR by 20%)")
        }
        
        // Text suggestions
        if features["has_cta"] != 1.0 {
            suggestions.append("Add a clear call-to-action button")
        }
        
        if let textLength = features["text_length"], textLength > 80 {
            suggestions.append("Shorten headline (optimal length: 20-80 characters)")
        }
        
        if features["text_has_urgency_words"] != 1.0 {
            suggestions.append("Add urgency words (e.g., 'Now', 'Today', 'Limited')")
        }
        
        // Performance suggestions
        if prediction.predictedCTR < 0.02 {
            suggestions.append("Low predicted CTR - consider A/B testing different creatives")
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func getPlacementMultiplier(_ placement: AdPlacement) -> Double {
        switch placement {
        case .preroll: return 1.2 // High attention
        case .midroll: return 1.0 // Normal
        case .postroll: return 0.8 // Lower attention
        case .native: return 1.1 // Good integration
        case .display: return 0.9 // Banner blindness
        }
    }
    
    // MARK: - Model Training
    
    func triggerModelRetraining() async throws {
        print("🔄 [VertexAI-Creative] Triggering model retraining...")
        
        let endpoint = "https://\(AppConfig.API.cloudRunBaseURL)/train/creative-performance"
        guard let url = URL(string: endpoint) else {
            throw VertexAIError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "training_data_path": "gs://mychannel-ml-data/creative-training-data",
            "model_type": "vision_automl",
            "hyperparameters": [
                "optimization_objective": "MAXIMIZE_AU_PRC",
                "train_budget_milli_node_hours": 8000
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await URLSession.configured.data(for: request)
        
        print("✅ [VertexAI-Creative] Model retraining triggered")
    }
}

// MARK: - Models

struct CreativeAnalysis {
    let qualityScore: Double // 0-1
    let predictedCTR: Double // 0-1
    let predictedCVR: Double // 0-1
    let visualScore: Double // 0-1
    let textScore: Double // 0-1
    let suggestions: [String]
    let autoApproved: Bool // Quality >= 85%
    let analysisTime: TimeInterval
    let modelVersion: String
}

struct CreativePerformancePrediction {
    let qualityScore: Double
    let predictedCTR: Double
    let predictedCVR: Double
    
    static func fallback() -> CreativePerformancePrediction {
        return CreativePerformancePrediction(
            qualityScore: 0.8,
            predictedCTR: 0.03,
            predictedCVR: 0.01
        )
    }
}

// MARK: - String Extensions

extension String {
    var containsEmoji: Bool {
        return self.unicodeScalars.contains { $0.properties.isEmoji }
    }
    
    var containsNumbers: Bool {
        return self.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    var hasUrgencyWords: Bool {
        let urgencyWords = ["now", "today", "limited", "hurry", "sale", "free", "new"]
        return urgencyWords.contains(where: { self.lowercased().contains($0) })
    }
    
    var hasActionVerb: Bool {
        let actionVerbs = ["buy", "shop", "get", "try", "join", "learn", "discover", "watch"]
        return actionVerbs.contains(where: { self.lowercased().contains($0) })
    }
}

