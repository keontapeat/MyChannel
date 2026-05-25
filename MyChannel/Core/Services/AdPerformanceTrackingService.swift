//
//  AdPerformanceTrackingService.swift
//  MyChannel
//
//  Phase 273: Ad Performance and Fill Rate Tracking
//  Monitors ad performance, fill rates, CPM, revenue by ad type
//

import Foundation
import Combine

@MainActor
class AdPerformanceTrackingService: ObservableObject {
    static let shared = AdPerformanceTrackingService()
    
    @Published private(set) var adMetrics: [AdMetric] = []
    @Published private(set) var overallFillRate: Double = 0
    @Published private(set) var avgCPM: Double = 0
    @Published private(set) var totalAdRevenue: Double = 0
    
    struct AdMetric: Identifiable, Codable {
        let id: String
        let adType: String
        let impressions: Int
        let clicks: Int
        let fillRate: Double
        let ctr: Double
        let cpm: Double
        let revenue: Double
        let period: String
    }
    
    private init() {
        Task { await loadAdMetrics() }
    }
    
    func loadAdMetrics() async {
        guard AppConfig.Features.enableAds else { return }
        
        struct Req: Encodable { let task: String }
        struct RawAd: Decodable { let id: String; let adType: String; let impressions: Int; let clicks: Int; let fillRate: Double; let ctr: Double; let cpm: Double; let revenue: Double; let period: String }
        struct Raw: Decodable { let adMetrics: [RawAd]?; let overallFillRate: Double?; let avgCPM: Double?; let totalAdRevenue: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.adsServe, path: "/predict",
                body: Req(task: "get_ad_performance"), timeout: 30)
            
            adMetrics = (r.adMetrics ?? []).map {
                AdMetric(
                    id: $0.id,
                    adType: $0.adType,
                    impressions: $0.impressions,
                    clicks: $0.clicks,
                    fillRate: $0.fillRate,
                    ctr: $0.ctr,
                    cpm: $0.cpm,
                    revenue: $0.revenue,
                    period: $0.period
                )
            }
            
            overallFillRate = r.overallFillRate ?? 0
            avgCPM = r.avgCPM ?? 0
            totalAdRevenue = r.totalAdRevenue ?? 0
            
        } catch {
            print("⚠️ [AdPerformanceTracking] Error: \(error)")
        }
    }
}
