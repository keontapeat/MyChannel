//
//  RevenueAttributionService.swift
//  MyChannel
//
//  Phase 265: Revenue Attribution and ROI Tracking
//  Tracks revenue sources, attribution, ROI by channel, campaign, creator
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class RevenueAttributionService: ObservableObject {
    static let shared = RevenueAttributionService()
    
    @Published private(set) var revenueStreams: [RevenueStream] = []
    @Published private(set) var attributionData: [AttributionMetric] = []
    @Published private(set) var roiMetrics: [ROIMetric] = []
    @Published private(set) var totalRevenue: Double = 0
    
    struct RevenueStream: Identifiable, Codable {
        let id: String
        let source: String
        let amount: Double
        let percentage: Double
        let growth: Double
        let period: String
    }
    
    struct AttributionMetric: Identifiable, Codable {
        let id: String
        let channel: String
        let attributedRevenue: Double
        let conversionRate: Double
        let cost: Double
        let roi: Double
        let touchpoints: Int
    }
    
    struct ROIMetric: Identifiable, Codable {
        let id: String
        let category: String
        let investment: Double
        let `return`: Double
        let roiPercentage: Double
        let paybackPeriod: Int
    }
    
    private init() {
        Task { await loadRevenueData() }
    }
    
    func loadRevenueData() async {
        guard AppConfig.Features.enableRevenueIntelligence else { return }
        
        struct Req: Encodable { let task: String }
        struct RawStream: Decodable { let id: String; let source: String; let amount: Double; let percentage: Double; let growth: Double; let period: String }
        struct RawAttrib: Decodable { let id: String; let channel: String; let attributedRevenue: Double; let conversionRate: Double; let cost: Double; let roi: Double; let touchpoints: Int }
        struct RawROI: Decodable { let id: String; let category: String; let investment: Double; let `return`: Double; let roiPercentage: Double; let paybackPeriod: Int }
        struct Raw: Decodable { let revenueStreams: [RawStream]?; let attributionData: [RawAttrib]?; let roiMetrics: [RawROI]?; let totalRevenue: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.revenueMaximizer, path: "/predict",
                body: Req(task: "get_revenue_attribution"), timeout: 30)
            
            revenueStreams = (r.revenueStreams ?? []).map {
                RevenueStream(
                    id: $0.id,
                    source: $0.source,
                    amount: $0.amount,
                    percentage: $0.percentage,
                    growth: $0.growth,
                    period: $0.period
                )
            }
            
            attributionData = (r.attributionData ?? []).map {
                AttributionMetric(
                    id: $0.id,
                    channel: $0.channel,
                    attributedRevenue: $0.attributedRevenue,
                    conversionRate: $0.conversionRate,
                    cost: $0.cost,
                    roi: $0.roi,
                    touchpoints: $0.touchpoints
                )
            }
            
            roiMetrics = (r.roiMetrics ?? []).map {
                ROIMetric(
                    id: $0.id,
                    category: $0.category,
                    investment: $0.investment,
                    `return`: $0.return,
                    roiPercentage: $0.roiPercentage,
                    paybackPeriod: $0.paybackPeriod
                )
            }
            
            totalRevenue = r.totalRevenue ?? 0
            
        } catch {
            print("⚠️ [RevenueAttribution] Error: \(error)")
        }
    }
    
    func getAttributionForChannel(channel: String) -> AttributionMetric? {
        attributionData.first { $0.channel == channel }
    }
}
