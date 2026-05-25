//
//  FeedPaginationService.swift
//  MyChannel
//
//  Phase 263: Feed Pull-to-Refresh & Pagination — cursor-based pagination,
//  prefetch threshold, infinite scroll, stale-while-revalidate, background refresh.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct PaginationState: Codable {
    let cursor: String?
    let hasMore: Bool
    let totalLoaded: Int
    let pageSize: Int
    let isRefreshing: Bool
}

@MainActor
final class FeedPaginationService: ObservableObject {
    static let shared = FeedPaginationService()
    private init() {}
    @Published private(set) var state = PaginationState(cursor: nil, hasMore: true, totalLoaded: 0, pageSize: 20, isRefreshing: false)
    @Published private(set) var lastRefreshAt: Date?
    private let prefetchThreshold = 5

    func loadNextPage(userId: String) async throws -> [String] {
        guard AppConfig.Features.enableFeedPagination, state.hasMore else { return [] }
        struct Req: Encodable { let task: String; let userId: String; let cursor: String?; let pageSize: Int }
        struct Raw: Decodable { let ids: [String]?; let cursor: String?; let hasMore: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "feed_next_page", userId: userId, cursor: state.cursor, pageSize: state.pageSize))
        let ids = r.ids ?? []
        state = PaginationState(cursor: r.cursor, hasMore: r.hasMore ?? false,
            totalLoaded: state.totalLoaded + ids.count, pageSize: state.pageSize, isRefreshing: false)
        return ids
    }

    func refresh(userId: String) async throws -> [String] {
        state = PaginationState(cursor: nil, hasMore: true, totalLoaded: 0, pageSize: state.pageSize, isRefreshing: true)
        let ids = try await loadNextPage(userId: userId)
        lastRefreshAt = Date()
        return ids
    }

    func shouldPrefetch(currentIndex: Int) -> Bool {
        state.hasMore && currentIndex >= state.totalLoaded - prefetchThreshold
    }

    func isStale(maxAge: TimeInterval = 300) -> Bool {
        guard let last = lastRefreshAt else { return true }
        return Date().timeIntervalSince(last) > maxAge
    }
}
