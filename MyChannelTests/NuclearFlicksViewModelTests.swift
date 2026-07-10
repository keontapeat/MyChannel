//
//  NuclearFlicksViewModelTests.swift
//  MyChannelTests
//
//  Pagination / blacklist helpers for Flicks feed safety.
//

import XCTest
@testable import MyChannel

final class NuclearFlicksViewModelTests: XCTestCase {

    func testPreloadRangeDoesNotCrashAtEdges() {
        // FeedMath guards Flicks index crashes when near start/end.
        XCTAssertNil(FeedMath.preloadRange(around: 0, before: 1, after: 5, total: 0))
        let start = FeedMath.preloadRange(around: 0, before: 1, after: 5, total: 10)
        XCTAssertNotNil(start)
        if let start {
            XCTAssertEqual(start.lowerBound, 0)
            XCTAssertLessThanOrEqual(start.upperBound, 9)
        }
        let end = FeedMath.preloadRange(around: 9, before: 1, after: 5, total: 10)
        XCTAssertNotNil(end)
        if let end {
            XCTAssertEqual(end.upperBound, 9)
        }
    }

    func testRemoveUnavailableFlickShrinksFeed() async {
        let vm = NuclearFlicksViewModel()
        // Demo feed is always available offline for tests.
        await vm.loadInitialFlicks()
        let before = vm.flicks.count
        XCTAssertGreaterThan(before, 0)
        let victim = vm.flicks[0].id
        vm.removeUnavailableFlick(id: victim)
        XCTAssertFalse(vm.flicks.contains(where: { $0.id == victim }))
        // Backfill keeps a playable floor when the feed would get too thin.
        XCTAssertGreaterThanOrEqual(vm.flicks.count, 8)
    }
}
