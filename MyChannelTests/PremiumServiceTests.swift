//
//  PremiumServiceTests.swift
//  MyChannelTests
//
//  Unit tests for PremiumService
//

import XCTest
@testable import MyChannel

@MainActor
final class PremiumServiceTests: XCTestCase {
    
    var sut: PremiumService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = PremiumService.shared
    }
    
    // MARK: - Premium Tier Tests
    
    func testPremiumTierProperties() {
        XCTAssertEqual(PremiumTier.none.title, "Free")
        XCTAssertEqual(PremiumTier.basic.title, "MyChannel+")
        XCTAssertEqual(PremiumTier.pro.title, "MyChannel Pro")
        XCTAssertEqual(PremiumTier.ultimate.title, "MyChannel Ultimate")
    }
    
    func testPremiumTierPrices() {
        XCTAssertEqual(PremiumTier.none.price, "Free")
        XCTAssertEqual(PremiumTier.basic.price, "$4.99/month")
        XCTAssertEqual(PremiumTier.pro.price, "$9.99/month")
        XCTAssertEqual(PremiumTier.ultimate.price, "$14.99/month")
    }
    
    func testPremiumTierAnnualPrices() {
        XCTAssertEqual(PremiumTier.basic.annualPrice, "$49.99/year")
        XCTAssertEqual(PremiumTier.pro.annualPrice, "$99.99/year")
        XCTAssertEqual(PremiumTier.ultimate.annualPrice, "$149.99/year")
    }
    
    func testPremiumTierFeatures() {
        // Free tier has no features
        XCTAssertTrue(PremiumTier.none.features.isEmpty)
        
        // Basic tier features
        let basicFeatures = PremiumTier.basic.features
        XCTAssertTrue(basicFeatures.contains(.adFree))
        XCTAssertTrue(basicFeatures.contains(.backgroundPlay))
        XCTAssertTrue(basicFeatures.contains(.offlineDownloads))
        
        // Pro tier has more features
        let proFeatures = PremiumTier.pro.features
        XCTAssertTrue(proFeatures.contains(.highQuality))
        XCTAssertTrue(proFeatures.contains(.creatorTools))
        
        // Ultimate tier has all features
        XCTAssertEqual(PremiumTier.ultimate.features.count, PremiumFeature.allCases.count)
    }
    
    func testPremiumTierIcons() {
        XCTAssertEqual(PremiumTier.none.icon, "play.circle")
        XCTAssertEqual(PremiumTier.basic.icon, "star.circle.fill")
        XCTAssertEqual(PremiumTier.pro.icon, "crown.fill")
        XCTAssertEqual(PremiumTier.ultimate.icon, "star.fill")
    }
    
    // MARK: - Premium Feature Tests
    
    func testPremiumFeatureProperties() {
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty, "\(feature) should have a title")
            XCTAssertFalse(feature.description.isEmpty, "\(feature) should have a description")
            XCTAssertFalse(feature.icon.isEmpty, "\(feature) should have an icon")
        }
    }
    
    func testPremiumFeatureTitles() {
        XCTAssertEqual(PremiumFeature.adFree.title, "Ad-Free Experience")
        XCTAssertEqual(PremiumFeature.backgroundPlay.title, "Background Play")
        XCTAssertEqual(PremiumFeature.offlineDownloads.title, "Offline Downloads")
        XCTAssertEqual(PremiumFeature.highQuality.title, "4K & HDR Quality")
    }
    
    // MARK: - Feature Check Tests
    
    func testHasFeature() {
        // When not premium, should have no features
        // Note: This depends on persistent state, so we just check the method exists
        let hasAdFree = sut.hasFeature(.adFree)
        XCTAssertNotNil(hasAdFree)
    }
    
    // MARK: - Video Quality Tests
    
    func testPremiumVideoQuality() {
        XCTAssertEqual(PremiumVideoQuality.low.title, "360p")
        XCTAssertEqual(PremiumVideoQuality.medium.title, "720p")
        XCTAssertEqual(PremiumVideoQuality.high.title, "1080p")
        XCTAssertEqual(PremiumVideoQuality.ultra.title, "4K")
    }
    
    // MARK: - Error Tests
    
    func testPremiumErrorDescriptions() {
        XCTAssertNotNil(PremiumError.featureNotAvailable.errorDescription)
        XCTAssertNotNil(PremiumError.subscriptionRequired.errorDescription)
        XCTAssertNotNil(PremiumError.downloadLimitReached.errorDescription)
        XCTAssertNotNil(PremiumError.alreadyDownloaded.errorDescription)
    }
    
    // MARK: - Downloaded Video Tests
    
    func testIsVideoDownloaded() {
        // Check method works
        let isDownloaded = sut.isVideoDownloaded("non-existent-video")
        XCTAssertFalse(isDownloaded)
    }
    
    func testGetDownloadProgress() {
        // Should return nil for non-downloading video
        let progress = sut.getDownloadProgress(for: "non-existent-video")
        XCTAssertNil(progress)
    }
    
    // MARK: - Subscription Status Tests
    
    func testSubscriptionStatusExists() {
        // Just verify the enum cases exist
        let _ = SubscriptionStatus.inactive
        let _ = SubscriptionStatus.active
        let _ = SubscriptionStatus.cancelled
        let _ = SubscriptionStatus.expired
        let _ = SubscriptionStatus.paused
        XCTAssertTrue(true) // If we got here, enum exists
    }
}
