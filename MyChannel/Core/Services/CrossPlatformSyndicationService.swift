//
//  CrossPlatformSyndicationService.swift
//  MyChannel
//
//  Phase 276: Cross-Platform Syndication Metrics
//  Tracks content syndication across platforms (YouTube, TikTok, Instagram, etc.)
//

import Foundation
import Combine

@MainActor
class CrossPlatformSyndicationService: ObservableObject {
    static let shared = CrossPlatformSyndicationService()
    
    @Published private(set) var syndicationMetrics: [SyndicationMetric] = []
    @Published private(set) var platformPerformance: [PlatformPerformance] = []
    @Published private(set) var totalSyndicatedViews: Double = 0
    @Published private(set) var syndicationRate: Double = 0
    
    struct SyndicationMetric: Identifiable, Codable {
        let id: String
        let contentId: String
        let platforms: [String]
        let totalViews: Double
        let totalRevenue: Double
        let engagementRate: Double
        let lastSyndicated: Date
    }
    
    struct PlatformPerformance: Identifiable, Codable {
        let id: String
        let platform: String
        let contentCount: Int
        let views: Double
        let revenue: Double
        let avgEngagement: Double
        let growthRate: Double
    }
    
    private init() {
        Task { await loadSyndicationData() }
    }
    
    func loadSyndicationData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawMetric: Decodable { let id: String; let contentId: String; let platforms: [String]; let totalViews: Double; let totalRevenue: Double; let engagementRate: Double; let lastSyndicated: String }
        struct RawPlatform: Decodable { let id: String; let platform: String; let contentCount: Int; let views: Double; let revenue: Double; let avgEngagement: Double; let growthRate: Double }
        struct Raw: Decodable { let syndicationMetrics: [RawMetric]?; let platformPerformance: [RawPlatform]?; let totalSyndicatedViews: Double?; let syndicationRate: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
                body: Req(task: "get_syndication_metrics"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            syndicationMetrics = (r.syndicationMetrics ?? []).map {
                SyndicationMetric(
                    id: $0.id,
                    contentId: $0.contentId,
                    platforms: $0.platforms,
                    totalViews: $0.totalViews,
                    totalRevenue: $0.totalRevenue,
                    engagementRate: $0.engagementRate,
                    lastSyndicated: decoder.date(from: $0.lastSyndicated) ?? Date()
                )
            }
            
            platformPerformance = (r.platformPerformance ?? []).map {
                PlatformPerformance(
                    id: $0.id,
                    platform: $0.platform,
                    contentCount: $0.contentCount,
                    views: $0.views,
                    revenue: $0.revenue,
                    avgEngagement: $0.avgEngagement,
                    growthRate: $0.growthRate
                )
            }
            
            totalSyndicatedViews = r.totalSyndicatedViews ?? 0
            syndicationRate = r.syndicationRate ?? 0
            
        } catch {
            print("⚠️ [CrossPlatformSyndication] Error: \(error)")
        }
    }
}
