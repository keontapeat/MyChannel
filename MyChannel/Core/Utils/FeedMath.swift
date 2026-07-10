//
//  FeedMath.swift
//  MyChannel
//
//  Pure, testable helpers for paged-feed index math (Flicks/Shorts/Home).
//  Centralizes the bounds logic that previously crashed with empty feeds
//  (e.g. `0...(-1)` ranges) or stale indices after the feed was filtered.
//

import Foundation

enum FeedMath {
    /// Standard page size for home/Flicks/Shorts list pagination (performance rule: 24).
    static let feedPageSize: Int = 24

    /// The inclusive index range to preload around `index`, clamped to the feed.
    /// Returns `nil` when the feed is empty or the window collapses — callers must
    /// skip preloading rather than force a `start...end` that could trap.
    ///
    /// - Parameters:
    ///   - index: the focused item index (may be stale / out of range).
    ///   - before: how many items to preload behind `index`.
    ///   - after: how many items to preload ahead of `index`.
    ///   - total: current item count in the feed.
    static func preloadRange(around index: Int, before: Int, after: Int, total: Int) -> ClosedRange<Int>? {
        guard total > 0 else { return nil }
        let start = max(0, index - max(0, before))
        let end = min(total - 1, index + max(0, after))
        guard start <= end else { return nil }
        return start...end
    }

    /// True when `index` is a valid subscript into a collection of `total` items.
    static func isValidIndex(_ index: Int, total: Int) -> Bool {
        index >= 0 && index < total
    }

    /// Clamps a potentially stale index after the feed shrinks (filter/blacklist).
    /// Returns `0` when the feed is empty.
    static func clampIndex(_ index: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(max(0, index), total - 1)
    }

    /// Flicks vertical pager: preload current + next item only (`visible+1` rule).
    static func flicksPrefetchWindow(focusedIndex: Int, total: Int) -> ClosedRange<Int>? {
        preloadRange(around: focusedIndex, before: 0, after: 1, total: total)
    }

    /// Safe subscript helper — returns `nil` instead of trapping on stale indices.
    static func safeElement<T>(_ collection: [T], index: Int) -> T? {
        guard isValidIndex(index, total: collection.count) else { return nil }
        return collection[index]
    }
}
