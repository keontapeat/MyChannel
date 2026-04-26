//
//  RevenueIntelligenceService.swift
//  MyChannel
//
//  Phase 128: Revenue Intelligence Dashboard.
//  Per-video RPM breakdown, audience LTV, revenue forecasting, what-if simulator.
//  Uses `creator-earnings-optimizer` + `revenue-maximizer-ai`.
//

import Foundation

// MARK: - Models

struct VideoRPMBreakdown: Codable, Identifiable {
    let id: String        // videoId
    let adsRPM: Double
    let membershipRPM: Double
    let tipsRPM: Double
    let totalRPM: Double
    let views: Int
    let estimatedRevenue: Double
}

struct AudienceLTV: Codable {
    let segment: String
    let avgLifetimeValueUSD: Double
    let retentionDays: Int
    let churnRisk: Double
}

struct RevenueForecast: Codable {
    let period: String
    let projectedRevenueUSD: Double
    let confidence: Double
    let growthPercent: Double
}

struct WhatIfScenario: Codable, Identifiable {
    let id: String
    let name: String
    let parameterChanges: [String: String]
    let projectedDelta: Double
    let recommendation: String
}

// MARK: - Service

@MainActor
final class RevenueIntelligenceService: ObservableObject {
    static let shared = RevenueIntelligenceService()
    private init() {}

    @Published private(set) var rpmBreakdowns: [VideoRPMBreakdown] = []
    @Published private(set) var audienceLTVs: [AudienceLTV] = []
    @Published private(set) var forecasts: [RevenueForecast] = []
    @Published private(set) var scenarios: [WhatIfScenario] = []

    func loadRPMBreakdown(creatorUid: String) async throws {
        guard AppConfig.Features.enableRevenueIntelligence else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawRPM: Decodable { let video_id: String; let ads: Double; let membership: Double; let tips: Double; let total: Double; let views: Int; let revenue: Double }
        struct Raw: Decodable { let breakdowns: [RawRPM]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorEarningsOptimizer, path: "/predict",
            body: Request(task: "rpm_breakdown", creatorUid: creatorUid)
        )
        rpmBreakdowns = (r.breakdowns ?? []).map {
            VideoRPMBreakdown(id: $0.video_id, adsRPM: $0.ads, membershipRPM: $0.membership, tipsRPM: $0.tips, totalRPM: $0.total, views: $0.views, estimatedRevenue: $0.revenue)
        }
    }

    func loadAudienceLTV(creatorUid: String) async throws {
        guard AppConfig.Features.enableRevenueIntelligence else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawLTV: Decodable { let segment: String; let ltv: Double; let retention: Int; let churn: Double }
        struct Raw: Decodable { let segments: [RawLTV]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .lifetimeValue, path: "/predict",
            body: Request(task: "audience_ltv", creatorUid: creatorUid)
        )
        audienceLTVs = (r.segments ?? []).map {
            AudienceLTV(segment: $0.segment, avgLifetimeValueUSD: $0.ltv, retentionDays: $0.retention, churnRisk: $0.churn)
        }
    }

    func forecast(creatorUid: String) async throws {
        guard AppConfig.Features.enableRevenueIntelligence else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawForecast: Decodable { let period: String; let revenue: Double; let confidence: Double; let growth: Double }
        struct Raw: Decodable { let forecasts: [RawForecast]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Request(task: "revenue_forecast", creatorUid: creatorUid)
        )
        forecasts = (r.forecasts ?? []).map {
            RevenueForecast(period: $0.period, projectedRevenueUSD: $0.revenue, confidence: $0.confidence, growthPercent: $0.growth)
        }
    }

    func simulateWhatIf(creatorUid: String, scenario: String) async throws {
        guard AppConfig.Features.enableRevenueIntelligence else { return }
        struct Request: Encodable { let task: String; let creatorUid: String; let scenario: String }
        struct RawScenario: Decodable { let name: String; let params: [String: String]?; let delta: Double; let recommendation: String }
        struct Raw: Decodable { let scenarios: [RawScenario]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Request(task: "what_if", creatorUid: creatorUid, scenario: scenario)
        )
        scenarios = (r.scenarios ?? []).map {
            WhatIfScenario(id: UUID().uuidString, name: $0.name, parameterChanges: $0.params ?? [:], projectedDelta: $0.delta, recommendation: $0.recommendation)
        }
    }
}
