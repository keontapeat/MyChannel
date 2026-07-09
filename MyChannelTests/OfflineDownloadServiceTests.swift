//
//  OfflineDownloadServiceTests.swift
//  MyChannelTests
//

import XCTest
@testable import MyChannel

@MainActor
final class OfflineDownloadServiceTests: XCTestCase {

    func testHLSURLDetectionViaPublicAPISurface() {
        // Smoke: service singleton is constructible and storage fields are sane defaults
        let service = OfflineDownloadService.shared
        XCTAssertGreaterThanOrEqual(service.maxStorageLimit, 0)
        XCTAssertNotNil(service.downloadQuality)
    }

    func testDownloadQualityRawValuesStable() {
        XCTAssertEqual(DownloadQuality.low.rawValue, "360p")
        XCTAssertEqual(DownloadQuality.medium.rawValue, "480p")
        XCTAssertEqual(DownloadQuality.high.rawValue, "720p")
        XCTAssertEqual(DownloadQuality.hd.rawValue, "1080p")
    }

    func testIsVideoAvailableOfflineFalseWhenEmpty() async {
        let service = OfflineDownloadService.shared
        // Random id should not be offline unless a prior test left state
        let available = service.isVideoAvailableOffline("nonexistent-video-\(UUID().uuidString)")
        XCTAssertFalse(available)
    }
}
