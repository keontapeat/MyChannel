//
//  CommerceAttributionService.swift
//  MyChannel
//
//  Phase 225: Commerce Attribution Intelligence.
//  Cross-surface conversion attribution for video/live/posts,
//  ROI scoring, creator and brand dashboards.
//  Uses `revenue-maximizer-ai` + `advertiser-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct AttributionEvent: Codable, Identifiable {
    let id: String
    let sourceSurface: String
    let sourceContentId: String
    let targetAction: String
    let targetProductId: String
    let userId: String
    let revenue: Double
    let timestamp: Date
    let confidence: Double
}

struct AttributionDashboard: Codable {
    let totalAttributedRevenue: Double
    let topConvertingContent: [ContentROI]
    let surfaceBreakdown: [SurfaceStat]
    let period: String
}

struct ContentROI: Codable, Identifiable {
    let id: String
    let contentId: String
    let title: String
    let impressions: Int
    let conversions: Int
    let revenue: Double
    let roi: Double
}

struct SurfaceStat: Codable {
    let surface: String
    let conversions: Int
    let revenue: Double
    let avgConfidence: Double
}

// MARK: - Service

@MainActor
final class CommerceAttributionService: ObservableObject {
    static let shared = CommerceAttributionService()
    private init() {}

    @Published private(set) var events: [AttributionEvent] = []
    @Published private(set) var dashboard: AttributionDashboard?

    func trackAttribution(source: String, contentId: String, action: String, productId: String, userId: String) async throws {
        guard AppConfig.Features.enableCommerceAttribution else { return }
        struct Req: Encodable { let task: String; let source: String; let contentId: String; let action: String; let productId: String; let userId: String }
        struct Raw: Decodable { let id: String; let revenue: Double?; let confidence: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "track_attribution", source: source, contentId: contentId,
                      action: action, productId: productId, userId: userId)
        )
        let event = AttributionEvent(id: r.id, sourceSurface: source, sourceContentId: contentId,
                                      targetAction: action, targetProductId: productId, userId: userId,
                                      revenue: r.revenue ?? 0, timestamp: Date(), confidence: r.confidence ?? 0)
        events.append(event)
    }

    func fetchDashboard(creatorId: String, period: String = "30d") async throws {
        guard AppConfig.Features.enableCommerceAttribution else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let period: String }
        struct RawROI: Decodable { let id: String; let content_id: String; let title: String; let impressions: Int; let conversions: Int; let revenue: Double; let roi: Double }
        struct RawSurf: Decodable { let surface: String; let conversions: Int; let revenue: Double; let confidence: Double }
        struct Raw: Decodable { let total_revenue: Double?; let top_content: [RawROI]?; let surfaces: [RawSurf]?; let period: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .advertiserAI, path: "/predict",
            body: Req(task: "attribution_dashboard", creatorId: creatorId, period: period), timeout: 30
        )
        dashboard = AttributionDashboard(
            totalAttributedRevenue: r.total_revenue ?? 0,
            topConvertingContent: (r.top_content ?? []).map { ContentROI(id: $0.id, contentId: $0.content_id, title: $0.title, impressions: $0.impressions, conversions: $0.conversions, revenue: $0.revenue, roi: $0.roi) },
            surfaceBreakdown: (r.surfaces ?? []).map { SurfaceStat(surface: $0.surface, conversions: $0.conversions, revenue: $0.revenue, avgConfidence: $0.confidence) },
            period: r.period ?? period
        )
    }

    func scoreROI(contentId: String) async throws -> Double {
        guard AppConfig.Features.enableCommerceAttribution else { return 0 }
        struct Req: Encodable { let task: String; let contentId: String }
        struct Raw: Decodable { let roi: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "score_roi", contentId: contentId)
        )
        return r.roi ?? 0
    }
}
