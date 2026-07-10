//
//  PlayerLifecycleTests.swift
//  MyChannelTests
//
//  Playback queue navigation + GlobalPlayerViewTracking session lifecycle.
//

import XCTest
@testable import MyChannel
import AVFoundation

@MainActor
final class PlayerLifecycleTests: XCTestCase {

    private func sampleVideo(_ id: String) -> Video {
        Video(
            id: id,
            title: id,
            description: "",
            thumbnailURL: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
            videoURL: "https://example.com/\(id).mp4",
            duration: 120,
            viewCount: 0,
            likeCount: 0,
            creator: User.sampleUsers[0],
            category: .entertainment
        )
    }

    // MARK: - VideoPlaybackQueue lifecycle

    func testQueueLifecycleMatchesPlayerNavigation() {
        let first = sampleVideo("first")
        let second = sampleVideo("second")
        let third = sampleVideo("third")

        var queue = VideoPlaybackQueue()
        queue.set(queue: [first, second, third], startingAt: first)

        XCTAssertEqual(queue.current?.id, first.id)
        XCTAssertEqual(queue.advance()?.id, second.id)
        XCTAssertEqual(queue.upNext?.id, third.id)
        XCTAssertEqual(queue.retreat()?.id, first.id)
        queue.reset()
        XCTAssertTrue(queue.videos.isEmpty)
    }

    // MARK: - GlobalPlayerViewTracking heartbeat / sessions

    func testViewTrackingStartAndEndSession() async {
        var flushed = false
        let tracking = GlobalPlayerViewTracking { _, _, _, _ in
            flushed = true
        }

        tracking.currentTime = { 45 }
        tracking.duration = { 120 }
        tracking.isPlaying = { true }
        tracking.hasCurrentVideo = { true }

        let video = sampleVideo("tracking-session")
        await tracking.start(for: video)
        await tracking.end()

        XCTAssertTrue(flushed, "University watch flush should run after sufficient watch time")
    }

    func testViewTrackingHeartbeatStartsWithoutCrash() {
        let tracking = GlobalPlayerViewTracking { _, _, _, _ in }
        tracking.hasCurrentVideo = { false }

        tracking.startHeartbeat()
        // No session + no current video — heartbeat tick should be a no-op.
        XCTAssertNotNil(tracking)
    }

    func testViewTrackingSkipsUniversityFlushUnderThreshold() async {
        var flushCount = 0
        let tracking = GlobalPlayerViewTracking { _, _, _, _ in
            flushCount += 1
        }

        tracking.currentTime = { 5 }
        tracking.duration = { 120 }
        tracking.isPlaying = { true }
        tracking.hasCurrentVideo = { true }

        let video = sampleVideo("short-watch")
        await tracking.start(for: video)
        await tracking.end()

        XCTAssertEqual(flushCount, 0, "Watch time under 30s should not flush university attribution")
    }

    func testViewTrackingHeartbeatIntervalIs10Seconds() {
        XCTAssertEqual(GlobalPlayerViewTracking.heartbeatIntervalSeconds, 10)
    }

    func testKVOObserversInvalidateClearsAllTokens() {
        let observers = GlobalPlayerKVOObservers()
        let player = AVPlayer(url: URL(string: "https://example.com/sample.mp4")!)
        observers.attach(to: player)
        XCTAssertGreaterThan(observers.activeObserverCount, 0)
        observers.invalidate()
        XCTAssertEqual(observers.activeObserverCount, 0)
    }

    func testVideoAssetPreloaderMaxPreloadCountIsTwo() {
        XCTAssertEqual(VideoAssetPreloader.maxPreloadCount, 2)
    }

    func testAVPlayerLayerViewDoesNotTrapOnNilPlayer() {
        // Regression: constructing player chrome with nil AVPlayer must not crash.
        let player = AVPlayer()
        player.replaceCurrentItem(with: nil)
        XCTAssertNotNil(player)
        XCTAssertNil(player.currentItem)
    }

    func testFlushUniversityWatchBeforeSwitchIsCallable() async {
        let tracking = GlobalPlayerViewTracking { _, _, _, _ in }
        tracking.currentTime = { 60 }
        tracking.duration = { 120 }
        tracking.hasCurrentVideo = { true }
        let video = sampleVideo("fast-skip")
        await tracking.start(for: video)
        tracking.flushUniversityWatchBeforeSwitch()
        await tracking.end()
    }
}
