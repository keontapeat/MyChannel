//
//  ProfileAnalyticsService.swift
//  MyChannel
//
//  Phase 247: Profile Analytics Dashboard.
//  In-profile stats card, subscriber growth sparkline,
//  top content breakdown, audience geography, real-time viewer count.
//  Uses `analytics-predictor-ai` + `audience-segmentation-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileStats: Codable {
    let subscriberCount: Int
    let totalViews: Int
    let totalLikes: Int
    let avgEngagement: Double
    let realTimeViewers: Int
    let growthRate: Double
}

struct SubscriberGrowth: Codable {
    let dataPoints: [GrowthPoint]
    let period: String

    struct GrowthPoint: Codable {
        let date: String
        let count: Int
    }
}

struct TopContentBreakdown: Codable {
    let topVideos: [TopVideo]
    let byCategory: [CategoryStat]

    struct TopVideo: Codable, Identifiable {
        let id: String
        let title: String
        let views: Int
        let engagement: Double
    }

    struct CategoryStat: Codable {
        let category: String
        let views: Int
        let pct: Double
    }
}

struct AudienceGeography: Codable {
    let topRegions: [RegionStat]

    struct RegionStat: Codable {
        let region: String
        let pct: Double
        let count: Int
    }
}

// MARK: - Service

@MainActor
final class ProfileAnalyticsService: ObservableObject {
    static let shared = ProfileAnalyticsService()
    private init() {}

    @Published private(set) var stats: ProfileStats?
    @Published private(set) var growth: SubscriberGrowth?
    @Published private(set) var topContent: TopContentBreakdown?
    @Published private(set) var geography: AudienceGeography?

    func fetchStats(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAnalytics else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let subs: Int?; let views: Int?; let likes: Int?; let engagement: Double?; let live_viewers: Int?; let growth_rate: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_profile_stats", creatorId: creatorId)
        )
        stats = ProfileStats(subscriberCount: r.subs ?? 0, totalViews: r.views ?? 0, totalLikes: r.likes ?? 0,
                              avgEngagement: r.engagement ?? 0, realTimeViewers: r.live_viewers ?? 0, growthRate: r.growth_rate ?? 0)
    }

    func fetchGrowth(creatorId: String, period: String = "30d") async throws {
        guard AppConfig.Features.enableProfileAnalytics else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let period: String }
        struct RawPt: Decodable { let date: String; let count: Int }
        struct Raw: Decodable { let points: [RawPt]?; let period: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_subscriber_growth", creatorId: creatorId, period: period)
        )
        growth = SubscriberGrowth(dataPoints: (r.points ?? []).map { SubscriberGrowth.GrowthPoint(date: $0.date, count: $0.count) },
                                    period: r.period ?? period)
    }

    func fetchTopContent(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAnalytics else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawV: Decodable { let id: String; let title: String; let views: Int; let engagement: Double }
        struct RawC: Decodable { let category: String; let views: Int; let pct: Double }
        struct Raw: Decodable { let top_videos: [RawV]?; let by_category: [RawC]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_top_content", creatorId: creatorId)
        )
        topContent = TopContentBreakdown(
            topVideos: (r.top_videos ?? []).map { TopContentBreakdown.TopVideo(id: $0.id, title: $0.title, views: $0.views, engagement: $0.engagement) },
            byCategory: (r.by_category ?? []).map { TopContentBreakdown.CategoryStat(category: $0.category, views: $0.views, pct: $0.pct) }
        )
    }

    func fetchGeography(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAnalytics else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawR: Decodable { let region: String; let pct: Double; let count: Int }
        struct Raw: Decodable { let regions: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Req(task: "fetch_audience_geography", creatorId: creatorId)
        )
        geography = AudienceGeography(topRegions: (r.regions ?? []).map { AudienceGeography.RegionStat(region: $0.region, pct: $0.pct, count: $0.count) })
    }
}
