//
//  VideoPlaybackQueueTests.swift
//  MyChannelTests
//

import XCTest
@testable import MyChannel

final class VideoPlaybackQueueTests: XCTestCase {

    private func video(_ id: String) -> Video {
        Video(
            id: id,
            title: id,
            description: "",
            thumbnailURL: "https://example.com/\(id).jpg",
            videoURL: "https://example.com/\(id).mp4",
            duration: 60,
            viewCount: 0,
            likeCount: 0,
            creator: User.sampleUsers[0],
            category: .entertainment
        )
    }

    func testSetQueueFindsStartingVideo() {
        let a = video("a")
        let b = video("b")
        let c = video("c")
        var q = VideoPlaybackQueue()
        q.set(queue: [a, b, c], startingAt: b)
        XCTAssertEqual(q.index, 1)
        XCTAssertEqual(q.current?.id, b.id)
        XCTAssertEqual(q.upNext?.id, c.id)
        XCTAssertTrue(q.hasPrevious)
        XCTAssertTrue(q.hasNext)
    }

    func testAdvanceAndRetreat() {
        let a = video("a")
        let b = video("b")
        var q = VideoPlaybackQueue()
        q.set(queue: [a, b], startingAt: a)
        XCTAssertEqual(q.advance()?.id, b.id)
        XCTAssertNil(q.advance())
        XCTAssertEqual(q.retreat()?.id, a.id)
        XCTAssertNil(q.retreat())
    }

    func testAppendDedupes() {
        let a = video("a")
        var q = VideoPlaybackQueue()
        q.append(a)
        q.append(a)
        XCTAssertEqual(q.videos.count, 1)
    }

    func testResetClears() {
        var q = VideoPlaybackQueue()
        q.append(video("a"))
        q.reset()
        XCTAssertTrue(q.videos.isEmpty)
        XCTAssertEqual(q.index, 0)
    }
}
