//
//  AppConfigTests.swift
//  MyChannelTests
//
//  Unit tests for AppConfig
//

import XCTest
@testable import MyChannel

final class AppConfigTests: XCTestCase {
    
    // MARK: - Environment Tests
    
    func testEnvironmentDisplayNames() {
        XCTAssertEqual(AppConfig.Environment.development.displayName, "Development")
        XCTAssertEqual(AppConfig.Environment.staging.displayName, "Staging")
        XCTAssertEqual(AppConfig.Environment.production.displayName, "Production")
    }
    
    func testEnvironmentAPIBaseURLs() {
        XCTAssertTrue(AppConfig.Environment.development.apiBaseURL.contains("dev"))
        XCTAssertTrue(AppConfig.Environment.staging.apiBaseURL.contains("staging"))
        XCTAssertTrue(AppConfig.Environment.production.apiBaseURL.contains("api.mychannel"))
    }
    
    // MARK: - Video Configuration Tests
    
    func testVideoQualityBitrates() {
        XCTAssertEqual(AppConfig.Video.Quality.quality240p.bitrate, 300_000)
        XCTAssertEqual(AppConfig.Video.Quality.quality720p.bitrate, 5_000_000)
        XCTAssertEqual(AppConfig.Video.Quality.quality1080p.bitrate, 8_000_000)
        XCTAssertEqual(AppConfig.Video.Quality.quality4K.bitrate, 35_000_000)
    }
    
    func testVideoQualityDisplayNames() {
        XCTAssertEqual(AppConfig.Video.Quality.quality720p.displayName, "720p")
        XCTAssertEqual(AppConfig.Video.Quality.quality4K.displayName, "4K")
    }
    
    func testDefaultVideoQuality() {
        XCTAssertEqual(AppConfig.Video.defaultQuality, .quality720p)
    }
    
    func testSupportedFormats() {
        XCTAssertTrue(AppConfig.Video.supportedFormats.contains("mp4"))
        XCTAssertTrue(AppConfig.Video.supportedFormats.contains("mov"))
    }
    
    func testMaxDuration() {
        // 10 hours in seconds
        XCTAssertEqual(AppConfig.Video.maxDuration, 36000)
    }
    
    // MARK: - API Configuration Tests
    
    func testAPIVersion() {
        XCTAssertEqual(AppConfig.API.version, "v1")
    }
    
    func testAPITimeout() {
        XCTAssertEqual(AppConfig.API.timeout, 30.0)
    }
    
    func testAPIEndpoints() {
        XCTAssertEqual(AppConfig.API.Endpoints.videos, "/videos")
        XCTAssertEqual(AppConfig.API.Endpoints.users, "/users")
        XCTAssertEqual(AppConfig.API.Endpoints.analytics, "/analytics")
    }
    
    // MARK: - Feature Flags Tests
    
    func testFeatureFlags() {
        // These should all be enabled by default
        XCTAssertTrue(AppConfig.Features.enableFlicks)
        XCTAssertTrue(AppConfig.Features.enableLiveStreaming)
        XCTAssertTrue(AppConfig.Features.enableAIRecommendations)
        XCTAssertTrue(AppConfig.Features.enablePremiumFeatures)
        XCTAssertTrue(AppConfig.Features.enableAnalytics)
        XCTAssertTrue(AppConfig.Features.enablePushNotifications)
        XCTAssertTrue(AppConfig.Features.enableDeepLinks)
        XCTAssertTrue(AppConfig.Features.enableOfflineDownload)
        XCTAssertTrue(AppConfig.Features.enableAds)
    }
    
    // MARK: - Performance Settings Tests
    
    func testPerformanceSettings() {
        XCTAssertEqual(AppConfig.Performance.maxVideoPreload, 3)
        XCTAssertEqual(AppConfig.Performance.defaultVideoQuality, "720p")
        XCTAssertGreaterThan(AppConfig.Performance.maxCacheSize, 0)
    }
    
    // MARK: - Verification Configuration Tests
    
    func testVerificationMilestones() {
        XCTAssertEqual(AppConfig.Verification.subscriberMilestone, 100_000)
        XCTAssertEqual(AppConfig.Verification.totalViewsMilestone, 5_000_000)
        XCTAssertEqual(AppConfig.Verification.minimumVideoCount, 50)
        XCTAssertEqual(AppConfig.Verification.minimumAccountAgeDays, 30)
    }
    
    // MARK: - UI Configuration Tests
    
    func testUIConfiguration() {
        XCTAssertEqual(AppConfig.UI.animationDuration, 0.3)
        XCTAssertEqual(AppConfig.UI.tabBarHeight, 83)
        XCTAssertEqual(AppConfig.UI.miniPlayerHeight, 60)
        XCTAssertEqual(AppConfig.UI.maxVideoAspectRatio, 16/9)
    }
    
    // MARK: - Analytics Configuration Tests
    
    func testAnalyticsEventNames() {
        XCTAssertEqual(AppConfig.Analytics.videoWatchEvent, "video_watch")
        XCTAssertEqual(AppConfig.Analytics.videoLikeEvent, "video_like")
        XCTAssertEqual(AppConfig.Analytics.videoShareEvent, "video_share")
    }
    
    func testSessionTimeout() {
        // 30 minutes in seconds
        XCTAssertEqual(AppConfig.Analytics.sessionTimeout, 1800)
    }
    
    // MARK: - Security Configuration Tests
    
    func testSecuritySettings() {
        XCTAssertTrue(AppConfig.Security.enableBiometricAuth)
        XCTAssertEqual(AppConfig.Security.maxLoginAttempts, 5)
        // 24 hours in seconds
        XCTAssertEqual(AppConfig.Security.sessionDuration, 86400)
    }
    
    // MARK: - Storage Configuration Tests
    
    func testStoragePaths() {
        XCTAssertEqual(AppConfig.Storage.thumbnailPath, "thumbnails")
        XCTAssertEqual(AppConfig.Storage.videoPath, "videos")
        XCTAssertEqual(AppConfig.Storage.profileImagePath, "profile-images")
    }
    
    func testMaxFileSize() {
        // 2GB
        XCTAssertEqual(AppConfig.Storage.maxFileSize, 2 * 1024 * 1024 * 1024)
    }
    
    // MARK: - URL Schemes Tests
    
    func testURLSchemes() {
        XCTAssertEqual(AppConfig.URLSchemes.main, "mychannel")
        XCTAssertTrue(AppConfig.URLSchemes.video.hasPrefix("mychannel://"))
    }
    
    // MARK: - Social Configuration Tests
    
    func testSocialHandles() {
        XCTAssertEqual(AppConfig.Social.twitterHandle, "@MyChannelApp")
        XCTAssertEqual(AppConfig.Social.supportEmail, "support@mychannel.app")
    }
    
    func testSocialLoginFlags() {
        XCTAssertTrue(AppConfig.Social.enableAppleLogin)
        XCTAssertTrue(AppConfig.Social.enableGoogleLogin)
    }
    
    // MARK: - App Info Tests
    
    func testAppInfo() {
        XCTAssertEqual(AppConfig.App.name, "MyChannel")
        XCTAssertFalse(AppConfig.App.version.isEmpty)
        XCTAssertFalse(AppConfig.App.build.isEmpty)
    }
    
    // MARK: - Environment Detection Tests
    
    func testEnvironmentDetection() {
        // In test environment, isDebug should be true
        #if DEBUG
        XCTAssertTrue(AppConfig.isDebug)
        #endif
    }
}
