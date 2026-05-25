//
//  LiveAnalyticsDashboardService.swift
//  MyChannel
//
//  Phase 175: Live Analytics Dashboard.
//  Real-time viewer map, engagement pulse, chat sentiment, revenue tracker.
//

import Foundation

// MARK: - Models

struct LiveViewerStats: Codable {
    let currentViewers: Int
    let peakViewers: Int
    let avgWatchTimeSec: Double
    let chatMessagesPerMinute: Double
    let superChatRevenueUSD: Double
}

struct GeoViewerCluster: Codable, Identifiable {
    let id: String
    let country: String
    let region: String
    let viewerCount: Int
    let latitude: Double
    let longitude: Double
}

struct ChatSentimentSnapshot: Codable, Identifiable {
    let id: String
    let timestampSec: Double
    let positive: Double
    let negative: Double
    let neutral: Double
    let topEmoji: String
}

struct EngagementPulse: Codable, Identifiable {
    let id: String
    let timestampSec: Double
    let engagementScore: Double
    let newFollowers: Int
    let giftsReceived: Int
}

// MARK: - Service

@MainActor
final class LiveAnalyticsDashboardService: ObservableObject {
    static let shared = LiveAnalyticsDashboardService()
    private init() {}

    @Published private(set) var viewerStats = LiveViewerStats(currentViewers: 0, peakViewers: 0, avgWatchTimeSec: 0, chatMessagesPerMinute: 0, superChatRevenueUSD: 0)
    @Published private(set) var geoViewers: [GeoViewerCluster] = []
    @Published private(set) var sentimentTimeline: [ChatSentimentSnapshot] = []
    @Published private(set) var engagementPulses: [EngagementPulse] = []

    func fetchRealTimeStats(streamId: String) async throws {
        guard AppConfig.Features.enableLiveAnalyticsDashboard else { return }
        struct Request: Encodable { let task: String; let streamId: String }
        struct Raw: Decodable { let viewers: Int?; let peak: Int?; let avg_watch: Double?; let chat_rate: Double?; let revenue: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Request(task: "live_stats", streamId: streamId)
        )
        viewerStats = LiveViewerStats(
            currentViewers: r.viewers ?? 0, peakViewers: r.peak ?? 0,
            avgWatchTimeSec: r.avg_watch ?? 0, chatMessagesPerMinute: r.chat_rate ?? 0,
            superChatRevenueUSD: r.revenue ?? 0
        )
    }

    func fetchGeoDistribution(streamId: String) async throws {
        guard AppConfig.Features.enableLiveAnalyticsDashboard else { return }
        struct Request: Encodable { let task: String; let streamId: String }
        struct RawGeo: Decodable { let country: String; let region: String; let count: Int; let lat: Double; let lng: Double }
        struct Raw: Decodable { let clusters: [RawGeo]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Request(task: "geo_viewers", streamId: streamId)
        )
        geoViewers = (r.clusters ?? []).map {
            GeoViewerCluster(id: UUID().uuidString, country: $0.country, region: $0.region,
                           viewerCount: $0.count, latitude: $0.lat, longitude: $0.lng)
        }
    }

    func fetchChatSentiment(streamId: String) async throws {
        guard AppConfig.Features.enableLiveAnalyticsDashboard else { return }
        struct Request: Encodable { let task: String; let streamId: String }
        struct RawSent: Decodable { let time: Double; let pos: Double; let neg: Double; let neutral: Double; let emoji: String }
        struct Raw: Decodable { let timeline: [RawSent]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .commentAnalyzer, path: "/predict",
            body: Request(task: "chat_sentiment", streamId: streamId)
        )
        sentimentTimeline = (r.timeline ?? []).map {
            ChatSentimentSnapshot(id: UUID().uuidString, timestampSec: $0.time,
                                positive: $0.pos, negative: $0.neg, neutral: $0.neutral, topEmoji: $0.emoji)
        }
    }
}
