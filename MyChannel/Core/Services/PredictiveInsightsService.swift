//
//  PredictiveInsightsService.swift
//  MyChannel
//
//  Predictive Insights - AI-powered forecasting
//

import Foundation
import Combine

@MainActor
class PredictiveInsightsService: ObservableObject {
    static let shared = PredictiveInsightsService()
    
    @Published private(set) var forecasts: [Forecast] = []
    @Published private(set) var insights: [PredictiveInsight] = []
    @Published private(set) var recommendations: [Recommendation] = []
    
    struct Forecast: Identifiable, Codable {
        let id: String
        let metric: String
        let currentValue: Double
        let predictedValues: [Double]
        let confidence: Double
        let timeframe: String
        let trend: String
    }
    
    struct PredictiveInsight: Identifiable, Codable {
        let id: String
        let category: String
        let title: String
        let description: String
        let impact: String
        let probability: Double
        let timeframe: String
        let actionable: Bool
    }
    
    struct Recommendation: Identifiable, Codable {
        let id: String
        let priority: String
        let action: String
        let rationale: String
        let expectedImpact: String
        let estimatedEffort: String
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { await self?.refreshInsights() }
        }
        Task { await refreshInsights() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshInsights() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawForecast: Decodable { let id: String; let metric: String; let currentValue: Double; let predictedValues: [Double]; let confidence: Double; let timeframe: String; let trend: String }
        struct RawInsight: Decodable { let id: String; let category: String; let title: String; let description: String; let impact: String; let probability: Double; let timeframe: String; let actionable: Bool }
        struct RawRec: Decodable { let id: String; let priority: String; let action: String; let rationale: String; let expectedImpact: String; let estimatedEffort: String }
        struct Raw: Decodable { let forecasts: [RawForecast]?; let insights: [RawInsight]?; let recommendations: [RawRec]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_predictive_insights"), timeout: 30)
            
            forecasts = (r.forecasts ?? []).map {
                Forecast(
                    id: $0.id,
                    metric: $0.metric,
                    currentValue: $0.currentValue,
                    predictedValues: $0.predictedValues,
                    confidence: $0.confidence,
                    timeframe: $0.timeframe,
                    trend: $0.trend
                )
            }
            
            insights = (r.insights ?? []).map {
                PredictiveInsight(
                    id: $0.id,
                    category: $0.category,
                    title: $0.title,
                    description: $0.description,
                    impact: $0.impact,
                    probability: $0.probability,
                    timeframe: $0.timeframe,
                    actionable: $0.actionable
                )
            }.sorted { $0.probability > $1.probability }
            
            recommendations = (r.recommendations ?? []).map {
                Recommendation(
                    id: $0.id,
                    priority: $0.priority,
                    action: $0.action,
                    rationale: $0.rationale,
                    expectedImpact: $0.expectedImpact,
                    estimatedEffort: $0.estimatedEffort
                )
            }.sorted { $0.priority == "high" && $1.priority != "high" }
            
        } catch {
            print("⚠️ [PredictiveInsights] Error: \(error)")
        }
    }
}
