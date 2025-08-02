//
//  Video.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - Video Model
struct Video: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let videoURL: String
    let duration: TimeInterval
    let viewCount: Int
    let likeCount: Int
    let dislikeCount: Int
    let commentCount: Int
    let createdAt: Date
    let updatedAt: Date
    let creator: User
    let tags: [String]
    let category: VideoCategory
    let isPublic: Bool
    let isLive: Bool
    let isShort: Bool
    let isPremium: Bool
    let monetization: VideoMonetization
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        thumbnailURL: String,
        videoURL: String,
        duration: TimeInterval,
        viewCount: Int = 0,
        likeCount: Int = 0,
        dislikeCount: Int = 0,
        commentCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        creator: User,
        tags: [String] = [],
        category: VideoCategory = .entertainment,
        isPublic: Bool = true,
        isLive: Bool = false,
        isShort: Bool = false,
        isPremium: Bool = false,
        monetization: VideoMonetization = VideoMonetization()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.duration = duration
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creator = creator
        self.tags = tags
        self.category = category
        self.isPublic = isPublic
        self.isLive = isLive
        self.isShort = isShort
        self.isPremium = isPremium
        self.monetization = monetization
    }
    
    // MARK: - Equatable
    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Video Category Enum
enum VideoCategory: String, CaseIterable, Codable {
    case entertainment = "entertainment"
    case education = "education"
    case gaming = "gaming"
    case music = "music"
    case news = "news"
    case sports = "sports"
    case technology = "technology"
    case lifestyle = "lifestyle"
    case cooking = "cooking"
    case travel = "travel"
    case fitness = "fitness"
    case beauty = "beauty"
    case fashion = "fashion"
    case diy = "diy"
    case business = "business"
    case science = "science"
    case comedy = "comedy"
    case art = "art"
    case animation = "animation"
    case documentary = "documentary"
    
    var displayName: String {
        switch self {
        case .entertainment: return "Entertainment"
        case .education: return "Education"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .news: return "News"
        case .sports: return "Sports"
        case .technology: return "Technology"
        case .lifestyle: return "Lifestyle"
        case .cooking: return "Cooking"
        case .travel: return "Travel"
        case .fitness: return "Fitness"
        case .beauty: return "Beauty"
        case .fashion: return "Fashion"
        case .diy: return "DIY & Crafts"
        case .business: return "Business"
        case .science: return "Science"
        case .comedy: return "Comedy"
        case .art: return "Art"
        case .animation: return "Animation"
        case .documentary: return "Documentary"
        }
    }
    
    var iconName: String {
        switch self {
        case .entertainment: return "tv"
        case .education: return "graduationcap"
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .news: return "newspaper"
        case .sports: return "sportscourt"
        case .technology: return "laptopcomputer"
        case .lifestyle: return "house"
        case .cooking: return "fork.knife"
        case .travel: return "airplane"
        case .fitness: return "figure.run"
        case .beauty: return "sparkles"
        case .fashion: return "tshirt"
        case .diy: return "hammer"
        case .business: return "briefcase"
        case .science: return "flask"
        case .comedy: return "theatermasks"
        case .art: return "paintbrush"
        case .animation: return "play.circle"
        case .documentary: return "doc.text"
        }
    }
}

// MARK: - Video Monetization Model
struct VideoMonetization: Codable, Equatable {
    let hasAds: Bool
    let adRevenue: Double
    let tipRevenue: Double
    let membershipRevenue: Double
    let totalRevenue: Double
    
    init(
        hasAds: Bool = false,
        adRevenue: Double = 0.0,
        tipRevenue: Double = 0.0,
        membershipRevenue: Double = 0.0
    ) {
        self.hasAds = hasAds
        self.adRevenue = adRevenue
        self.tipRevenue = tipRevenue
        self.membershipRevenue = membershipRevenue
        self.totalRevenue = adRevenue + tipRevenue + membershipRevenue
    }
    
    // MARK: - Equatable
    static func == (lhs: VideoMonetization, rhs: VideoMonetization) -> Bool {
        lhs.hasAds == rhs.hasAds &&
        lhs.adRevenue == rhs.adRevenue &&
        lhs.tipRevenue == rhs.tipRevenue &&
        lhs.membershipRevenue == rhs.membershipRevenue
    }
}

// MARK: - Video Extensions
extension Video {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedViews: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount)"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Sample Data
extension Video {
    static let sampleVideos: [Video] = [
        Video(
            title: "Building the Future of SwiftUI",
            description: "In this comprehensive tutorial, we'll explore the latest SwiftUI features and how to build modern, responsive apps that look great on all devices.",
            thumbnailURL: "https://picsum.photos/400/225?random=1",
            videoURL: "https://example.com/video1.mp4",
            duration: 1245, // 20:45
            viewCount: 45680,
            likeCount: 3200,
            dislikeCount: 45,
            commentCount: 328,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["SwiftUI", "iOS", "Development", "Tutorial"],
            category: .technology,
            monetization: VideoMonetization(hasAds: true, adRevenue: 245.50, tipRevenue: 89.00)
        ),
        Video(
            title: "10 Minute Digital Art Challenge",
            description: "Watch me create a stunning digital artwork in just 10 minutes using Procreate! Speed drawing with commentary and tips.",
            thumbnailURL: "https://picsum.photos/400/225?random=2",
            videoURL: "https://example.com/video2.mp4",
            duration: 630, // 10:30
            viewCount: 128340,
            likeCount: 8900,
            dislikeCount: 123,
            commentCount: 567,
            createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date(),
            creator: User.sampleUsers[1],
            tags: ["Art", "Digital", "Procreate", "Tutorial", "Speed Drawing"],
            category: .art,
            isShort: false,
            monetization: VideoMonetization(hasAds: true, adRevenue: 687.20, tipRevenue: 234.00, membershipRevenue: 156.00)
        ),
        Video(
            title: "Quick Cooking Hack",
            description: "This will change how you cook forever! ",
            thumbnailURL: "https://picsum.photos/400/225?random=3",
            videoURL: "https://example.com/video3.mp4",
            duration: 45, // 0:45
            viewCount: 892340,
            likeCount: 45600,
            dislikeCount: 890,
            commentCount: 2340,
            createdAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Cooking", "Food", "Hack", "Quick"],
            category: .cooking,
            isShort: true,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1245.80, tipRevenue: 567.00)
        ),
        Video(
            title: "iOS 18 Hidden Features Revealed",
            description: "Discover the secret features Apple didn't announce at WWDC! These hidden gems will change how you use your iPhone.",
            thumbnailURL: "https://picsum.photos/400/225?random=4",
            videoURL: "https://example.com/video4.mp4",
            duration: 890, // 14:50
            viewCount: 567890,
            likeCount: 34500,
            dislikeCount: 234,
            commentCount: 1456,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["iOS", "Apple", "Features", "Tutorial"],
            category: .technology,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1234.50, tipRevenue: 456.00)
        ),
        Video(
            title: "Midnight Art Session",
            description: "Join me for a late-night digital painting session. Relaxing music and creative flow.",
            thumbnailURL: "https://picsum.photos/400/225?random=5",
            videoURL: "https://example.com/video5.mp4",
            duration: 2340, // 39:00
            viewCount: 234567,
            likeCount: 15600,
            dislikeCount: 89,
            commentCount: 892,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            creator: User.sampleUsers[1],
            tags: ["Art", "Digital", "Relaxing", "Night"],
            category: .art,
            monetization: VideoMonetization(hasAds: true, adRevenue: 456.20, tipRevenue: 123.00, membershipRevenue: 234.00)
        ),
        Video(
            title: "Gaming Setup Tour 2024",
            description: "Check out my ultimate gaming setup! From RGB lighting to the latest hardware - everything you need to know.",
            thumbnailURL: "https://picsum.photos/400/225?random=6",
            videoURL: "https://example.com/video6.mp4",
            duration: 1456, // 24:16
            viewCount: 1234567,
            likeCount: 89000,
            dislikeCount: 1200,
            commentCount: 4567,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            creator: User.sampleUsers[2],
            tags: ["Gaming", "Setup", "Hardware", "RGB"],
            category: .gaming,
            monetization: VideoMonetization(hasAds: true, adRevenue: 2345.80, tipRevenue: 890.00)
        ),
        Video(
            title: "Beat Making Tutorial",
            description: "Learn how to make fire beats from scratch! Using Logic Pro X and some secret techniques.",
            thumbnailURL: "https://picsum.photos/400/225?random=7",
            videoURL: "https://example.com/video7.mp4",
            duration: 1890, // 31:30
            viewCount: 456789,
            likeCount: 23400,
            dislikeCount: 345,
            commentCount: 1890,
            createdAt: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(),
            creator: User.sampleUsers[3],
            tags: ["Music", "Beats", "Production", "Logic Pro"],
            category: .music,
            monetization: VideoMonetization(hasAds: true, adRevenue: 890.50, tipRevenue: 234.00)
        ),
        Video(
            title: "React vs SwiftUI: Which is Better?",
            description: "A comprehensive comparison between React and SwiftUI for mobile development in 2024.",
            thumbnailURL: "https://picsum.photos/400/225?random=8",
            videoURL: "https://example.com/video8.mp4",
            duration: 1678, // 27:58
            viewCount: 789123,
            likeCount: 45600,
            dislikeCount: 890,
            commentCount: 2345,
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Programming", "React", "SwiftUI", "Comparison"],
            category: .technology,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1567.20, tipRevenue: 678.00)
        ),
        Video(
            title: "Epic Gaming Montage",
            description: "My best gaming moments from this month! Incredible plays and funny fails.",
            thumbnailURL: "https://picsum.photos/400/225?random=9",
            videoURL: "https://example.com/video9.mp4",
            duration: 567, // 9:27
            viewCount: 2345678,
            likeCount: 123456,
            dislikeCount: 2345,
            commentCount: 8901,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            creator: User.sampleUsers[2],
            tags: ["Gaming", "Montage", "Highlights", "Epic"],
            category: .gaming,
            monetization: VideoMonetization(hasAds: true, adRevenue: 4567.80, tipRevenue: 1234.00)
        ),
        Video(
            title: "New Music Drop Tonight!",
            description: "Get ready for my latest track! Here's a sneak peek of what's coming at midnight.",
            thumbnailURL: "https://picsum.photos/400/225?random=10",
            videoURL: "https://example.com/video10.mp4",
            duration: 234, // 3:54
            viewCount: 567890,
            likeCount: 34567,
            dislikeCount: 456,
            commentCount: 3456,
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            creator: User.sampleUsers[3],
            tags: ["Music", "New Release", "Preview", "Tonight"],
            category: .music,
            monetization: VideoMonetization(hasAds: true, adRevenue: 890.50, tipRevenue: 456.00)
        ),
        Video(
            title: "Morning Workout Routine",
            description: "Start your day right with this energizing 20-minute workout! No equipment needed.",
            thumbnailURL: "https://picsum.photos/400/225?random=11",
            videoURL: "https://example.com/video11.mp4",
            duration: 1245, // 20:45
            viewCount: 345678,
            likeCount: 23456,
            dislikeCount: 234,
            commentCount: 1567,
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
            creator: User.sampleUsers[1],
            tags: ["Fitness", "Workout", "Morning", "Health"],
            category: .fitness,
            monetization: VideoMonetization(hasAds: true, adRevenue: 567.80, tipRevenue: 234.00)
        ),
        Video(
            title: "Ultimate Food Challenge",
            description: "Trying every item on the menu at my favorite restaurant! This was intense.",
            thumbnailURL: "https://picsum.photos/400/225?random=12",
            videoURL: "https://example.com/video12.mp4",
            duration: 2156, // 35:56
            viewCount: 1567890,
            likeCount: 89012,
            dislikeCount: 1345,
            commentCount: 5678,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Food", "Challenge", "Restaurant", "Epic"],
            category: .entertainment,
            monetization: VideoMonetization(hasAds: true, adRevenue: 2890.50, tipRevenue: 1234.00)
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("Video Models")
                .font(AppTheme.Typography.largeTitle)
                .padding()
            
            ForEach(Video.sampleVideos) { video in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .aspectRatio(16/9, contentMode: .fill)
                        }
                        .frame(width: 120, height: 68)
                        .cornerRadius(AppTheme.CornerRadius.sm)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(AppTheme.Typography.headline)
                                .lineLimit(2)
                            
                            Text(video.creator.displayName)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            HStack {
                                Text("\(video.formattedViews) views")
                                Text("•")
                                Text(video.timeAgo)
                            }
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Label(video.formattedDuration, systemImage: "clock")
                        Spacer()
                        Label("\(video.likeCount)", systemImage: "heart")
                        Label("\(video.commentCount)", systemImage: "bubble.right")
                        if video.isShort {
                            Label("Short", systemImage: "bolt")
                        }
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }
    .background(AppTheme.Colors.background)
}