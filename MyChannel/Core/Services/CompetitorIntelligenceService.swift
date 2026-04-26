//
//  CompetitorIntelligenceService.swift
//  MyChannel
//
//  Competitor Intelligence - Track metrics, content gaps, market share
//

import Foundation
import Combine

@MainActor
class CompetitorIntelligenceService: ObservableObject {
    static let shared = CompetitorIntelligenceService()
    
    @Published private(set) var competitorMetrics: [CompetitorMetric] = []
    @Published private(set) var contentGaps: [ContentGap] = []
    @Published private(set) var marketShare: MarketShareData?
    
    struct CompetitorMetric: Identifiable, Codable {
        let id: String
        let competitorName: String
        let platform: String
        let estimatedUsers: Int
        let contentVolume: Int
        let avgEngagement: Double
        let growthRate: Double
        let strengths: [String]
        let weaknesses: [String]
    }
    
    struct ContentGap: Identifiable, Codable {
        let id: String
        let category: String
        let competitorCoverage: Double
        let ourCoverage: Double
        let opportunityScore: Double
        let suggestedContent: [String]
    }
    
    struct MarketShareData: Codable {
        let ourShare: Double
        let competitorShares: [String: Double]
        let trend: String
        let projectedShare: Double
    }
    
    private init() {
        Task { await loadCompetitorData() }
    }
    
    func loadCompetitorData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawMetric: Decodable { let id: String; let competitorName: String; let platform: String; let estimatedUsers: Int; let contentVolume: Int; let avgEngagement: Double; let growthRate: Double; let strengths: [String]; let weaknesses: [String] }
        struct RawGap: Decodable { let id: String; let category: String; let competitorCoverage: Double; let ourCoverage: Double; let opportunityScore: Double; let suggestedContent: [String] }
        struct RawShare: Decodable { let ourShare: Double; let competitorShares: [String: Double]; let trend: String; let projectedShare: Double }
        struct Raw: Decodable { let competitorMetrics: [RawMetric]?; let contentGaps: [RawGap]?; let marketShare: RawShare? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_competitor_intelligence"), timeout: 30)
            
            competitorMetrics = (r.competitorMetrics ?? []).map {
                CompetitorMetric(
                    id: $0.id,
                    competitorName: $0.competitorName,
                    platform: $0.platform,
                    estimatedUsers: $0.estimatedUsers,
                    contentVolume: $0.contentVolume,
                    avgEngagement: $0.avgEngagement,
                    growthRate: $0.growthRate,
                    strengths: $0.strengths,
                    weaknesses: $0.weaknesses
                )
            }
            
            contentGaps = (r.contentGaps ?? []).map {
                ContentGap(
                    id: $0.id,
                    category: $0.category,
                    competitorCoverage: $0.competitorCoverage,
                    ourCoverage: $0.ourCoverage,
                    opportunityScore: $0.opportunityScore,
                    suggestedContent: $0.suggestedContent
                )
            }.sorted { $0.opportunityScore > $1.opportunityScore }
            
            if let rawShare = r.marketShare {
                marketShare = MarketShareData(
                    ourShare: rawShare.ourShare,
                    competitorShares: rawShare.competitorShares,
                    trend: rawShare.trend,
                    projectedShare: rawShare.projectedShare
                )
            }
            
        } catch {
            print("⚠️ [CompetitorIntelligence] Error: \(error)")
        }
    }
}
