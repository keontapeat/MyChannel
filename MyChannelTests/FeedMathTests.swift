//
//  FeedMathTests.swift
//  MyChannelTests
//
//  Regression tests for paged-feed index math. Guards the Flicks crashes where an
//  empty feed produced a `0...(-1)` range and where a stale index ran past the end.
//

import XCTest
@testable import MyChannel

final class FeedMathTests: XCTestCase {

    // MARK: - preloadRange

    func testEmptyFeedReturnsNil() {
        // The crash: total == 0 made `0...(-1)`, a fatal range error.
        XCTAssertNil(FeedMath.preloadRange(around: 0, before: 1, after: 5, total: 0))
        XCTAssertNil(FeedMath.preloadRange(around: 3, before: 2, after: 2, total: 0))
    }

    func testSingleItemFeed() {
        let range = FeedMath.preloadRange(around: 0, before: 1, after: 7, total: 1)
        XCTAssertEqual(range, 0...0)
    }

    func testRangeClampedToBounds() {
        // index near the end must not exceed total-1
        let range = FeedMath.preloadRange(around: 9, before: 1, after: 7, total: 10)
        XCTAssertEqual(range, 8...9)
    }

    func testRangeClampedAtStart() {
        let range = FeedMath.preloadRange(around: 0, before: 5, after: 3, total: 10)
        XCTAssertEqual(range, 0...3)
    }

    func testNormalMidFeedWindow() {
        let range = FeedMath.preloadRange(around: 5, before: 1, after: 3, total: 20)
        XCTAssertEqual(range, 4...8)
    }

    func testStaleIndexPastEndDoesNotCrash() {
        // Feed shrank (dead URLs filtered) but index is stale → clamp, don't trap.
        let range = FeedMath.preloadRange(around: 50, before: 1, after: 7, total: 10)
        XCTAssertEqual(range, 9...9)
    }

    func testNegativeWindowTreatedAsZero() {
        let range = FeedMath.preloadRange(around: 5, before: -3, after: -3, total: 20)
        XCTAssertEqual(range, 5...5)
    }

    // MARK: - isValidIndex

    func testIsValidIndex() {
        XCTAssertTrue(FeedMath.isValidIndex(0, total: 1))
        XCTAssertTrue(FeedMath.isValidIndex(9, total: 10))
        XCTAssertFalse(FeedMath.isValidIndex(10, total: 10))
        XCTAssertFalse(FeedMath.isValidIndex(-1, total: 10))
        XCTAssertFalse(FeedMath.isValidIndex(0, total: 0))
    }

    func testFeedPageSizeIs24() {
        XCTAssertEqual(FeedMath.feedPageSize, 24)
    }

    func testClampIndexAfterFeedShrink() {
        XCTAssertEqual(FeedMath.clampIndex(50, total: 10), 9)
        XCTAssertEqual(FeedMath.clampIndex(-3, total: 10), 0)
        XCTAssertEqual(FeedMath.clampIndex(0, total: 0), 0)
    }

    func testSafeElementReturnsNilForStaleIndex() {
        let items = ["a", "b", "c"]
        XCTAssertEqual(FeedMath.safeElement(items, index: 1), "b")
        XCTAssertNil(FeedMath.safeElement(items, index: 99))
        XCTAssertNil(FeedMath.safeElement([], index: 0))
    }

    func testFlicksCrashIndexRegression() {
        // Reproduce the `0...(-1)` trap class without executing invalid ranges.
        for total in [0, 1, 5, 10] {
            for index in [-1, 0, 3, 50] {
                let range = FeedMath.preloadRange(around: index, before: 1, after: 5, total: total)
                if total == 0 {
                    XCTAssertNil(range)
                } else if let range {
                    XCTAssertGreaterThanOrEqual(range.lowerBound, 0)
                    XCTAssertLessThan(range.upperBound, total)
                }
                let clamped = FeedMath.clampIndex(index, total: total)
                XCTAssertTrue(FeedMath.isValidIndex(clamped, total: total) || total == 0)
            }
        }
    }

    func testFlicksPrefetchWindowIsVisiblePlusOne() {
        XCTAssertEqual(FeedMath.flicksPrefetchWindow(focusedIndex: 3, total: 10), 3...4)
        XCTAssertNil(FeedMath.flicksPrefetchWindow(focusedIndex: 0, total: 0))
    }
}
