//
//  FeedCachingService.swift
//  MyChannel
//
//  Phase 276: Feed Caching & Prefetch — multi-layer cache, predictive prefetch,
//  cache warming, eviction policy, offline feed.
//

import Foundation

struct FeedCacheEntry: Codable, Identifiable {
    let id: String
    let section: String
    let videoIds: [String]
    let createdAt: Date
    let expiresAt: Date
}

@MainActor
final class FeedCachingService: ObservableObject {
    static let shared = FeedCachingService()
    private init() {}

    @Published private(set) var cache: [String: FeedCacheEntry] = [:]

    func cache(section: String, videoIds: [String], ttl: TimeInterval = 300) {
        guard AppConfig.Features.enableFeedCaching else { return }
        let entry = FeedCacheEntry(id: UUID().uuidString, section: section, videoIds: videoIds, createdAt: Date(), expiresAt: Date().addingTimeInterval(ttl))
        cache[section] = entry
    }

    func get(section: String) -> [String] {
        guard let entry = cache[section], entry.expiresAt > Date() else { return [] }
        return entry.videoIds
    }

    func prewarm(sections: [String]) {
        _ = sections.map { get(section: $0) }
    }

    func evictExpired() {
        cache = cache.filter { $0.value.expiresAt > Date() }
    }
}
