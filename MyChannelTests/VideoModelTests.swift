//
//  VideoModelTests.swift
//  MyChannelTests
//
//  Unit tests for Video model
//

import XCTest
@testable import MyChannel

final class VideoModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testVideoInitialization() {
        let creator = User(
            username: "testcreator",
            displayName: "Test Creator",
            email: "creator@test.com"
        )
        
        let video = Video(
            title: "Test Video",
            description: "Test description",
            thumbnailURL: "https://example.com/thumb.jpg",
            videoURL: "https://example.com/video.mp4",
            duration: 120,
            viewCount: 1000,
            likeCount: 50,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.title, "Test Video")
        XCTAssertEqual(video.description, "Test description")
        XCTAssertEqual(video.duration, 120)
        XCTAssertEqual(video.viewCount, 1000)
        XCTAssertEqual(video.likeCount, 50)
        XCTAssertEqual(video.category, .technology)
    }
    
    // MARK: - Formatted Duration Tests
    
    func testFormattedDurationMinutesOnly() {
        let creator = User.sampleUsers[0]
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 125, // 2:05
            viewCount: 0,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.formattedDuration, "2:05")
    }
    
    func testFormattedDurationWithHours() {
        let creator = User.sampleUsers[0]
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 3725, // 1:02:05
            viewCount: 0,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.formattedDuration, "1:02:05")
    }
    
    // MARK: - Formatted View Count Tests
    
    func testFormattedViewCountThousands() {
        let creator = User.sampleUsers[0]
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 5400,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.formattedViewCount, "5.4K")
    }
    
    func testFormattedViewCountMillions() {
        let creator = User.sampleUsers[0]
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 2_500_000,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.formattedViewCount, "2.5M")
    }
    
    func testFormattedViewCountSmall() {
        let creator = User.sampleUsers[0]
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 500,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.formattedViewCount, "500")
    }
    
    // MARK: - Computed Property Tests
    
    func testIsShort() {
        let creator = User.sampleUsers[0]
        
        let shortVideo = Video(
            title: "Short",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 45,
            viewCount: 0,
            likeCount: 0,
            creator: creator,
            category: .shorts
        )
        
        let longVideo = Video(
            title: "Long",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 120,
            viewCount: 0,
            likeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertTrue(shortVideo.isShort)
        XCTAssertFalse(longVideo.isShort)
    }
    
    func testIsNew() {
        let creator = User.sampleUsers[0]
        
        let newVideo = Video(
            title: "New Video",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 0,
            likeCount: 0,
            createdAt: Date(),
            creator: creator,
            category: .technology
        )
        
        let oldVideo = Video(
            title: "Old Video",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 0,
            likeCount: 0,
            createdAt: Date().addingTimeInterval(-48 * 60 * 60), // 48 hours ago
            creator: creator,
            category: .technology
        )
        
        XCTAssertTrue(newVideo.isNew)
        XCTAssertFalse(oldVideo.isNew)
    }
    
    func testLikeRatio() {
        let creator = User.sampleUsers[0]
        
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 0,
            likeCount: 80,
            dislikeCount: 20,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.likeRatio, 0.8, accuracy: 0.01)
    }
    
    func testLikeRatioZeroDivision() {
        let creator = User.sampleUsers[0]
        
        let video = Video(
            title: "Test",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 0,
            likeCount: 0,
            dislikeCount: 0,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video.likeRatio, 0.0)
    }
    
    // MARK: - Visibility Tests
    
    func testVisibilityStatus() {
        XCTAssertEqual(Video.VisibilityStatus.public.displayName, "Public")
        XCTAssertEqual(Video.VisibilityStatus.unlisted.displayName, "Unlisted")
        XCTAssertEqual(Video.VisibilityStatus.private.displayName, "Private")
        
        XCTAssertEqual(Video.VisibilityStatus.public.iconName, "globe")
        XCTAssertEqual(Video.VisibilityStatus.unlisted.iconName, "link")
        XCTAssertEqual(Video.VisibilityStatus.private.iconName, "lock.fill")
    }
    
    // MARK: - Category Tests
    
    func testVideoCategoryProperties() {
        let category = VideoCategory.gaming
        
        XCTAssertEqual(category.displayName, "Gaming")
        XCTAssertEqual(category.iconName, "gamecontroller")
        XCTAssertNotNil(category.color)
    }
    
    func testAllCategoriesHaveDisplayNames() {
        for category in VideoCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "Category \(category) should have a display name")
            XCTAssertFalse(category.iconName.isEmpty, "Category \(category) should have an icon")
        }
    }
    
    // MARK: - Hashable & Equatable Tests
    
    func testVideoEquality() {
        let creator = User.sampleUsers[0]
        
        let video1 = Video(
            id: "same-id",
            title: "Video 1",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 100,
            likeCount: 10,
            creator: creator,
            category: .technology
        )
        
        let video2 = Video(
            id: "same-id",
            title: "Different Title",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 120,
            viewCount: 200,
            likeCount: 20,
            creator: creator,
            category: .gaming
        )
        
        let video3 = Video(
            id: "different-id",
            title: "Video 1",
            description: "",
            thumbnailURL: "",
            videoURL: "",
            duration: 60,
            viewCount: 100,
            likeCount: 10,
            creator: creator,
            category: .technology
        )
        
        XCTAssertEqual(video1, video2) // Same ID = equal
        XCTAssertNotEqual(video1, video3) // Different ID = not equal
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleVideosExist() {
        let samples = Video.sampleVideos
        // Should have sample videos when mock data is enabled
        XCTAssertNotNil(samples)
    }
}
