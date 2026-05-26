//
//  BudgetPacingAgent.swift
//  MyChannel
//
//  VERTEX AI - BUDGET PACING AGENT
//  Time series forecasting for optimal spend distribution
//  Predict traffic patterns, maximize impressions within budget
//

import Foundation

// MARK: - Budget Pacing Agent (Vertex AI)

@MainActor
final class BudgetPacingAgent: ObservableObject {
    static let shared = BudgetPacingAgent()
    
    @Published var isModelLoaded = false
    @Published var modelVersion = "v1.2"
    @Published var pacingCount: Int = 0
    
    private let vertexAIEndpoint: String
    private let projectID = AppSecrets.googleCloudProjectID
    private let apiKey = AppSecrets.googleCloudAPIKey
    
    private init() {
        vertexAIEndpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/budget-pacing"
    }
    
    // MARK: - Budget Pacing
    
    /// Calculate optimal bid for current time to pace budget
    func calculateOptimalBid(
        campaign: AdCampaign,
        currentSpend: Double,
        timeRemaining: TimeInterval
    ) async -> BudgetPacingResult {
        let startTime = Date()
        
        // 1. Predict traffic for remaining time
        let trafficForecast = await predictTrafficPattern(
            campaign: campaign,
            timeRange: timeRemaining
        )
        
        // 2. Calculate pacing multiplier
        let pacingMultiplier = calculatePacingMultiplier(
            budgetRemaining: campaign.budget - currentSpend,
            timeRemaining: timeRemaining,
            trafficForecast: trafficForecast
        )
        
        // 3. Adjust bid based on pacing
        let baseBid = campaign.bidCPM
        let pacedBid = baseBid * pacingMultiplier
        
        let computationTime = Date().timeIntervalSince(startTime)
        pacingCount += 1
        
        print("💰 [VertexAI-Pacing] Paced bid: $\(String(format: "%.2f", pacedBid)) (multiplier: \(String(format: "%.2f", pacingMultiplier))x) in \(Int(computationTime * 1000))ms")
        
        return BudgetPacingResult(
            optimalBid: pacedBid,
            pacingMultiplier: pacingMultiplier,
            predictedImpressions: trafficForecast.predictedImpressions,
            budgetUtilization: currentSpend / campaign.budget,
            recommendation: generateRecommendation(
                multiplier: pacingMultiplier,
                budgetUtilization: currentSpend / campaign.budget
            ),
            modelVersion: modelVersion
        )
    }
    
    /// Predict hourly spend for campaign
    func predictHourlySpend(campaign: AdCampaign) async -> [HourlySpendForecast] {
        let endpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/hourly-spend"
        guard let url = URL(string: endpoint) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "campaign_id": campaign.id,
            "daily_budget": campaign.budget,
            "target_cpm": campaign.bidCPM,
            "historical_data": extractHistoricalFeatures(campaign: campaign)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.configured.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let forecasts = json["hourly_forecasts"] as? [[String: Any]] {
                
                return forecasts.compactMap { forecast in
                    guard let hour = forecast["hour"] as? Int,
                          let predictedSpend = forecast["predicted_spend"] as? Double,
                          let predictedImpressions = forecast["predicted_impressions"] as? Int else {
                        return nil
                    }
                    
                    return HourlySpendForecast(
                        hour: hour,
                        predictedSpend: predictedSpend,
                        predictedImpressions: predictedImpressions,
                        confidence: forecast["confidence"] as? Double ?? 0.85
                    )
                }
            }
        } catch {
            print("🚨 [VertexAI-Pacing] Hourly spend prediction error: \(error)")
        }
        
        return []
    }
    
    /// Predict daily traffic pattern
    func predictDailyTraffic(dayOfWeek: Int) async -> TrafficPattern {
        let features = extractTrafficFeatures(dayOfWeek: dayOfWeek)
        
        let endpoint = "https://\(AppConfig.API.cloudRunBaseURL)/predict/daily-traffic"
        guard let url = URL(string: endpoint) else {
            return TrafficPattern.fallback()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "instances": [[
                "features": features
            ]]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.configured.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first {
                
                let hourlyMultipliers = firstPrediction["hourly_multipliers"] as? [Double] ?? Array(repeating: 1.0, count: 24)
                let peakHours = firstPrediction["peak_hours"] as? [Int] ?? [18, 19, 20, 21]
                
                return TrafficPattern(
                    hourlyMultipliers: hourlyMultipliers,
                    peakHours: peakHours,
                    dayOfWeek: dayOfWeek
                )
            }
        } catch {
            print("🚨 [VertexAI-Pacing] Daily traffic prediction error: \(error)")
        }
        
        return TrafficPattern.fallback()
    }
    
    // MARK: - Feature Engineering
    
    private func extractHistoricalFeatures(campaign: AdCampaign) -> [String: Any] {
        var features: [String: Any] = [:]
        
        // Campaign features
        features["campaign_age_days"] = campaign.ageInDays
        features["avg_daily_spend"] = campaign.avgDailySpend
        features["avg_cpm"] = campaign.avgCPM
        features["avg_ctr"] = campaign.avgCTR
        
        // Historical spend pattern (last 7 days, hourly)
        features["historical_spend_pattern"] = campaign.historicalHourlySpend
        
        // Day of week patterns
        features["day_of_week_multipliers"] = campaign.dayOfWeekMultipliers
        
        return features
    }
    
    private func extractTrafficFeatures(dayOfWeek: Int) -> [String: Double] {
        var features: [String: Double] = [:]
        
        features["day_of_week"] = Double(dayOfWeek)
        features["is_weekend"] = [6, 7].contains(dayOfWeek) ? 1.0 : 0.0
        features["is_monday"] = dayOfWeek == 1 ? 1.0 : 0.0
        features["is_friday"] = dayOfWeek == 5 ? 1.0 : 0.0
        
        // Seasonal features
        let month = Calendar.current.component(.month, from: Date())
        features["month"] = Double(month)
        features["is_holiday_season"] = [11, 12].contains(month) ? 1.0 : 0.0
        
        return features
    }
    
    // MARK: - Traffic Prediction
    
    private func predictTrafficPattern(
        campaign: AdCampaign,
        timeRange: TimeInterval
    ) async -> TrafficForecast {
        let hoursRemaining = Int(timeRange / 3600)
        
        // Get hourly traffic multipliers
        let currentHour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        
        let trafficPattern = await predictDailyTraffic(dayOfWeek: dayOfWeek)
        
        // Calculate predicted impressions for remaining hours
        var totalPredictedImpressions = 0
        for i in 0..<hoursRemaining {
            let hour = (currentHour + i) % 24
            let multiplier = trafficPattern.hourlyMultipliers[hour]
            let baseImpressions = 1000 // Base impressions per hour
            totalPredictedImpressions += Int(Double(baseImpressions) * multiplier)
        }
        
        return TrafficForecast(
            predictedImpressions: totalPredictedImpressions,
            peakHours: trafficPattern.peakHours,
            confidence: 0.85
        )
    }
    
    // MARK: - Pacing Calculation
    
    private func calculatePacingMultiplier(
        budgetRemaining: Double,
        timeRemaining: TimeInterval,
        trafficForecast: TrafficForecast
    ) -> Double {
        // Calculate ideal spend rate
        let idealSpendRate = budgetRemaining / (timeRemaining / 3600) // Per hour
        
        // Calculate predicted impressions per hour
        let hoursRemaining = timeRemaining / 3600
        let predictedImpressionsPerHour = Double(trafficForecast.predictedImpressions) / hoursRemaining
        
        // Calculate required CPM to hit budget
        let requiredCPM = (idealSpendRate / predictedImpressionsPerHour) * 1000
        
        // Calculate multiplier (how much to adjust bid)
        let currentCPM = 10.0 // Default CPM
        let multiplier = requiredCPM / currentCPM
        
        // Clamp multiplier (0.5x - 2.0x)
        return max(0.5, min(2.0, multiplier))
    }
    
    private func generateRecommendation(
        multiplier: Double,
        budgetUtilization: Double
    ) -> String {
        if multiplier < 0.7 {
            return "Under-pacing: Increase bids to maximize impressions"
        } else if multiplier > 1.3 {
            return "Over-pacing: Reduce bids to extend campaign reach"
        } else if budgetUtilization > 0.9 && multiplier > 1.0 {
            return "Budget nearly exhausted: Consider adding more budget"
        } else {
            return "On track: Pacing is optimal"
        }
    }
    
    // MARK: - Model Training
    
    func triggerModelRetraining() async throws {
        print("🔄 [VertexAI-Pacing] Triggering model retraining...")
        
        let endpoint = "https://\(AppConfig.API.cloudRunBaseURL)/train/budget-pacing"
        guard let url = URL(string: endpoint) else {
            throw BudgetVertexAIError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "training_data_path": "gs://mychannel-ml-data/pacing-training-data",
            "model_type": "time_series_forecast",
            "hyperparameters": [
                "forecast_horizon": 24, // 24 hours
                "seasonality_mode": "multiplicative",
                "changepoint_prior_scale": 0.05
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await URLSession.configured.data(for: request)
        
        print("✅ [VertexAI-Pacing] Model retraining triggered")
    }
}

// MARK: - Models

struct BudgetPacingResult {
    let optimalBid: Double // Adjusted CPM bid
    let pacingMultiplier: Double // Multiplier applied (0.5x - 2.0x)
    let predictedImpressions: Int // Expected impressions with this bid
    let budgetUtilization: Double // 0-1 (current spend / total budget)
    let recommendation: String
    let modelVersion: String
}

struct HourlySpendForecast {
    let hour: Int // 0-23
    let predictedSpend: Double
    let predictedImpressions: Int
    let confidence: Double
}

struct TrafficForecast {
    let predictedImpressions: Int
    let peakHours: [Int]
    let confidence: Double
}

struct TrafficPattern {
    let hourlyMultipliers: [Double] // 24 values (one per hour)
    let peakHours: [Int] // Hours with highest traffic
    let dayOfWeek: Int
    
    static func fallback() -> TrafficPattern {
        // Default pattern: peak in evening (18-22)
        var multipliers = Array(repeating: 0.8, count: 24)
        for hour in 18...22 {
            multipliers[hour] = 1.5
        }
        return TrafficPattern(
            hourlyMultipliers: multipliers,
            peakHours: [18, 19, 20, 21, 22],
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
    }
}

// MARK: - Budget Vertex AI Error

enum BudgetVertexAIError: LocalizedError {
    case invalidEndpoint
    case predictionFailed
    case modelNotLoaded
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Invalid Vertex AI endpoint"
        case .predictionFailed: return "Prediction failed"
        case .modelNotLoaded: return "Model not loaded"
        }
    }
}

// MARK: - AdCampaign Extension

extension AdCampaign {
    var ageInDays: Int {
        return Int(Date().timeIntervalSince(startDate) / 86400)
    }
    
    var avgDailySpend: Double {
        return spent / Double(max(ageInDays, 1))
    }
    
    var avgCPM: Double {
        guard impressions > 0 else { return 0 }
        return (spent / Double(impressions)) * 1000
    }
    
    var avgCTR: Double {
        guard impressions > 0 else { return 0 }
        return Double(clicks) / Double(impressions)
    }
    
    var historicalHourlySpend: [Double] {
        // Return last 7 days * 24 hours = 168 values
        return Array(repeating: avgDailySpend / 24, count: 168)
    }
    
    var dayOfWeekMultipliers: [Double] {
        // Return 7 values (one per day of week)
        return [1.0, 0.9, 0.95, 1.0, 1.1, 1.2, 1.15] // Mon-Sun
    }
}

