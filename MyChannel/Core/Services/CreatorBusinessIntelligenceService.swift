//
//  CreatorBusinessIntelligenceService.swift
//  MyChannel
//
//  Phase 230: Creator Business Intelligence.
//  Profitability by format and audience, revenue concentration risk,
//  predictive cashflow.
//  Uses `revenue-maximizer-ai` + `analytics-predictor-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct FormatProfitability: Codable, Identifiable {
    let id: String
    let format: String
    let revenue: Double
    let cost: Double
    let profit: Double
    let margin: Double
    let views: Int
}

struct RevenueConcentration: Codable {
    let topSourcePct: Double
    let diversifiedScore: Double
    let riskLevel: String
    let sources: [RevenueSource]
}

struct RevenueSource: Codable, Identifiable {
    let id: String
    let name: String
    let amount: Double
    let pct: Double
}

struct CashflowForecast: Codable {
    let currentMonth: Double
    let nextMonth: Double
    let threeMonth: Double
    let confidence: Double
    let trend: String
}

// MARK: - Service

@MainActor
final class CreatorBusinessIntelligenceService: ObservableObject {
    static let shared = CreatorBusinessIntelligenceService()
    private init() {}

    @Published private(set) var formatProfitability: [FormatProfitability] = []
    @Published private(set) var concentration: RevenueConcentration?
    @Published private(set) var cashflow: CashflowForecast?

    func fetchProfitability(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorBusinessIntelligence else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawFmt: Decodable { let id: String; let format: String; let revenue: Double; let cost: Double; let profit: Double; let margin: Double; let views: Int }
        struct Raw: Decodable { let formats: [RawFmt]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "format_profitability", creatorId: creatorId)
        )
        formatProfitability = (r.formats ?? []).map {
            FormatProfitability(id: $0.id, format: $0.format, revenue: $0.revenue, cost: $0.cost,
                                profit: $0.profit, margin: $0.margin, views: $0.views)
        }
    }

    func assessConcentration(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorBusinessIntelligence else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawSrc: Decodable { let id: String; let name: String; let amount: Double; let pct: Double }
        struct Raw: Decodable { let top_pct: Double?; let score: Double?; let risk: String?; let sources: [RawSrc]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "revenue_concentration", creatorId: creatorId)
        )
        concentration = RevenueConcentration(topSourcePct: r.top_pct ?? 0, diversifiedScore: r.score ?? 0,
                                              riskLevel: r.risk ?? "low",
                                              sources: (r.sources ?? []).map { RevenueSource(id: $0.id, name: $0.name, amount: $0.amount, pct: $0.pct) })
    }

    func forecastCashflow(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorBusinessIntelligence else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let current: Double?; let next: Double?; let three_month: Double?; let confidence: Double?; let trend: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "forecast_cashflow", creatorId: creatorId), timeout: 30
        )
        cashflow = CashflowForecast(currentMonth: r.current ?? 0, nextMonth: r.next ?? 0,
                                     threeMonth: r.three_month ?? 0, confidence: r.confidence ?? 0,
                                     trend: r.trend ?? "stable")
    }
}
