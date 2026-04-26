//
//  AnalyticsService.swift
//  MyChannel
//
//  Core analytics: event tracking, session management, funnel analysis.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

struct AnalyticsEvent: Codable, Identifiable {
    let id: String
    let name: String
    let params: [String: String]
    let timestamp: Date
    let sessionId: String
    let userId: String?
}

struct AnalyticsSession: Codable, Identifiable {
    let id: String
    let startedAt: Date
    let endedAt: Date?
    let eventCount: Int
    let screenViews: Int
    let userId: String?
}

struct FunnelStep: Codable, Identifiable {
    let id: String
    let name: String
    let order: Int
    let enterCount: Int
    let exitCount: Int
    let conversionRate: Double
}

@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    private init() {}
    @Published private(set) var currentSession: AnalyticsSession?
    @Published private(set) var recentEvents: [AnalyticsEvent] = []
    private var eventBuffer: [AnalyticsEvent] = []

    func startSession(userId: String?) {
        let session = AnalyticsSession(id: UUID().uuidString, startedAt: Date(), endedAt: nil, eventCount: 0, screenViews: 0, userId: userId)
        currentSession = session
    }

    func endSession() {
        guard var session = currentSession else { return }
        session = AnalyticsSession(id: session.id, startedAt: session.startedAt, endedAt: Date(),
            eventCount: session.eventCount, screenViews: session.screenViews, userId: session.userId)
        currentSession = nil
    }

    func track(name: String, params: [String: String] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: params)
        #endif
        let event = AnalyticsEvent(id: UUID().uuidString, name: name, params: params,
            timestamp: Date(), sessionId: currentSession?.id ?? "", userId: currentSession?.userId)
        eventBuffer.append(event)
        recentEvents.append(event)
        if recentEvents.count > 200 { recentEvents = Array(recentEvents.suffix(100)) }
    }

    func trackScreen(_ screenName: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("screen_view", parameters: ["screen_name": screenName])
        #endif
        track(name: "screen_view", params: ["screen": screenName])
    }

    func trackVideoPlay(videoId: String, position: TimeInterval) async {
        track(name: "video_play", params: [
            "video_id": videoId,
            "position": String(position)
        ])
    }

    func trackVideoPause(videoId: String, position: TimeInterval) async {
        track(name: "video_pause", params: [
            "video_id": videoId,
            "position": String(position)
        ])
    }

    func trackVideoSeek(videoId: String, from: TimeInterval, to: TimeInterval) async {
        track(name: "video_seek", params: [
            "video_id": videoId,
            "from_position": String(from),
            "to_position": String(to)
        ])
    }

    func trackEvent(_ name: String, parameters: [String: String] = [:]) async {
        track(name: name, params: parameters)
    }

    func trackEvent(_ name: String, parameters: [String: Any]) async {
        let stringParams = parameters.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = "\(pair.value)"
        }
        track(name: name, params: stringParams)
    }

    func trackVideoQuartile(videoId: String, quartile: Int) async {
        track(name: "video_quartile", params: [
            "video_id": videoId,
            "quartile": String(quartile)
        ])
    }

    func trackScreenView(_ screenName: String) async {
        trackScreen(screenName)
    }

    func flush() async throws {
        guard !eventBuffer.isEmpty else { return }
        let batch = eventBuffer
        eventBuffer = []
        struct Req: Encodable { let task: String; let count: Int }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "flush_analytics", count: batch.count))
    }

    func fetchFunnel(funnelId: String) async throws -> [FunnelStep] {
        struct Req: Encodable { let task: String; let funnelId: String }
        struct RawS: Decodable { let id: String; let name: String; let order: Int; let enter: Int; let exit: Int; let rate: Double }
        struct Raw: Decodable { let steps: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_funnel", funnelId: funnelId))
        return (r.steps ?? []).map { FunnelStep(id: $0.id, name: $0.name, order: $0.order, enterCount: $0.enter, exitCount: $0.exit, conversionRate: $0.rate) }
    }
}
