//
//  RegionalPerformanceService.swift
//  MyChannel
//
//  Phase 269: Regional Performance Breakdown
//  Analyzes performance metrics by region, country, locale
//

import Foundation
import Combine

@MainActor
class RegionalPerformanceService: ObservableObject {
    static let shared = RegionalPerformanceService()
    
    @Published private(set) var regionalMetrics: [RegionalMetric] = []
    @Published private(set) var topRegions: [RegionalMetric] = []
    @Published private(set) var underperformingRegions: [RegionalMetric] = []
    
    struct RegionalMetric: Identifiable, Codable {
        let id: String
        let region: String
        let countryCode: String
        let userCount: Int
        let activeUsers: Int
        let avgSessionTime: Double
        let engagementRate: Double
        let revenue: Double
        let latency: Double
        let growthRate: Double
        let performanceScore: Double
    }
    
    private init() {
        Task { await loadRegionalData() }
    }
    
    func loadRegionalData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawRegion: Decodable { let id: String; let region: String; let countryCode: String; let userCount: Int; let activeUsers: Int; let avgSessionTime: Double; let engagementRate: Double; let revenue: Double; let latency: Double; let growthRate: Double; let performanceScore: Double }
        struct Raw: Decodable { let regionalMetrics: [RawRegion]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_regional_performance"), timeout: 30)
            
            regionalMetrics = (r.regionalMetrics ?? []).map {
                RegionalMetric(
                    id: $0.id,
                    region: $0.region,
                    countryCode: $0.countryCode,
                    userCount: $0.userCount,
                    activeUsers: $0.activeUsers,
                    avgSessionTime: $0.avgSessionTime,
                    engagementRate: $0.engagementRate,
                    revenue: $0.revenue,
                    latency: $0.latency,
                    growthRate: $0.growthRate,
                    performanceScore: $0.performanceScore
                )
            }
            
            topRegions = regionalMetrics.sorted { $0.performanceScore > $1.performanceScore }.prefix(5).map { $0 }
            underperformingRegions = regionalMetrics.filter { $0.performanceScore < 60 }.sorted { $0.performanceScore < $1.performanceScore }
            
        } catch {
            print("⚠️ [RegionalPerformance] Error: \(error)")
        }
    }
}
