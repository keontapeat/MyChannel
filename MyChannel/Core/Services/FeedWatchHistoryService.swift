//
//  FeedWatchHistoryService.swift
//  MyChannel
//
//  Phase 273: Feed Watch History Integration — watched indicators,
//  continue-watching row, progress bars, duplicate filtering.
//  Uses Firestore + feed heuristics.
//

import Foundation

struct FeedWatchHistoryItem: Codable, Identifiable {
    let id: String
    let videoId: String
    let progress: Double
    let lastWatchedAt: Date
    let isCompleted: Bool
}

@MainActor
final class FeedWatchHistoryService: ObservableObject {
    static let shared = FeedWatchHistoryService()
    private init() {}

    @Published private(set) var history: [FeedWatchHistoryItem] = []

    func syncFromProgress(_ progressItems: [WatchProgress]) {
        guard AppConfig.Features.enableFeedWatchHistory else { return }
        history = progressItems.map {
            FeedWatchHistoryItem(id: $0.id, videoId: $0.videoId, progress: $0.completionPct, lastWatchedAt: $0.lastWatchedAt, isCompleted: $0.isCompleted)
        }.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    func filterDuplicates(candidateVideoIds: [String]) -> [String] {
        let watched = Set(history.filter { $0.isCompleted }.map(\ .videoId))
        return candidateVideoIds.filter { !watched.contains($0) }
    }

    func continueWatching(limit: Int = 10) -> [FeedWatchHistoryItem] {
        Array(history.filter { !$0.isCompleted }.prefix(limit))
    }
}
