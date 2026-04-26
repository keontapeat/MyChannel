//
//  ProfileActivityFeedService.swift
//  MyChannel
//
//  Phase 251: Profile Activity Feed & Notifications.
//  Recent activity timeline, follower milestones, content drops,
//  community highlights, activity privacy controls.
//  Uses `mychannel-events` Cloud Run.
//

import Foundation

// MARK: - Models

struct ActivityItem: Codable, Identifiable {
    let id: String
    let creatorId: String
    let type: ActivityType
    let title: String
    let description: String?
    let mediaURL: String?
    let timestamp: Date
    let isPublic: Bool

    enum ActivityType: String, Codable {
        case newVideo, newShort, newPost, milestone, livestream, communityHighlight, collaboration
    }
}

struct ActivityPrivacy: Codable {
    let creatorId: String
    let showActivity: Bool
    let visibleTypes: [String]
    let hideFrom: [String]
}

// MARK: - Service

@MainActor
final class ProfileActivityFeedService: ObservableObject {
    static let shared = ProfileActivityFeedService()
    private init() {}

    @Published private(set) var activities: [ActivityItem] = []
    @Published private(set) var privacy: ActivityPrivacy?

    func fetchActivity(creatorId: String, limit: Int = 20) async throws {
        guard AppConfig.Features.enableProfileActivityFeed else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let limit: Int }
        struct RawA: Decodable { let id: String; let type: String; let title: String; let desc: String?; let media: String?; let ts: String?; let `public`: Bool }
        struct Raw: Decodable { let activities: [RawA]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "fetch_profile_activity", creatorId: creatorId, limit: limit)
        )
        activities = (r.activities ?? []).map {
            ActivityItem(id: $0.id, creatorId: creatorId, type: .init(rawValue: $0.type) ?? .newPost,
                         title: $0.title, description: $0.desc, mediaURL: $0.media,
                         timestamp: $0.ts.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(), isPublic: $0.public)
        }
    }

    func updatePrivacy(creatorId: String, showActivity: Bool, visibleTypes: [String]) async throws {
        guard AppConfig.Features.enableProfileActivityFeed else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let show: Bool; let types: [String] }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "update_activity_privacy", creatorId: creatorId, show: showActivity, types: visibleTypes)
        )
        privacy = ActivityPrivacy(creatorId: creatorId, showActivity: showActivity, visibleTypes: visibleTypes, hideFrom: [])
    }

    func postActivity(creatorId: String, type: ActivityItem.ActivityType, title: String, description: String?) async throws -> ActivityItem {
        guard AppConfig.Features.enableProfileActivityFeed else {
            return ActivityItem(id: "", creatorId: creatorId, type: type, title: title, description: description,
                                 mediaURL: nil, timestamp: Date(), isPublic: true)
        }
        struct Req: Encodable { let task: String; let creatorId: String; let type: String; let title: String; let desc: String? }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "post_activity", creatorId: creatorId, type: type.rawValue, title: title, desc: description)
        )
        let item = ActivityItem(id: r.id, creatorId: creatorId, type: type, title: title, description: description,
                                  mediaURL: nil, timestamp: Date(), isPublic: true)
        activities.insert(item, at: 0)
        return item
    }
}
