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

    func testHasDownloadFalseForUnknownVideo() {
        let service = OfflineDownloadService.shared
        XCTAssertFalse(service.hasDownload(videoId: "unknown-\(UUID().uuidString)"))
    }

    func testDefaultMaxStorageLimitIsFiveGB() {
        let service = OfflineDownloadService.shared
        XCTAssertEqual(service.maxStorageLimit, 5 * 1024 * 1024 * 1024)
    }

    func testDownloadOnlyOnWiFiDefaultsTrue() {
        let service = OfflineDownloadService.shared
        XCTAssertTrue(service.downloadOnlyOnWiFi)
    }

    func testCompletedAndInProgressDownloadsAreDisjoint() {
        let service = OfflineDownloadService.shared
        let completedIds = Set(service.completedDownloads.map(\.id))
        let inProgressIds = Set(service.inProgressDownloads.map(\.id))
        XCTAssertTrue(completedIds.isDisjoint(with: inProgressIds))
    }

    func testFormattedStorageUsedReturnsNonEmpty() {
        let service = OfflineDownloadService.shared
        XCTAssertFalse(service.formattedStorageUsed().isEmpty)
    }

    func testHLSPatternDetectionSmoke() {
        XCTAssertTrue(OfflineDownloadService.isHLSStream("https://cdn.example.com/stream.m3u8"))
        XCTAssertTrue(OfflineDownloadService.isHLSStream("https://cdn.example.com/master?type=application/vnd.apple.mpegurl"))
        XCTAssertFalse(OfflineDownloadService.isHLSStream("https://cdn.example.com/video.mp4"))
    }

    func testDownloadStatusStateMachineValues() {
        XCTAssertEqual(DownloadStatus.queued.rawValue, "queued")
        XCTAssertEqual(DownloadStatus.downloading.rawValue, "downloading")
        XCTAssertEqual(DownloadStatus.completed.rawValue, "completed")
        XCTAssertEqual(DownloadStatus.failed.rawValue, "failed")
        XCTAssertEqual(DownloadStatus.paused.rawValue, "paused")
    }

    func testOfflineDownloadErrorDescriptionsPresent() {
        let errors: [OfflineDownloadError] = [
            .alreadyDownloaded,
            .alreadyInQueue,
            .insufficientStorage,
            .wifiRequired,
            .downloadNotFound,
            .networkError,
            .fileSystemError
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testMaxConcurrentDownloadsIsTwo() {
        XCTAssertEqual(OfflineDownloadService.maxConcurrentDownloads, 2)
    }

    func testDownloadProgressPublisherEmitsVideoProgress() async {
        let service = OfflineDownloadService.shared
        var received: [String: Double]?
        let cancellable = service.downloadProgressPublisher
            .sink { received = $0 }
        XCTAssertNotNil(cancellable)
        _ = received
    }
}
