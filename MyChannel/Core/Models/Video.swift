//
//  Video.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import SwiftUI

// MARK: - Video Model
struct Video: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var description: String
    var thumbnailURL: String
    var videoURL: String
    var duration: TimeInterval // in seconds
    var viewCount: Int
    var likeCount: Int
    var dislikeCount: Int
    var commentCount: Int
    var createdAt: Date
    var updatedAt: Date
    let creatorId: String
    var creator: User
    var category: VideoCategory
    var tags: [String]
    var isPublic: Bool
    var quality: [VideoQuality]
    var aspectRatio: AspectRatio
    var isLiveStream: Bool
    var scheduledAt: Date?
    
    // Enhanced properties for different content types
    var contentSource: ContentSource?
    var externalID: String? // For API content
    var contentRating: ContentRating?
    var language: String?
    var subtitles: [SubtitleTrack]?
    var isVerified: Bool
    var monetization: MonetizationSettings?
    
    // MARK: - Custom Coding Keys
    private enum CodingKeys: String, CodingKey {
        case id, title, description, thumbnailURL, videoURL, duration
        case viewCount, likeCount, dislikeCount, commentCount
        case createdAt, updatedAt, creatorId, creator, category
        case tags, isPublic, quality, aspectRatio, isLiveStream
        case scheduledAt, contentSource, externalID, contentRating
        case language, subtitles, isVerified, monetization
    }
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        thumbnailURL = try container.decode(String.self, forKey: .thumbnailURL)
        videoURL = try container.decode(String.self, forKey: .videoURL)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        dislikeCount = try container.decode(Int.self, forKey: .dislikeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        
        // Handle Date decoding safely
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        
        creatorId = try container.decode(String.self, forKey: .creatorId)
        creator = try container.decode(User.self, forKey: .creator)
        category = try container.decode(VideoCategory.self, forKey: .category)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        quality = try container.decodeIfPresent([VideoQuality].self, forKey: .quality) ?? [.quality720p]
        aspectRatio = try container.decodeIfPresent(AspectRatio.self, forKey: .aspectRatio) ?? .landscape
        isLiveStream = try container.decodeIfPresent(Bool.self, forKey: .isLiveStream) ?? false
        
        contentSource = try container.decodeIfPresent(ContentSource.self, forKey: .contentSource)
        externalID = try container.decodeIfPresent(String.self, forKey: .externalID)
        contentRating = try container.decodeIfPresent(ContentRating.self, forKey: .contentRating)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        subtitles = try container.decodeIfPresent([SubtitleTrack].self, forKey: .subtitles)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        monetization = try container.decodeIfPresent(MonetizationSettings.self, forKey: .monetization)
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(videoURL, forKey: .videoURL)
        try container.encode(duration, forKey: .duration)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(dislikeCount, forKey: .dislikeCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(creator, forKey: .creator)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(quality, forKey: .quality)
        try container.encode(aspectRatio, forKey: .aspectRatio)
        try container.encode(isLiveStream, forKey: .isLiveStream)
        try container.encodeIfPresent(contentSource, forKey: .contentSource)
        try container.encodeIfPresent(externalID, forKey: .externalID)
        try container.encodeIfPresent(contentRating, forKey: .contentRating)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(subtitles, forKey: .subtitles)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(monetization, forKey: .monetization)
    }
    
    // Computed property for shareable link
    var link: String {
        return "https://mychannel.app/video/\(id)"
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        thumbnailURL: String,
        videoURL: String,
        duration: TimeInterval,
        viewCount: Int,
        likeCount: Int,
        dislikeCount: Int = 0,
        commentCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        creator: User,
        category: VideoCategory,
        tags: [String] = [],
        isPublic: Bool = true,
        quality: [VideoQuality] = [.quality720p],
        aspectRatio: AspectRatio = .landscape,
        isLiveStream: Bool = false,
        scheduledAt: Date? = nil,
        contentSource: ContentSource? = nil,
        externalID: String? = nil,
        contentRating: ContentRating? = nil,
        language: String? = nil,
        subtitles: [SubtitleTrack]? = nil,
        isVerified: Bool = false,
        monetization: MonetizationSettings? = nil
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
        self.creatorId = creator.id
        self.creator = creator
        self.category = category
        self.tags = tags
        self.isPublic = isPublic
        self.quality = quality
        self.aspectRatio = aspectRatio
        self.isLiveStream = isLiveStream
        self.scheduledAt = scheduledAt
        self.contentSource = contentSource
        self.externalID = externalID
        self.contentRating = contentRating
        self.language = language
        self.subtitles = subtitles
        self.isVerified = isVerified
        self.monetization = monetization
    }
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount)"
        }
    }
    
    var formattedLikeCount: String {
        if likeCount >= 1_000_000 {
            return String(format: "%.1fM", Double(likeCount) / 1_000_000)
        } else if likeCount >= 1_000 {
            return String(format: "%.1fK", Double(likeCount) / 1_000)
        } else {
            return "\(likeCount)"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var isNew: Bool {
        Date().timeIntervalSince(createdAt) < 24 * 60 * 60 // Less than 24 hours
    }
    
    var isTrending: Bool {
        viewCount > 100_000 && Date().timeIntervalSince(createdAt) < 7 * 24 * 60 * 60 // High views in last week
    }
    
    var isShort: Bool {
        duration <= 60 // Videos 60 seconds or less are considered shorts
    }
    
    var isLive: Bool {
        isLiveStream && scheduledAt != nil && Date() >= (scheduledAt ?? Date())
    }
    
    var likeRatio: Double {
        let total = likeCount + dislikeCount
        return total > 0 ? Double(likeCount) / Double(total) : 0.0
    }
    
    // MARK: - AspectRatio Enum
    enum AspectRatio: String, Codable, CaseIterable {
        case landscape = "16:9"
        case portrait = "9:16"
        case square = "1:1"
        case ultrawide = "21:9"
        
        var ratio: CGFloat {
            switch self {
            case .landscape: return 16/9
            case .portrait: return 9/16
            case .square: return 1/1
            case .ultrawide: return 21/9
            }
        }
    }
    
    // MARK: - Content Source
    enum ContentSource: String, Codable, CaseIterable {
        case userUploaded = "user_uploaded"
        case tmdb = "tmdb"
        case omdb = "omdb"
        case jikan = "jikan" // MyAnimeList
        case anilist = "anilist"
        case archive = "archive_org"
        case youtube = "youtube"
        case vimeo = "vimeo"
        case twitch = "twitch"
        case dailymotion = "dailymotion"
        
        var displayName: String {
            switch self {
            case .userUploaded: return "User Upload"
            case .tmdb: return "The Movie Database"
            case .omdb: return "Open Movie Database"
            case .jikan: return "MyAnimeList"
            case .anilist: return "AniList"
            case .archive: return "Archive.org"
            case .youtube: return "YouTube"
            case .vimeo: return "Vimeo"
            case .twitch: return "Twitch"
            case .dailymotion: return "Dailymotion"
            }
        }
        
        var iconName: String {
            switch self {
            case .userUploaded: return "person.crop.circle"
            case .tmdb: return "tv"
            case .omdb: return "film"
            case .jikan, .anilist: return "sparkles.tv"
            case .archive: return "archivebox"
            case .youtube: return "play.rectangle"
            case .vimeo: return "v.circle"
            case .twitch: return "gamecontroller"
            case .dailymotion: return "play.circle"
            }
        }
    }
    
    // MARK: - Content Rating
    enum ContentRating: String, Codable, CaseIterable {
        case G = "G"           // General Audiences
        case PG = "PG"         // Parental Guidance
        case PG13 = "PG-13"    // Parents Strongly Cautioned
        case R = "R"           // Restricted
        case NC17 = "NC-17"    // Adults Only
        case TV_Y = "TV-Y"     // All Children
        case TV_Y7 = "TV-Y7"   // Children 7+
        case TV_G = "TV-G"     // General Audience
        case TV_PG = "TV-PG"   // Parental Guidance
        case TV_14 = "TV-14"   // Parents Strongly Cautioned
        case TV_MA = "TV-MA"   // Mature Audience
        
        var description: String {
            switch self {
            case .G: return "General Audiences"
            case .PG: return "Parental Guidance Suggested"
            case .PG13: return "Parents Strongly Cautioned"
            case .R: return "Restricted"
            case .NC17: return "Adults Only"
            case .TV_Y: return "All Children"
            case .TV_Y7: return "Directed to Children 7+"
            case .TV_G: return "General Audience"
            case .TV_PG: return "Parental Guidance Suggested"
            case .TV_14: return "Parents Strongly Cautioned"
            case .TV_MA: return "Mature Audience Only"
            }
        }
        
        var color: Color {
            switch self {
            case .G, .TV_Y, .TV_G: return .green
            case .PG, .TV_Y7, .TV_PG: return .blue
            case .PG13, .TV_14: return .orange
            case .R, .TV_MA: return .red
            case .NC17: return .purple
            }
        }
    }
    
    // MARK: - Subtitle Track
    struct SubtitleTrack: Codable, Identifiable {
        let id: String
        let language: String
        let languageCode: String
        let url: String
        let isDefault: Bool
        
        init(language: String, languageCode: String, url: String, isDefault: Bool) {
            self.id = UUID().uuidString
            self.language = language
            self.languageCode = languageCode
            self.url = url
            self.isDefault = isDefault
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, language, languageCode, url, isDefault
        }
    }
    
    // MARK: - Monetization Settings
    struct MonetizationSettings: Codable {
        let isMonetized: Bool
        let adBreaks: [AdBreak]
        let sponsorSegments: [SponsorSegment]
        let merchandise: [MerchandiseItem]?
        let donationEnabled: Bool
        let subscriptionTier: SubscriptionTier?
        let totalRevenue: Double // Add this property
        
        init(
            isMonetized: Bool = false,
            adBreaks: [AdBreak] = [],
            sponsorSegments: [SponsorSegment] = [],
            merchandise: [MerchandiseItem]? = nil,
            donationEnabled: Bool = false,
            subscriptionTier: SubscriptionTier? = nil,
            totalRevenue: Double = 0.0
        ) {
            self.isMonetized = isMonetized
            self.adBreaks = adBreaks
            self.sponsorSegments = sponsorSegments
            self.merchandise = merchandise
            self.donationEnabled = donationEnabled
            self.subscriptionTier = subscriptionTier
            self.totalRevenue = totalRevenue
        }
        
        struct AdBreak: Codable {
            let timeStamp: TimeInterval
            let duration: TimeInterval
            let type: AdType
            
            enum AdType: String, Codable {
                case preRoll = "pre_roll"
                case midRoll = "mid_roll"
                case postRoll = "post_roll"
                case overlay = "overlay"
            }
        }
        
        struct SponsorSegment: Codable {
            let startTime: TimeInterval
            let endTime: TimeInterval
            let sponsor: String
            let category: SponsorCategory
            
            enum SponsorCategory: String, Codable {
                case sponsor = "sponsor"
                case selfPromo = "self_promo"
                case interaction = "interaction"
                case intro = "intro"
                case outro = "outro"
                case preview = "preview"
            }
        }
        
        struct MerchandiseItem: Codable {
            let name: String
            let description: String
            let price: Double
            let currency: String
            let imageURL: String
            let purchaseURL: String
        }
        
        enum SubscriptionTier: String, Codable {
            case free = "free"
            case basic = "basic"
            case premium = "premium"
            case exclusive = "exclusive"
        }
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Video Category
enum VideoCategory: String, Codable, CaseIterable {
    case movies = "movies"
    case tvShows = "tv_shows"
    case anime = "anime"
    case mukbang = "mukbang"
    case documentaries = "documentaries"
    case shorts = "shorts"
    case gaming = "gaming"
    case music = "music"
    case cooking = "cooking"
    case lifestyle = "lifestyle"
    case education = "education"
    case technology = "technology"
    case sports = "sports"
    case news = "news"
    case comedy = "comedy"
    case beauty = "beauty"
    case travel = "travel"
    case fitness = "fitness"
    case diy = "diy"
    case pets = "pets"
    case art = "art"
    case entertainment = "entertainment"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        case .anime: return "Anime"
        case .mukbang: return "Mukbang"
        case .documentaries: return "Documentaries"
        case .shorts: return "Shorts"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .cooking: return "Cooking"
        case .lifestyle: return "Lifestyle"
        case .education: return "Education"
        case .technology: return "Technology"
        case .sports: return "Sports"
        case .news: return "News"
        case .comedy: return "Comedy"
        case .beauty: return "Beauty & Fashion"
        case .travel: return "Travel"
        case .fitness: return "Fitness & Health"
        case .diy: return "DIY & Crafts"
        case .pets: return "Pets & Animals"
        case .art: return "Art & Design"
        case .entertainment: return "Entertainment"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .movies: return "tv"
        case .tvShows: return "tv.and.hifispeaker.fill"
        case .anime: return "sparkles.tv"
        case .mukbang: return "fork.knife"
        case .documentaries: return "doc.on.doc"
        case .shorts: return "rectangle.portrait"
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .cooking: return "chef.hat"
        case .lifestyle: return "heart.fill"
        case .education: return "graduationcap"
        case .technology: return "laptopcomputer"
        case .sports: return "soccerball"
        case .news: return "newspaper"
        case .comedy: return "theatermasks"
        case .beauty: return "paintbrush"
        case .travel: return "airplane"
        case .fitness: return "figure.run"
        case .diy: return "hammer"
        case .pets: return "pawprint"
        case .art: return "paintbrush.pointed"
        case .entertainment: return "sparkles"
        case .other: return "ellipsis"
        }
    }
    
    var color: Color {
        switch self {
        case .movies, .tvShows: return .blue
        case .anime: return .purple
        case .mukbang, .cooking: return .orange
        case .documentaries, .education: return .green
        case .shorts: return .pink
        case .gaming: return .red
        case .music: return .indigo
        case .lifestyle, .beauty: return .mint
        case .technology: return .cyan
        case .sports, .fitness: return .red
        case .news: return .gray
        case .comedy: return .yellow
        case .travel: return .teal
        case .diy: return .brown
        case .pets: return .orange
        case .art: return .purple
        case .entertainment: return .purple
        case .other: return .secondary
        }
    }
}

// MARK: - Sample Data
extension Video {
    static var sampleVideos: [Video] {
        let creators = User.sampleUsers
        
        var videos = [
            // Movies
            Video(
                title: "Epic Adventure: The Lost Kingdom",
                description: "Join our heroes on an epic quest to find the lost kingdom and restore peace to the realm. Featuring stunning visuals and an engaging storyline.",
                thumbnailURL: "https://images.unsplash.com/photo-1489599511895-42ac8d2e6286?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 596, // 9:56 minutes
                viewCount: 1250000,
                likeCount: 98500,
                creator: creators[0],
                category: .movies,
                tags: ["adventure", "fantasy", "epic", "kingdom"],
                contentSource: .archive,
                contentRating: .PG13,
                language: "English"
            ),
            
            // Anime
            Video(
                title: "Sakura Academy Episode 12: Festival Night",
                description: "The annual cherry blossom festival arrives at Sakura Academy! Watch as our characters navigate friendship, romance, and magical adventures under the moonlight.",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 653, // 10:53 minutes
                viewCount: 856000,
                likeCount: 125000,
                creator: User(
                    username: "SakuraStudio",
                    displayName: "Sakura Animation Studio",
                    email: "contact@sakurastudio.com",
                    profileImageURL: "https://images.unsplash.com/photo-1544725176-7c40e5a71c5e?w=150"
                ),
                category: .anime,
                tags: ["anime", "school", "festival", "romance", "slice of life"],
                contentSource: .jikan,
                externalID: "sakura_academy_12",
                contentRating: .TV_PG,
                language: "Japanese",
                subtitles: [
                    SubtitleTrack(language: "English", languageCode: "en", url: "https://example.com/subtitles/en.vtt", isDefault: true),
                    SubtitleTrack(language: "Spanish", languageCode: "es", url: "https://example.com/subtitles/es.vtt", isDefault: false)
                ]
            ),
            
            // Mukbang
            Video(
                title: "ASMR Mukbang: Korean BBQ Feast 🥩",
                description: "Join me for a delicious Korean BBQ mukbang! Featuring marinated bulgogi, spicy kimchi, fresh lettuce wraps, and satisfying ASMR eating sounds.",
                thumbnailURL: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                duration: 15, // 15 seconds
                viewCount: 2340000,
                likeCount: 187000,
                creator: User(
                    username: "KoreanFoodieASMR",
                    displayName: "Korean Foodie ASMR 🍽️",
                    email: "hello@koreanfoodieasmr.com",
                    profileImageURL: "https://images.unsplash.com/photo-1494790108755-2616b612b742?w=150"
                ),
                category: .mukbang,
                tags: ["mukbang", "asmr", "korean food", "bbq", "eating sounds"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                language: "Korean",
                isVerified: true
            ),
            
            Video(
                title: "Spicy Fire Noodle Challenge Mukbang 🔥",
                description: "Taking on the extreme spicy fire noodle challenge! Watch me struggle through the heat with milk, ice cream, and lots of tissues ready. Can I finish it all?",
                thumbnailURL: "https://images.unsplash.com/photo-1555126634-323283e090fa?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                duration: 15, // 15 seconds
                viewCount: 3450000,
                likeCount: 456000,
                creator: User(
                    username: "SpicyEatsChallenge",
                    displayName: "Spicy Eats Challenge 🌶️",
                    email: "spicy@eatschallenge.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
                ),
                category: .mukbang,
                tags: ["mukbang", "spicy", "noodles", "challenge", "fire noodles"],
                contentSource: .userUploaded,
                contentRating: .TV_PG
            ),
            
            // More content categories...
            Video(
                title: "Homemade Ramen: From Scratch Tutorial",
                description: "Learn how to make authentic Japanese ramen from scratch! Including the perfect broth, handmade noodles, and traditional toppings.",
                thumbnailURL: "https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
                duration: 15, // 15 seconds
                viewCount: 567000,
                likeCount: 67800,
                creator: creators[2],
                category: .cooking,
                tags: ["cooking", "ramen", "japanese", "tutorial", "homemade"],
                contentSource: .userUploaded,
                contentRating: .TV_G
            ),
            
            Video(
                title: "Quick Morning Routine for Productivity",
                description: "Transform your mornings with this efficient 30-minute routine that will boost your productivity and energy for the entire day!",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                duration: 15, // 15 seconds
                viewCount: 890000,
                likeCount: 78900,
                creator: creators[3],
                category: .lifestyle,
                tags: ["lifestyle", "morning routine", "productivity", "wellness"],
                contentSource: .userUploaded,
                contentRating: .TV_G
            )
        ]
        
        // Add art videos to the main sample data
        videos.append(contentsOf: artVideos)
        
        return videos
    }
    
    // Additional art videos for sample data
    static var artVideos: [Video] {
        let creators = User.sampleUsers
        
        return [
            Video(
                title: "Digital Portrait Tutorial: Realistic Eye Drawing",
                description: "Learn how to draw realistic eyes in this step-by-step digital art tutorial. Perfect for beginners who want to improve their portrait skills.",
                thumbnailURL: "https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
                duration: 15, // 15 seconds
                viewCount: 425000,
                likeCount: 34500,
                creator: User(
                    username: "DigitalArtMaster",
                    displayName: "Digital Art Master 🎨",
                    email: "hello@digitalartmaster.com",
                    profileImageURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150"
                ),
                category: .art,
                tags: ["art", "digital", "tutorial", "portrait", "drawing"],
                contentSource: .userUploaded,
                contentRating: .TV_G
            ),
            
            Video(
                title: "Watercolor Landscape: Mountain Sunrise",
                description: "Paint a breathtaking mountain sunrise scene using watercolor techniques. Learn blending, color theory, and atmospheric perspective.",
                thumbnailURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
                duration: 888, // 14:48 minutes
                viewCount: 678000,
                likeCount: 52300,
                creator: User(
                    username: "WatercolorWonders",
                    displayName: "Watercolor Wonders 🌈",
                    email: "paint@watercolorwonders.com",
                    profileImageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150"
                ),
                category: .art,
                tags: ["art", "watercolor", "landscape", "painting", "tutorial"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            ),
            
            Video(
                title: "3D Character Design Speedrun",
                description: "Watch as I create a complete 3D character from concept to final render in just one hour! Using Blender 3D modeling techniques.",
                thumbnailURL: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
                duration: 734, // 12:14 minutes
                viewCount: 892000,
                likeCount: 78900,
                creator: User(
                    username: "Blender3DPro",
                    displayName: "Blender 3D Pro 🔥",
                    email: "create@blender3dpro.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
                ),
                category: .art,
                tags: ["art", "3d", "blender", "character design", "speedrun"],
                contentSource: .userUploaded,
                contentRating: .TV_G
            )
        ]
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 16) {
            Text("Video System")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            ForEach(Video.sampleVideos.prefix(3)) { video in
                VStack(alignment: .leading, spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: video.category.iconName)
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(video.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        
                        HStack {
                            AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    )
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            
                            Text(video.creator.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if video.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Text(video.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(video.category.color.opacity(0.1))
                                .foregroundColor(video.category.color)
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Text("\(video.formattedViewCount) views")
                            Text("•")
                            Text(video.timeAgo)
                            Text("•")
                            Text(video.formattedDuration)
                            
                            Spacer()
                            
                            HStack(spacing: 2) {
                                Image(systemName: "hand.thumbsup")
                                Text(video.formattedLikeCount)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}