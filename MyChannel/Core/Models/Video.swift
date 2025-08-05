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
            title: "Big Buck Bunny - Official Short Film",
            description: "Follow a day of the life of Big Buck Bunny when he meets three bullying rodents: Frank, Rinky, and Gamera. The rodents amuse themselves by harassing helpless creatures by throwing fruits, nuts and rocks at them.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            duration: 596, // 9:56
            viewCount: 2456780,
            likeCount: 78900,
            dislikeCount: 1245,
            commentCount: 8934,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Animation", "Short Film", "Comedy", "Classic"],
            category: .animation,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1245.50, tipRevenue: 389.00)
        ),
        Video(
            title: "Elephant's Dream - Blender Foundation",
            description: "The story of two strange characters exploring a capricious and seemingly infinite machine. The elder, Proog, acts as a tour-guide and protector, happily showing off the sights and dangers of the machine to his initially curious but increasingly skeptical protege Emo.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            duration: 654, // 10:54
            viewCount: 1567890,
            likeCount: 45600,
            dislikeCount: 567,
            commentCount: 3456,
            createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date(),
            creator: User.sampleUsers[1],
            tags: ["Animation", "3D", "Blender", "Art", "Experimental"],
            category: .art,
            isShort: false,
            monetization: VideoMonetization(hasAds: true, adRevenue: 987.20, tipRevenue: 234.00, membershipRevenue: 156.00)
        ),
        Video(
            title: "For Bigger Blazes - Fire Safety",
            description: "HBO GO now works with Chromecast -- the easiest way to enjoy online video on your TV. For when you want to settle into your Iron Throne to watch the latest episodes. For $35. Learn how to use Chromecast with HBO GO and more at google.com/chromecast.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            duration: 15, // 0:15
            viewCount: 892340,
            likeCount: 25600,
            dislikeCount: 890,
            commentCount: 1234,
            createdAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Technology", "Streaming", "Commercial", "Short"],
            category: .technology,
            isShort: true,
            monetization: VideoMonetization(hasAds: true, adRevenue: 456.80, tipRevenue: 123.00)
        ),
        Video(
            title: "For Bigger Escapes - Travel Adventures",
            description: "Introducing Chromecast. The easiest way to enjoy online video and music on your TV—for when Batman's escapes aren't quite big enough. For $35. Learn how to use Chromecast with Google Play Movies and more at google.com/chromecast.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            duration: 15, // 0:15
            viewCount: 567890,
            likeCount: 18500,
            dislikeCount: 234,
            commentCount: 789,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            creator: User.sampleUsers[2],
            tags: ["Travel", "Adventure", "Technology", "Commercial"],
            category: .travel,
            isShort: true,
            monetization: VideoMonetization(hasAds: true, adRevenue: 234.50, tipRevenue: 67.00)
        ),
        Video(
            title: "Sintel - Blender Open Movie",
            description: "A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend Scales.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/Sintel.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            duration: 888, // 14:48
            viewCount: 3456789,
            likeCount: 125000,
            dislikeCount: 2340,
            commentCount: 15678,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            creator: User.sampleUsers[1],
            tags: ["Animation", "Fantasy", "Dragon", "Adventure", "Blender"],
            category: .animation,
            monetization: VideoMonetization(hasAds: true, adRevenue: 2456.20, tipRevenue: 890.00, membershipRevenue: 456.00)
        ),
        Video(
            title: "Subaru Outback On Street And Dirt",
            description: "Smoking Tire takes the all-new Subaru Outback to the highest point we can find in hopes our customer-appreciation barbecue for one would somehow make us more appreciated.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/SubaruOutbackOnStreetAndDirt.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
            duration: 596, // 9:56
            viewCount: 1234567,
            likeCount: 45600,
            dislikeCount: 1200,
            commentCount: 3456,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            creator: User.sampleUsers[2],
            tags: ["Cars", "Review", "Subaru", "Adventure", "Automotive"],
            category: .entertainment,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1567.80, tipRevenue: 345.00)
        ),
        Video(
            title: "Tears of Steel - Sci-Fi Short",
            description: "Tears of Steel was realized with crowd-funding by users of the open source 3D creation tool Blender. Target was to improve and test a complete open and free pipeline for visual effects in film.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
            duration: 734, // 12:14
            viewCount: 2345678,
            likeCount: 89000,
            dislikeCount: 1567,
            commentCount: 7890,
            createdAt: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(),
            creator: User.sampleUsers[3],
            tags: ["Sci-Fi", "Short Film", "Blender", "Visual Effects", "Future"],
            category: .entertainment,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1890.50, tipRevenue: 567.00)
        ),
        Video(
            title: "Volkswagen GTI Review",
            description: "The Smoking Tire heads out to Adams Motorsports Park in Riverside, CA to test the most requested car of 2010, the Volkswagen GTI. Will it beat the Mazdaspeed3's standard-setting lap time?",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/VolkswagenGTIReview.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
            duration: 607, // 10:07
            viewCount: 789123,
            likeCount: 34500,
            dislikeCount: 678,
            commentCount: 2345,
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            creator: User.sampleUsers[0],
            tags: ["Cars", "Review", "Volkswagen", "GTI", "Performance"],
            category: .entertainment,
            monetization: VideoMonetization(hasAds: true, adRevenue: 1234.20, tipRevenue: 456.00)
        ),
        Video(
            title: "We Are Going On Bullrun",
            description: "The Smoking Tire is going on the 2010 Bullrun Live Rally in a 2011 Shelby GT500, and posting a video from the road every single day! The only place to watch them is by subscribing to The Smoking Tire or watching at BlackMagicShine.com",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/WeAreGoingOnBullrun.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
            duration: 78, // 1:18
            viewCount: 456789,
            likeCount: 23400,
            dislikeCount: 345,
            commentCount: 1234,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            creator: User.sampleUsers[2],
            tags: ["Cars", "Rally", "Adventure", "Shelby", "Road Trip"],
            category: .entertainment,
            isShort: true,
            monetization: VideoMonetization(hasAds: true, adRevenue: 345.80, tipRevenue: 123.00)
        ),
        Video(
            title: "What Car Can You Get For A Grand?",
            description: "The Smoking Tire meets up with Chris and Jorge from CarsForAGrand.com to see just how far $1,000 can go when looking for a car. The guys test a $1,000 car with the World Speed Record for a car under $1,000.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/WhatCarCanYouGetForAGrand.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4",
            duration: 596, // 9:56
            viewCount: 1567890,
            likeCount: 67800,
            dislikeCount: 890,
            commentCount: 4567,
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            creator: User.sampleUsers[3],
            tags: ["Cars", "Budget", "Review", "Challenge", "Automotive"],
            category: .entertainment,
            monetization: VideoMonetization(hasAds: true, adRevenue: 890.50, tipRevenue: 234.00)
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