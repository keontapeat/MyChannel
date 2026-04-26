//
//  FeedQuickActionsService.swift
//  MyChannel
//
//  Phase 271: Feed Quick Actions — inline like/save/share, swipe gestures,
//  long-press menus, quick preview, batch actions.
//  Uses `mychannel-events` Cloud Run.
//

import Foundation

struct FeedQuickAction: Codable, Identifiable {
    let id: String
    let videoId: String
    let action: ActionType
    let performedAt: Date
    let succeeded: Bool
    enum ActionType: String, Codable { case like, save, share, hide, report, preview }
}

@MainActor
final class FeedQuickActionsService: ObservableObject {
    static let shared = FeedQuickActionsService()
    private init() {}

    @Published private(set) var recentActions: [FeedQuickAction] = []

    func perform(videoId: String, action: FeedQuickAction.ActionType, userId: String) async throws {
        guard AppConfig.Features.enableFeedQuickActions else { return }
        struct Req: Encodable { let task: String; let videoId: String; let action: String; let userId: String }
        struct Raw: Decodable { let ok: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "feed_quick_action", videoId: videoId, action: action.rawValue, userId: userId)
        )
        recentActions.insert(FeedQuickAction(id: UUID().uuidString, videoId: videoId, action: action, performedAt: Date(), succeeded: r.ok ?? false), at: 0)
        if recentActions.count > 100 { recentActions = Array(recentActions.prefix(100)) }
    }

    func batchHide(videoIds: [String], userId: String) async throws {
        for id in videoIds { try await perform(videoId: id, action: .hide, userId: userId) }
    }
}
