//
//  SubscriptionsFeedService.swift
//  MyChannel
//
//  Subscription feed: chronological + algorithmic feed from subscribed
//  creators, new upload notifications, feed pagination.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct SubscriptionsFeedItem: Codable, Identifiable {
    let id: String
    let videoId: String
    let creatorId: String
    let creatorName: String
    let creatorImageURL: String?
    let title: String
    let thumbnailURL: String?
    let publishedAt: Date
    let isShort: Bool
    let isLive: Bool
}

@MainActor
final class SubscriptionsFeedService: ObservableObject {
    static let shared = SubscriptionsFeedService()
    private init() {}
    @Published private(set) var feed: [SubscriptionsFeedItem] = []
    @Published private(set) var hasMore: Bool = true
    private var lastDocId: String?

    func fetchFeed(userId: String, limit: Int = 20, refresh: Bool = false) async throws {
        if refresh { feed = []; lastDocId = nil; hasMore = true }
        struct Req: Encodable { let task: String; let userId: String; let limit: Int; let cursor: String? }
        struct RawI: Decodable { let id: String; let video_id: String; let creator_id: String; let creator_name: String; let creator_image: String?; let title: String; let thumbnail: String?; let published: String?; let is_short: Bool?; let is_live: Bool? }
        struct Raw: Decodable { let items: [RawI]?; let has_more: Bool?; let cursor: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "fetch_subscriptions_feed", userId: userId, limit: limit, cursor: lastDocId))
        let newItems = (r.items ?? []).map {
            SubscriptionsFeedItem(id: $0.id, videoId: $0.video_id, creatorId: $0.creator_id, creatorName: $0.creator_name,
                creatorImageURL: $0.creator_image, title: $0.title, thumbnailURL: $0.thumbnail,
                publishedAt: $0.published.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(), isShort: $0.is_short ?? false, isLive: $0.is_live ?? false)
        }
        feed.append(contentsOf: newItems)
        hasMore = r.has_more ?? false
        lastDocId = r.cursor
    }
}
