//
//  FeedSocialSignalsService.swift
//  MyChannel
//
//  Phase 274: Feed Social Signals — friend activity indicators,
//  trending badges, social proof counts, mutual viewer highlights.
//  Uses `creator-relations-ai` Cloud Run.
//

import Foundation

struct FeedSocialSignal: Codable, Identifiable {
    let id: String
    let videoId: String
    let friendsWhoWatched: [String]
    let likedByCount: Int
    let sharedByCount: Int
    let trendingBadge: String?
}

@MainActor
final class FeedSocialSignalsService: ObservableObject {
    static let shared = FeedSocialSignalsService()
    private init() {}

    @Published private(set) var signals: [String: FeedSocialSignal] = [:]

    func fetchSignals(userId: String, videoIds: [String]) async throws {
        guard AppConfig.Features.enableFeedSocialSignals else { return }
        struct Req: Encodable { let task: String; let userId: String; let videoIds: [String] }
        struct RawS: Decodable { let videoId: String; let friends: [String]?; let liked: Int?; let shared: Int?; let badge: String? }
        struct Raw: Decodable { let signals: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict", body: Req(task: "feed_social_signals", userId: userId, videoIds: videoIds))
        signals = Dictionary(uniqueKeysWithValues: (r.signals ?? []).map {
            let s = FeedSocialSignal(id: UUID().uuidString, videoId: $0.videoId, friendsWhoWatched: $0.friends ?? [], likedByCount: $0.liked ?? 0, sharedByCount: $0.shared ?? 0, trendingBadge: $0.badge)
            return ($0.videoId, s)
        })
    }
}
