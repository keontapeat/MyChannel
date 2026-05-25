//
//  WatchTimeOptimizerService.swift
//  MyChannel
//
//  Watch time optimization: content scheduling, thumbnail A/B testing,
//  retention analysis, optimal publish time. Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct WatchTimeInsight: Codable, Identifiable {
    let id: String
    let creatorId: String
    let avgRetentionPct: Double
    let avgWatchTimeSec: Double
    let bestPublishHour: Int
    let bestPublishDay: String
    let topRetainingCategories: [String]
}

struct WatchTimeRetentionCurve: Codable {
    let videoId: String
    let points: [RetentionPoint]
    struct RetentionPoint: Codable { let sec: Double; let pct: Double }
}

@MainActor
final class WatchTimeOptimizerService: ObservableObject {
    static let shared = WatchTimeOptimizerService()
    private init() {}
    @Published private(set) var insights: WatchTimeInsight?
    @Published private(set) var retentionCurves: [String: WatchTimeRetentionCurve] = [:]

    func fetchInsights(creatorId: String) async throws {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let retention: Double?; let watch_time: Double?; let best_hour: Int?; let best_day: String?; let categories: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_watch_time_insights", creatorId: creatorId))
        insights = WatchTimeInsight(id: UUID().uuidString, creatorId: creatorId, avgRetentionPct: r.retention ?? 0,
            avgWatchTimeSec: r.watch_time ?? 0, bestPublishHour: r.best_hour ?? 18, bestPublishDay: r.best_day ?? "Saturday",
            topRetainingCategories: r.categories ?? [])
    }

    func fetchWatchTimeRetentionCurve(videoId: String) async throws {
        struct Req: Encodable { let task: String; let videoId: String }
        struct RawP: Decodable { let sec: Double; let pct: Double }
        struct Raw: Decodable { let points: [RawP]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_retention_curve", videoId: videoId))
        retentionCurves[videoId] = WatchTimeRetentionCurve(videoId: videoId,
            points: (r.points ?? []).map { WatchTimeRetentionCurve.RetentionPoint(sec: $0.sec, pct: $0.pct) })
    }

    func suggestOptimalPublishTime(creatorId: String) async throws -> (hour: Int, day: String) {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let hour: Int?; let day: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "suggest_publish_time", creatorId: creatorId))
        return (hour: r.hour ?? 18, day: r.day ?? "Saturday")
    }
}
