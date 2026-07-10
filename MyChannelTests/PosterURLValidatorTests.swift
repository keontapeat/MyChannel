//
//  PosterURLValidatorTests.swift
//  MyChannelTests
//

import XCTest
@testable import MyChannel

final class PosterURLValidatorTests: XCTestCase {

    func testTMDBPosterAllowed() {
        XCTAssertTrue(PosterURLValidator.isAllowed("https://image.tmdb.org/t/p/w500/abc.jpg"))
    }

    func testWikipediaPosterBlocked() {
        XCTAssertFalse(PosterURLValidator.isAllowed("https://upload.wikimedia.org/wikipedia/en/poster.jpg"))
    }

    func testSVGPosterBlocked() {
        XCTAssertFalse(PosterURLValidator.isAllowed("https://cdn.example.com/logo.svg"))
    }

    func testYouTubeThumbnailAllowed() {
        XCTAssertTrue(PosterURLValidator.isAllowed("https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"))
    }
}
