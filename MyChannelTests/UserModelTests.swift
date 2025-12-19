//
//  UserModelTests.swift
//  MyChannelTests
//
//  Unit tests for User model
//

import XCTest
@testable import MyChannel

final class UserModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testUserInitialization() {
        let user = User(
            id: "test-123",
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            profileImageURL: "https://example.com/avatar.jpg",
            bio: "Test bio",
            subscriberCount: 1000,
            videoCount: 50,
            isVerified: true,
            isCreator: true
        )
        
        XCTAssertEqual(user.id, "test-123")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.subscriberCount, 1000)
        XCTAssertEqual(user.videoCount, 50)
        XCTAssertTrue(user.isVerified)
        XCTAssertTrue(user.isCreator)
    }
    
    // MARK: - Owner Detection Tests
    
    func testIsOwnerWithOwnerEmail() {
        let owner = User(
            username: "owner",
            displayName: "Owner",
            email: "keontapeat@mychannel.live"
        )
        
        XCTAssertTrue(owner.isOwner)
    }
    
    func testIsOwnerWithRegularEmail() {
        let regular = User(
            username: "regular",
            displayName: "Regular User",
            email: "user@example.com"
        )
        
        XCTAssertFalse(regular.isOwner)
    }
    
    func testShouldShowVerificationBadge() {
        let verifiedUser = User(
            username: "verified",
            displayName: "Verified User",
            email: "verified@example.com",
            isVerified: true
        )
        
        let ownerUser = User(
            username: "owner",
            displayName: "Owner",
            email: "keontapeat@gmail.com",
            isVerified: false
        )
        
        let regularUser = User(
            username: "regular",
            displayName: "Regular",
            email: "regular@example.com",
            isVerified: false
        )
        
        XCTAssertTrue(verifiedUser.shouldShowVerificationBadge)
        XCTAssertTrue(ownerUser.shouldShowVerificationBadge) // Owner always verified
        XCTAssertFalse(regularUser.shouldShowVerificationBadge)
    }
    
    // MARK: - Updating User Tests
    
    func testUpdatingUserProperties() {
        let user = User(
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            subscriberCount: 100,
            videoCount: 10
        )
        
        let updated = user.updating(
            videoCount: 15,
            subscriberCount: 150
        )
        
        XCTAssertEqual(updated.videoCount, 15)
        XCTAssertEqual(updated.subscriberCount, 150)
        XCTAssertEqual(updated.username, user.username) // Unchanged
        XCTAssertEqual(updated.email, user.email) // Unchanged
    }
    
    // MARK: - Social Platform Tests
    
    func testSocialPlatformProperties() {
        for platform in SocialPlatform.allCases {
            XCTAssertFalse(platform.displayName.isEmpty, "\(platform) should have display name")
            XCTAssertFalse(platform.iconName.isEmpty, "\(platform) should have icon")
        }
    }
    
    func testSocialLinkInitialization() {
        let link = SocialLink(
            platform: .twitter,
            url: "https://twitter.com/testuser",
            displayName: "@testuser"
        )
        
        XCTAssertEqual(link.platform, .twitter)
        XCTAssertEqual(link.url, "https://twitter.com/testuser")
        XCTAssertEqual(link.displayName, "@testuser")
    }
    
    // MARK: - Membership Tier Tests
    
    func testMembershipTierInitialization() {
        let tier = MembershipTier(
            name: "Gold",
            description: "Premium membership",
            price: 9.99,
            currency: "USD",
            benefits: ["Ad-free", "Early access"],
            badgeColor: "#FFD700"
        )
        
        XCTAssertEqual(tier.name, "Gold")
        XCTAssertEqual(tier.price, 9.99)
        XCTAssertEqual(tier.benefits.count, 2)
    }
    
    // MARK: - Equatable & Hashable Tests
    
    func testUserEquality() {
        let user1 = User(
            id: "same-id",
            username: "user1",
            displayName: "User 1",
            email: "user1@test.com"
        )
        
        let user2 = User(
            id: "same-id",
            username: "user2",
            displayName: "User 2",
            email: "user2@test.com"
        )
        
        let user3 = User(
            id: "different-id",
            username: "user1",
            displayName: "User 1",
            email: "user1@test.com"
        )
        
        XCTAssertEqual(user1, user2) // Same ID
        XCTAssertNotEqual(user1, user3) // Different ID
    }
    
    func testUserHashable() {
        let user1 = User(
            id: "test-id",
            username: "user",
            displayName: "User",
            email: "user@test.com"
        )
        
        let user2 = User(
            id: "test-id",
            username: "different",
            displayName: "Different",
            email: "different@test.com"
        )
        
        var set = Set<User>()
        set.insert(user1)
        set.insert(user2)
        
        XCTAssertEqual(set.count, 1) // Same ID = same hash
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleUsersExist() {
        XCTAssertFalse(User.sampleUsers.isEmpty)
        XCTAssertEqual(User.sampleUsers.count, 5)
    }
    
    func testDefaultUserExists() {
        let defaultUser = User.defaultUser
        XCTAssertEqual(defaultUser.username, "defaultuser")
    }
}
