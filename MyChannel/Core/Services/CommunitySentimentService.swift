//
//  CommunitySentimentService.swift
//  MyChannel
//
//  Phase 274: Community Sentiment and Feedback Hub
//  Analyzes community sentiment, feedback trends, NPS scores
//

import Foundation
import Combine

@MainActor
class CommunitySentimentService: ObservableObject {
    static let shared = CommunitySentimentService()
    
    @Published private(set) var sentimentMetrics: [SentimentMetric] = []
    @Published private(set) var overallSentiment: String = "neutral"
    @Published private(set) var npsScore: Double = 0
    @Published private(set) var feedbackTrends: [FeedbackTrend] = []
    
    struct SentimentMetric: Identifiable, Codable {
        let id: String
        let category: String
        let positiveCount: Int
        let negativeCount: Int
        let neutralCount: Int
        let sentimentScore: Double
        let trend: String
    }
    
    struct FeedbackTrend: Identifiable, Codable {
        let id: String
        let topic: String
        let mentions: Int
        let sentiment: String
        let changePercentage: Double
    }
    
    private init() {
        Task { await loadSentimentData() }
    }
    
    func loadSentimentData() async {
        guard AppConfig.Features.enableSentimentHeatmap else { return }
        
        struct Req: Encodable { let task: String }
        struct RawSent: Decodable { let id: String; let category: String; let positiveCount: Int; let negativeCount: Int; let neutralCount: Int; let sentimentScore: Double; let trend: String }
        struct RawTrend: Decodable { let id: String; let topic: String; let mentions: Int; let sentiment: String; let changePercentage: Double }
        struct Raw: Decodable { let sentimentMetrics: [RawSent]?; let overallSentiment: String?; let npsScore: Double?; let feedbackTrends: [RawTrend]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_community_sentiment"), timeout: 30)
            
            sentimentMetrics = (r.sentimentMetrics ?? []).map {
                SentimentMetric(
                    id: $0.id,
                    category: $0.category,
                    positiveCount: $0.positiveCount,
                    negativeCount: $0.negativeCount,
                    neutralCount: $0.neutralCount,
                    sentimentScore: $0.sentimentScore,
                    trend: $0.trend
                )
            }
            
            overallSentiment = r.overallSentiment ?? "neutral"
            npsScore = r.npsScore ?? 0
            
            feedbackTrends = (r.feedbackTrends ?? []).map {
                FeedbackTrend(
                    id: $0.id,
                    topic: $0.topic,
                    mentions: $0.mentions,
                    sentiment: $0.sentiment,
                    changePercentage: $0.changePercentage
                )
            }.sorted { $0.mentions > $1.mentions }
            
        } catch {
            print("⚠️ [CommunitySentiment] Error: \(error)")
        }
    }
}
