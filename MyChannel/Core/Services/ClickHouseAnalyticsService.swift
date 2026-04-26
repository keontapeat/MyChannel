//
//  ClickHouseAnalyticsService.swift
//  MyChannel
//
//  Phase 2.4: ClickHouse OLAP for real-time analytics at scale.
//  Columnar storage for sub-second aggregation queries.
//  Uses `mychannel-content` Cloud Run as ClickHouse proxy.
//

import Foundation
import Combine

// MARK: - Models

struct AnalyticsQuery: Codable {
    let metric: AnalyticsMetric
    let dimensions: [AnalyticsDimension]
    let filters: [AnalyticsFilter]
    let dateRange: DateRange
    let granularity: Granularity
    let limit: Int
    
    enum AnalyticsMetric: String, Codable, CaseIterable {
        case views = "views"
        case watchTime = "watch_time"
        case uniqueViewers = "unique_viewers"
        case avgViewDuration = "avg_view_duration"
        case engagement = "engagement_rate"
        case revenue = "revenue"
        case subscribers = "subscribers_gained"
        case likes = "likes"
        case comments = "comments"
        case shares = "shares"
        case ctr = "click_through_rate"
        case retention = "retention_rate"
        case adImpressions = "ad_impressions"
        case adRevenue = "ad_revenue"
    }
    
    enum AnalyticsDimension: String, Codable, CaseIterable {
        case video = "video_id"
        case creator = "creator_id"
        case date = "date"
        case hour = "hour"
        case country = "country"
        case device = "device_type"
        case os = "os"
        case source = "traffic_source"
        case category = "category"
        case quality = "video_quality"
    }
    
    struct AnalyticsFilter: Codable {
        let dimension: String
        let filterOperator: String
        let value: String

        enum CodingKeys: String, CodingKey {
            case dimension
            case filterOperator = "operator"
            case value
        }
    }
    
    enum Granularity: String, Codable {
        case hourly = "hour"
        case daily = "day"
        case weekly = "week"
        case monthly = "month"
    }
    
    struct DateRange: Codable {
        let start: String // ISO 8601
        let end: String
    }
}

struct AnalyticsResult: Codable, Identifiable {
    let id: String
    let dimensions: [String: String]
    let metrics: [String: Double]
    let timestamp: Date
}

struct RealTimeMetrics: Codable {
    let activeViewers: Int
    let concurrentStreams: Int
    let requestsPerSecond: Int
    let avgLatencyMs: Int
    let errorRate: Double
    let bandwidthGbps: Double
    let timestamp: Date
}

struct CreatorAnalyticsSummary: Codable {
    let totalViews: Int64
    let totalWatchHours: Double
    let totalSubscribers: Int
    let avgViewDuration: Double
    let estimatedRevenue: Double
    let topVideo: String?
    let topCountry: String?
    let topSource: String?
    let periodStart: String
    let periodEnd: String
}

// MARK: - ClickHouse Analytics Service

@MainActor
final class ClickHouseAnalyticsService: ObservableObject {
    static let shared = ClickHouseAnalyticsService()
    
    @Published var realTimeMetrics: RealTimeMetrics?
    @Published var lastQueryResults: [AnalyticsResult] = []
    @Published var isQuerying = false
    
    private let redisCache = RedisCacheService.shared
    private var metricsTimer: Timer?
    
    private init() {}
    
    // MARK: - 📊 QUERY ANALYTICS
    
    func query(_ query: AnalyticsQuery) async throws -> [AnalyticsResult] {
        isQuerying = true
        defer { isQuerying = false }
        
        // Check Redis cache first (5ms for hot analytics)
        let cacheKey = "analytics:\(query.metric.rawValue)_\(query.granularity.rawValue)_\(query.dateRange.start)"
        if let cached: [AnalyticsResult] = await redisCache.get(cacheKey, type: [AnalyticsResult].self) {
            lastQueryResults = cached
            return cached
        }
        
        struct Request: Encodable {
            let task: String; let metric: String; let dimensions: [String]
            let filters: [AnalyticsQuery.AnalyticsFilter]; let dateStart: String; let dateEnd: String
            let granularity: String; let limit: Int
        }
        struct RawResult: Decodable {
            let id: String?; let dimensions: [String: String]?; let metrics: [String: Double]?
            let timestamp: Double?
        }
        struct Response: Decodable { let results: [RawResult]? }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelContent,
            path: "/predict",
            body: Request(
                task: "clickhouse_query",
                metric: query.metric.rawValue,
                dimensions: query.dimensions.map(\.rawValue),
                filters: query.filters,
                dateStart: query.dateRange.start,
                dateEnd: query.dateRange.end,
                granularity: query.granularity.rawValue,
                limit: query.limit
            ),
            timeout: 15
        )
        
        let results = (r.results ?? []).compactMap { raw -> AnalyticsResult? in
            guard let id = raw.id else { return nil }
            return AnalyticsResult(
                id: id,
                dimensions: raw.dimensions ?? [:],
                metrics: raw.metrics ?? [:],
                timestamp: Date(timeIntervalSince1970: raw.timestamp ?? 0)
            )
        }
        
        // Cache results (TTL varies by granularity)
        let ttl: TimeInterval = query.granularity == .hourly ? 60 : query.granularity == .daily ? 300 : 3600
        await redisCache.set(cacheKey, value: results, ttl: ttl)
        
        lastQueryResults = results
        return results
    }
    
    // MARK: - ⚡ REAL-TIME METRICS
    
    func startRealTimeMonitoring() {
        guard metricsTimer == nil else { return }
        
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchRealTimeMetrics()
            }
        }
        print("📊 [ClickHouse] Real-time monitoring started (5s interval)")
    }
    
    func stopRealTimeMonitoring() {
        metricsTimer?.invalidate()
        metricsTimer = nil
        print("📊 [ClickHouse] Real-time monitoring stopped")
    }
    
    private func fetchRealTimeMetrics() async {
        // Try Redis cache first (1ms for real-time dashboard)
        if let cached: RealTimeMetrics = await redisCache.get("analytics:realtime", type: RealTimeMetrics.self) {
            realTimeMetrics = cached
            return
        }
        
        struct Request: Encodable { let task: String }
        struct Response: Decodable {
            let activeViewers: Int?; let concurrentStreams: Int?; let requestsPerSecond: Int?
            let avgLatencyMs: Int?; let errorRate: Double?; let bandwidthGbps: Double?
            let timestamp: Double?
        }
        
        guard let r: Response = try? await CloudRunAgentRouter.post(
            .myChannelContent,
            path: "/predict",
            body: Request(task: "realtime_metrics")
        ) else { return }
        
        let metrics = RealTimeMetrics(
            activeViewers: r.activeViewers ?? 0,
            concurrentStreams: r.concurrentStreams ?? 0,
            requestsPerSecond: r.requestsPerSecond ?? 0,
            avgLatencyMs: r.avgLatencyMs ?? 0,
            errorRate: r.errorRate ?? 0,
            bandwidthGbps: r.bandwidthGbps ?? 0,
            timestamp: Date(timeIntervalSince1970: r.timestamp ?? 0)
        )
        
        // Cache for 10 seconds
        await redisCache.set("analytics:realtime", value: metrics, ttl: 10)
        realTimeMetrics = metrics
    }
    
    // MARK: - 📈 CREATOR ANALYTICS SUMMARY
    
    func getCreatorSummary(creatorId: String, period: AnalyticsQuery.DateRange) async throws -> CreatorAnalyticsSummary {
        // Redis cache for creator dashboard (5ms)
        let cacheKey = "analytics:creator:\(creatorId):\(period.start)"
        if let cached: CreatorAnalyticsSummary = await redisCache.get(cacheKey, type: CreatorAnalyticsSummary.self) {
            return cached
        }
        
        struct Request: Encodable {
            let task: String; let creatorId: String; let dateStart: String; let dateEnd: String
        }
        struct Response: Decodable {
            let totalViews: Int64?; let totalWatchHours: Double?; let totalSubscribers: Int?
            let avgViewDuration: Double?; let estimatedRevenue: Double?
            let topVideo: String?; let topCountry: String?; let topSource: String?
        }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelContent,
            path: "/predict",
            body: Request(task: "creator_summary", creatorId: creatorId, dateStart: period.start, dateEnd: period.end)
        )
        
        let summary = CreatorAnalyticsSummary(
            totalViews: r.totalViews ?? 0,
            totalWatchHours: r.totalWatchHours ?? 0,
            totalSubscribers: r.totalSubscribers ?? 0,
            avgViewDuration: r.avgViewDuration ?? 0,
            estimatedRevenue: r.estimatedRevenue ?? 0,
            topVideo: r.topVideo,
            topCountry: r.topCountry,
            topSource: r.topSource,
            periodStart: period.start,
            periodEnd: period.end
        )
        
        // Cache for 5 minutes
        await redisCache.set(cacheKey, value: summary, ttl: 300)
        return summary
    }
    
    // MARK: - 📊 VIDEO RETENTION CURVE
    
    func getRetentionCurve(videoId: String) async throws -> [ClickHouseRetentionPoint] {
        let cacheKey = "analytics:retention:\(videoId)"
        if let cached: [ClickHouseRetentionPoint] = await redisCache.get(cacheKey, type: [ClickHouseRetentionPoint].self) {
            return cached
        }
        
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawPoint: Decodable { let percent: Double?; let viewers: Int? }
        struct Response: Decodable { let points: [RawPoint]? }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelContent,
            path: "/predict",
            body: Request(task: "retention_curve", videoId: videoId)
        )
        
        let points = (r.points ?? []).enumerated().map { index, raw in
            ClickHouseRetentionPoint(
                second: index * 5, // 5-second buckets
                percent: raw.percent ?? 0,
                viewers: raw.viewers ?? 0
            )
        }
        
        await redisCache.set(cacheKey, value: points, ttl: 600) // 10 min
        return points
    }
}

struct ClickHouseRetentionPoint: Codable {
    let second: Int
    let percent: Double
    let viewers: Int
}
