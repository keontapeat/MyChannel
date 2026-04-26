//
//  ProfileLiveStatusService.swift
//  MyChannel
//
//  Phase 249: Profile Live & Upcoming Indicator.
//  Live-now badge, upcoming stream schedule, stream countdown timer,
//  live viewer count, replay availability.
//  Uses `live-stream-optimizer-ai` + `mychannel-events` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileLiveStatus: Codable, Identifiable {
    let id: String
    let creatorId: String
    let isLive: Bool
    let currentStreamId: String?
    let viewerCount: Int
    let startedAt: Date?
    let title: String?
    let category: String?
}

struct UpcomingStream: Codable, Identifiable {
    let id: String
    let creatorId: String
    let title: String
    let scheduledStart: Date
    let category: String?
    let hasReminder: Bool
}

struct StreamReplay: Codable, Identifiable {
    let id: String
    let streamId: String
    let title: String
    let duration: TimeInterval
    let viewCount: Int
    let availableUntil: Date?
}

// MARK: - Service

@MainActor
final class ProfileLiveStatusService: ObservableObject {
    static let shared = ProfileLiveStatusService()
    private init() {}

    @Published private(set) var liveStatus: ProfileLiveStatus?
    @Published private(set) var upcomingStreams: [UpcomingStream] = []
    @Published private(set) var replays: [StreamReplay] = []

    func fetchLiveStatus(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileLiveStatus else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let id: String; let is_live: Bool?; let stream_id: String?; let viewers: Int?; let started: String?; let title: String?; let category: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Req(task: "fetch_live_status", creatorId: creatorId)
        )
        liveStatus = ProfileLiveStatus(id: r.id, creatorId: creatorId, isLive: r.is_live ?? false,
                                          currentStreamId: r.stream_id, viewerCount: r.viewers ?? 0,
                                          startedAt: r.started.flatMap { ISO8601DateFormatter().date(from: $0) },
                                          title: r.title, category: r.category)
    }

    func fetchUpcomingStreams(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileLiveStatus else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawS: Decodable { let id: String; let title: String; let scheduled: String; let category: String?; let reminder: Bool }
        struct Raw: Decodable { let streams: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "fetch_upcoming_streams", creatorId: creatorId)
        )
        upcomingStreams = (r.streams ?? []).map {
            UpcomingStream(id: $0.id, creatorId: creatorId, title: $0.title,
                           scheduledStart: ISO8601DateFormatter().date(from: $0.scheduled) ?? Date(),
                           category: $0.category, hasReminder: $0.reminder)
        }
    }

    func setReminder(streamId: String) async throws {
        guard AppConfig.Features.enableProfileLiveStatus else { return }
        struct Req: Encodable { let task: String; let streamId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "set_stream_reminder", streamId: streamId)
        )
        if let idx = upcomingStreams.firstIndex(where: { $0.id == streamId }) {
            let old = upcomingStreams[idx]
            upcomingStreams[idx] = UpcomingStream(id: old.id, creatorId: old.creatorId, title: old.title,
                                                   scheduledStart: old.scheduledStart, category: old.category, hasReminder: true)
        }
    }

    func fetchReplays(creatorId: String, limit: Int = 5) async throws {
        guard AppConfig.Features.enableProfileLiveStatus else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let limit: Int }
        struct RawR: Decodable { let id: String; let stream_id: String; let title: String; let duration: Double; let views: Int; let until: String? }
        struct Raw: Decodable { let replays: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Req(task: "fetch_replays", creatorId: creatorId, limit: limit)
        )
        replays = (r.replays ?? []).map {
            StreamReplay(id: $0.id, streamId: $0.stream_id, title: $0.title,
                         duration: $0.duration, viewCount: $0.views,
                         availableUntil: $0.until.flatMap { ISO8601DateFormatter().date(from: $0) })
        }
    }
}
