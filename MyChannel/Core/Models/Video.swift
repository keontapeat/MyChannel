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
    
    var uploadTimeAgo: String {
        return timeAgo // Same as timeAgo for consistency
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
    
    var isKidFriendly: Bool {
        return category == .kids || contentRating == .G || contentRating == .TV_Y || contentRating == .TV_Y7 || contentRating == .TV_G
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
        case crunchyroll = "crunchyroll"
        case funimation = "funimation"
        case adultswim = "adult_swim"
        case pbsKids = "pbs_kids"
        case disney = "disney"
        case nickJr = "nick_jr"
        case cartoonNetwork = "cartoon_network"
        
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
            case .crunchyroll: return "Crunchyroll"
            case .funimation: return "Funimation"
            case .adultswim: return "Adult Swim"
            case .pbsKids: return "PBS Kids"
            case .disney: return "Disney"
            case .nickJr: return "Nick Jr."
            case .cartoonNetwork: return "Cartoon Network"
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
            case .crunchyroll: return "sparkles.tv"
            case .funimation: return "tv.and.hifispeaker.fill"
            case .adultswim: return "moon.stars.fill"
            case .pbsKids: return "graduationcap.fill"
            case .disney: return "star.fill"
            case .nickJr: return "heart.fill"
            case .cartoonNetwork: return "face.smiling.fill"
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
        case TV_PG = "TV-PG"   // Parental Guidance Suggested
        case TV_14 = "TV-14"   // Parents Strongly Cautioned
        case TV_MA = "TV-MA"   // Mature Audience Only
        
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
        let totalRevenue: Double
        
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
enum VideoCategory: String, Codable, CaseIterable, CustomStringConvertible {
    case movies = "movies"
    case tvShows = "tv_shows"
    case anime = "anime"
    case kids = "kids" // 🎯 NEW KIDS SECTION!
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
    case cartoons = "cartoons"
    case adultAnimation = "adult_animation" // For Robot Chicken type content
    case other = "other"
    
    var description: String {
        return displayName
    }
    
    var displayName: String {
        switch self {
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        case .anime: return "Anime"
        case .kids: return "Kids & Family" // 🎯 SAFE FOR THE WHOLE FAMILY
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
        case .cartoons: return "Cartoons"
        case .adultAnimation: return "Adult Animation"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .movies: return "tv"
        case .tvShows: return "tv.and.hifispeaker.fill"
        case .anime: return "sparkles.tv"
        case .kids: return "face.smiling.inverse" // 🎯 KID-FRIENDLY ICON
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
        case .cartoons: return "scribble.variable"
        case .adultAnimation: return "moon.stars.fill"
        case .other: return "ellipsis"
        }
    }
    
    var color: Color {
        switch self {
        case .movies, .tvShows: return .blue
        case .anime: return .purple
        case .kids: return .mint // 🎯 SOFT, KID-FRIENDLY COLOR
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
        case .cartoons: return .yellow
        case .adultAnimation: return .black
        case .other: return .secondary
        }
    }
}

// MARK: - Sample Data Extension with REAL WORKING CONTENT 🔥
extension Video {
    static var sampleVideos: [Video] {
        var allVideos: [Video] = []
        
        // Add all categories with REAL working videos
        allVideos.append(contentsOf: animeInspiredVideos) // Legal anime-inspired content
        allVideos.append(contentsOf: kidsVideos) // Safe kids content
        allVideos.append(contentsOf: mukbangVideos) // Food content
        allVideos.append(contentsOf: trendingVideos) // Viral content
        allVideos.append(contentsOf: gamingVideos) // Gaming content
        allVideos.append(contentsOf: musicVideos) // Music content
        allVideos.append(contentsOf: comedyVideos) // Comedy content
        allVideos.append(contentsOf: educationalVideos) // Educational content
        allVideos.append(contentsOf: lifestyleVideos) // Lifestyle content
        allVideos.append(contentsOf: shortsVideos) // Viral shorts
        
        return allVideos
    }
    
    // 🔥 ANIME-INSPIRED CONTENT (Legal & Working!)
    static var animeInspiredVideos: [Video] {
        let animeStudioCreator = User(
            username: "EpicAnimeStudio",
            displayName: "Epic Anime Studio 🎌",
            email: "official@epicanimestudio.com",
            profileImageURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "EPIC Warrior Battle: Power Unleashed! ⚡🔥",
                description: "Watch this incredible anime-style battle animation! Two warriors clash with earth-shaking power in this action-packed episode. Amazing fight choreography and stunning visuals!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 596,
                viewCount: 15600000,
                likeCount: 2340000,
                commentCount: 456000,
                creator: animeStudioCreator,
                category: .anime,
                tags: ["anime", "battle", "warrior", "action", "epic", "animation"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                language: "English",
                isVerified: true
            ),
            
            Video(
                title: "Mystical Academy: Magic School Adventures! ✨🏫",
                description: "Join students at the most magical academy in the world! Watch as they learn powerful spells and face incredible challenges. Perfect anime-style storytelling!",
                thumbnailURL: "https://images.unsplash.com/photo-1544725176-7c40e5a71c5e?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 653,
                viewCount: 12800000,
                likeCount: 1890000,
                commentCount: 234000,
                creator: animeStudioCreator,
                category: .anime,
                tags: ["anime", "magic", "school", "academy", "fantasy", "adventure"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            ),
            
            Video(
                title: "Ninja Chronicles: Shadow Warrior Training! 🥷",
                description: "Follow young ninjas as they master ancient techniques and face ultimate challenges! Action-packed ninja adventure with incredible fight scenes!",
                thumbnailURL: "https://images.unsplash.com/photo-1544725176-7c40e5a71c5e?w=500&h=281&fit=crop&crop=center",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
                duration: 1380,
                viewCount: 18900000,
                likeCount: 2890000,
                commentCount: 567000,
                creator: animeStudioCreator,
                category: .anime,
                tags: ["ninja", "training", "warrior", "action", "adventure", "martial arts"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🎯 KIDS CONTENT - REAL & SAFE!
    static var kidsVideos: [Video] {
        let kidsCreator = User(
            username: "SafeKidsLearning",
            displayName: "Safe Kids Learning 🌈",
            email: "safe@kidschannel.com",
            profileImageURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "Learn Colors with Fun Animals! 🌈🦁",
                description: "Educational and fun! Kids will learn all the colors of the rainbow with cute animals. Perfect for toddlers and preschoolers. Safe, verified content!",
                thumbnailURL: "https://images.unsplash.com/photo-1551963831-b3b1ca40c98e?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                duration: 180,
                viewCount: 2300000,
                likeCount: 345000,
                commentCount: 12000,
                creator: kidsCreator,
                category: .kids,
                tags: ["kids", "colors", "learning", "animals", "educational", "toddlers"],
                contentSource: .userUploaded,
                contentRating: .TV_Y,
                language: "English",
                isVerified: true
            ),
            
            Video(
                title: "Numbers 1-10 Fun Learning Song! 🔢🎵",
                description: "Count along with our fun number song! Kids will learn numbers 1 through 10 with catchy music and colorful animations. Educational entertainment!",
                thumbnailURL: "https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
                duration: 240,
                viewCount: 1800000,
                likeCount: 290000,
                commentCount: 8500,
                creator: kidsCreator,
                category: .kids,
                tags: ["numbers", "counting", "kids", "educational", "song", "learning"],
                contentSource: .userUploaded,
                contentRating: .TV_Y,
                isVerified: true
            )
        ]
    }
    
    // 🍽️ MUKBANG & FOOD CONTENT
    static var mukbangVideos: [Video] {
        let foodCreator = User(
            username: "FoodieASMR",
            displayName: "Foodie ASMR 🍽️",
            email: "eat@foodieasmr.com",
            profileImageURL: "https://images.unsplash.com/photo-1494790108755-2616b612b742?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "ASMR Food Challenge: Satisfying Eating Sounds! 🔥",
                description: "The most satisfying food eating video! Watch and listen to amazing ASMR eating sounds that will relax and satisfy you. Pure eating bliss!",
                thumbnailURL: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                duration: 1800,
                viewCount: 8900000,
                likeCount: 1200000,
                commentCount: 234000,
                creator: foodCreator,
                category: .mukbang,
                tags: ["mukbang", "asmr", "eating", "food", "satisfying", "relaxing"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 🔥 TRENDING CONTENT
    static var trendingVideos: [Video] {
        let trendingCreator = User(
            username: "ViralChallenges",
            displayName: "Viral Challenges 🔥",
            email: "viral@challenges.com",
            profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "24 Hour Challenge: Living in a Tiny House! 🏠",
                description: "I spent 24 hours in the world's tiniest house! Watch me try to cook, sleep, and live in this incredible space. You won't believe what happens!",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
                duration: 1800,
                viewCount: 12400000,
                likeCount: 1890000,
                commentCount: 345000,
                creator: trendingCreator,
                category: .lifestyle,
                tags: ["24 hour challenge", "tiny house", "lifestyle", "adventure", "viral"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🎮 GAMING CONTENT
    static var gamingVideos: [Video] {
        let gamingCreator = User(
            username: "ProGamerElite",
            displayName: "Pro Gamer Elite 🎮",
            email: "pro@gaming.com",
            profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "EPIC Gaming Moments Compilation! 🏆",
                description: "The most epic gaming moments ever! Watch these incredible plays that will leave you speechless. Pro-level gameplay and amazing skills!",
                thumbnailURL: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
                duration: 900,
                viewCount: 6700000,
                likeCount: 890000,
                commentCount: 156000,
                creator: gamingCreator,
                category: .gaming,
                tags: ["gaming", "epic moments", "compilation", "pro player", "skills"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🎵 MUSIC CONTENT
    static var musicVideos: [Video] {
        let musicCreator = User(
            username: "ChillVibesMusic",
            displayName: "Chill Vibes Music 🎧",
            email: "music@chillvibes.com",
            profileImageURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "Chill Beats for Study & Relax 🌊🎵",
                description: "The perfect background music for studying, working, or just chilling out. Smooth beats that will help you focus and feel good!",
                thumbnailURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
                duration: 3600,
                viewCount: 5200000,
                likeCount: 720000,
                commentCount: 89000,
                creator: musicCreator,
                category: .music,
                tags: ["chill", "study music", "beats", "relax", "background music"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 😂 COMEDY CONTENT  
    static var comedyVideos: [Video] {
        let comedyCreator = User(
            username: "FunnySkits",
            displayName: "Funny Skits Comedy 😂",
            email: "laughs@funnyskits.com",
            profileImageURL: "https://images.unsplash.com/photo-1517315003714-a071486bd9ea?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "Hilarious Life Situations Everyone Can Relate To! 😂",
                description: "These funny situations happen to everyone! Watch these hilarious skits that perfectly capture everyday life. You'll be laughing non-stop!",
                thumbnailURL: "https://images.unsplash.com/photo-1517315003714-a071486bd9ea?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
                duration: 480,
                viewCount: 4100000,
                likeCount: 580000,
                commentCount: 78000,
                creator: comedyCreator,
                category: .comedy,
                tags: ["comedy", "funny", "relatable", "skits", "humor"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 📚 EDUCATIONAL CONTENT
    static var educationalVideos: [Video] {
        let eduCreator = User(
            username: "LearnWithUs",
            displayName: "Learn With Us 📚",
            email: "learn@educational.com",
            profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "How Technology Actually Works - Mind Blowing! 🤯",
                description: "Ever wondered how your phone really works? This amazing explanation will blow your mind! Learn about technology in a fun and easy way!",
                thumbnailURL: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4",
                duration: 960,
                viewCount: 2800000,
                likeCount: 390000,
                commentCount: 45000,
                creator: eduCreator,
                category: .education,
                tags: ["technology", "education", "learning", "science", "how it works"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 💅 LIFESTYLE CONTENT
    static var lifestyleVideos: [Video] {
        let lifestyleCreator = User(
            username: "LifestyleGuru",
            displayName: "Lifestyle Guru ✨",
            email: "lifestyle@guru.com",
            profileImageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "Transform Your Life: Morning Routine That Works! ☀️",
                description: "This morning routine will completely change your life! Simple steps to boost your energy, productivity, and happiness. Start transforming today!",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500&h=281&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 720,
                viewCount: 1900000,
                likeCount: 280000,
                commentCount: 34000,
                creator: lifestyleCreator,
                category: .lifestyle,
                tags: ["morning routine", "lifestyle", "productivity", "wellness", "self improvement"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 🩳 VIRAL SHORTS
    static var shortsVideos: [Video] {
        let shortsCreator = User(
            username: "ViralShorts",
            displayName: "Viral Shorts 🔥",
            email: "shorts@viral.com",
            profileImageURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face",
            isVerified: true
        )
        
        return [
            Video(
                title: "This Will Make You Smile! 😊❤️",
                description: "Pure wholesome content that will instantly make your day better! Watch this heartwarming moment that's going viral! #shorts",
                thumbnailURL: "https://images.unsplash.com/photo-1552053831-71594a27632d?w=500&h=889&fit=crop",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 30,
                viewCount: 15600000,
                likeCount: 2340000,
                commentCount: 456000,
                creator: shortsCreator,
                category: .shorts,
                tags: ["wholesome", "viral", "shorts", "heartwarming", "smile"],
                aspectRatio: .portrait,
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 16) {
            Text("MyChannel Video Library 🔥")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            ForEach(Video.sampleVideos.prefix(5)) { video in
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