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
enum VideoCategory: String, Codable, CaseIterable {
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

// MARK: - Sample Data Extension with FIRE CONTENT 🔥
extension Video {
    static var sampleVideos: [Video] {
        var allVideos: [Video] = []
        
        // Add all categories
        allVideos.append(contentsOf: dragonBallZVideos)
        allVideos.append(contentsOf: inuyashaVideos)
        allVideos.append(contentsOf: narutoVideos)
        allVideos.append(contentsOf: robotChickenVideos)
        allVideos.append(contentsOf: kidsVideos) // 🎯 NEW KIDS CONTENT!
        allVideos.append(contentsOf: mukbangVideos)
        allVideos.append(contentsOf: trendingVideos)
        allVideos.append(contentsOf: movieVideos)
        allVideos.append(contentsOf: gamingVideos)
        allVideos.append(contentsOf: musicVideos)
        allVideos.append(contentsOf: comedyVideos)
        allVideos.append(contentsOf: educationalVideos)
        allVideos.append(contentsOf: lifestyleVideos)
        allVideos.append(contentsOf: shortsVideos)
        
        return allVideos
    }
    
    // 🔥 DRAGON BALL Z - THE GOAT ANIME
    static var dragonBallZVideos: [Video] {
        let gokuCreator = User(
            username: "ToeiAnimation",
            displayName: "Toei Animation Official 🐉",
            email: "official@toei-animation.com",
            profileImageURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=150",
            isVerified: true
        )
        
        return [
            Video(
                title: "Dragon Ball Z: Goku vs Vegeta - EPIC FINAL BATTLE! 🐉⚡",
                description: "The most legendary battle in anime history! Watch Goku and Vegeta clash in an earth-shattering fight that will leave you on the edge of your seat. Pure Saiyan power unleashed!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 1440, // 24 minutes
                viewCount: 15600000, // 15.6M views 🔥
                likeCount: 2340000,
                commentCount: 456000,
                creator: gokuCreator,
                category: .anime,
                tags: ["dragon ball z", "goku", "vegeta", "saiyan", "battle", "anime", "epic"],
                contentSource: .crunchyroll,
                contentRating: .TV_PG,
                language: "Japanese",
                subtitles: [
                    SubtitleTrack(language: "English", languageCode: "en", url: "https://example.com/dbz1_en.vtt", isDefault: true),
                    SubtitleTrack(language: "Spanish", languageCode: "es", url: "https://example.com/dbz1_es.vtt", isDefault: false)
                ],
                isVerified: true
            ),
            
            Video(
                title: "Gohan Goes SUPER SAIYAN 2 vs Cell - Most Emotional Moment! 😭🔥",
                description: "The moment that made everyone cry! Watch teenage Gohan unlock his true power and transform into Super Saiyan 2 to save the world. Cell saga at its peak!",
                thumbnailURL: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 1320, // 22 minutes
                viewCount: 12800000,
                likeCount: 1890000,
                commentCount: 234000,
                creator: gokuCreator,
                category: .anime,
                tags: ["dragon ball z", "gohan", "super saiyan 2", "cell", "transformation", "emotional"],
                contentSource: .funimation,
                contentRating: .TV_PG,
                language: "English",
                isVerified: true
            ),
            
            Video(
                title: "Frieza's Final Form DESTROYS Planet Namek! 💥",
                description: "The tyrant of the universe reveals his true power! Watch Frieza's terrifying final transformation as Planet Namek crumbles. Classic DBZ at its finest!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                duration: 1380, // 23 minutes
                viewCount: 9500000,
                likeCount: 1200000,
                commentCount: 167000,
                creator: gokuCreator,
                category: .anime,
                tags: ["dragon ball z", "frieza", "namek", "destruction", "villain", "transformation"],
                contentSource: .crunchyroll,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // ⚔️ INUYASHA - FEUDAL FAIRY TALE VIBES
    static var inuyashaVideos: [Video] {
        let inuyashaCreator = User(
            username: "SunriseAnimation",
            displayName: "Sunrise Animation Studio ⚔️",
            email: "official@sunrise-inc.co.jp",
            profileImageURL: "https://images.unsplash.com/photo-1544725176-7c40e5a71c5e?w=150",
            isVerified: true
        )
        
        return [
            Video(
                title: "Inuyasha & Kagome's First Meeting - Love Story Begins! 💕⚔️",
                description: "The moment that started it all! Watch Kagome fall through the well and meet the half-demon Inuyasha. A timeless love story across centuries begins!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                duration: 1440, // 24 minutes
                viewCount: 8900000,
                likeCount: 1340000,
                commentCount: 234000,
                creator: inuyashaCreator,
                category: .anime,
                tags: ["inuyasha", "kagome", "romance", "feudal japan", "demons", "time travel"],
                contentSource: .crunchyroll,
                contentRating: .TV_PG,
                language: "Japanese",
                subtitles: [
                    SubtitleTrack(language: "English", languageCode: "en", url: "https://example.com/inu1_en.vtt", isDefault: true)
                ],
                isVerified: true
            ),
            
            Video(
                title: "Sesshomaru's Transformation - FULL DEMON POWER! 🌙",
                description: "The most elegant and powerful demon in the series! Watch Sesshomaru unleash his true demonic form. Pure badass energy and stunning animation!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
                duration: 1320, // 22 minutes
                viewCount: 6700000,
                likeCount: 980000,
                commentCount: 156000,
                creator: inuyashaCreator,
                category: .anime,
                tags: ["inuyasha", "sesshomaru", "demon", "transformation", "power", "badass"],
                contentSource: .funimation,
                contentRating: .TV_PG,
                isVerified: true
            ),
            
            Video(
                title: "The Final Act: Naraku's ULTIMATE DEFEAT! ⚡💀",
                description: "The climactic battle everyone waited for! Watch Inuyasha and friends finally defeat the evil Naraku in this epic conclusion. Tears and triumph guaranteed!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                duration: 1500, // 25 minutes
                viewCount: 11200000,
                likeCount: 1670000,
                commentCount: 289000,
                creator: inuyashaCreator,
                category: .anime,
                tags: ["inuyasha", "naraku", "final battle", "victory", "conclusion", "epic"],
                contentSource: .crunchyroll,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🍃 NARUTO - BELIEVE IT!
    static var narutoVideos: [Video] {
        let narutoCreator = User(
            username: "StudioPierrot",
            displayName: "Studio Pierrot Official 🍃",
            email: "official@pierrot.jp",
            profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
            isVerified: true
        )
        
        return [
            Video(
                title: "Naruto vs Sasuke - Valley of the End FINAL BATTLE! 🍃⚡",
                description: "The battle that broke our hearts! Watch Naruto and Sasuke's ultimate clash at the Valley of the End. Brotherhood, rivalry, and ninja way collide!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
                duration: 1680, // 28 minutes
                viewCount: 18900000, // MASSIVE VIEWS 🔥
                likeCount: 2890000,
                commentCount: 567000,
                creator: narutoCreator,
                category: .anime,
                tags: ["naruto", "sasuke", "valley of the end", "final battle", "ninja", "friendship"],
                contentSource: .crunchyroll,
                contentRating: .TV_PG,
                language: "Japanese",
                subtitles: [
                    SubtitleTrack(language: "English", languageCode: "en", url: "https://example.com/naruto1_en.vtt", isDefault: true)
                ],
                isVerified: true
            ),
            
            Video(
                title: "Rock Lee Drops His Weights - SPEED OF LIGHT! 💚⚡",
                description: "The moment that gave everyone goosebumps! Watch Rock Lee remove his training weights and show what hard work can achieve. Pure inspiration!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
                duration: 960, // 16 minutes
                viewCount: 14500000,
                likeCount: 2100000,
                commentCount: 345000,
                creator: narutoCreator,
                category: .anime,
                tags: ["naruto", "rock lee", "weights", "speed", "hard work", "inspiration"],
                contentSource: .funimation,
                contentRating: .TV_PG,
                isVerified: true
            ),
            
            Video(
                title: "Pain Destroys Hidden Leaf Village - ALMIGHTY PUSH! 💥",
                description: "The most devastating attack in Naruto! Watch Pain obliterate the entire Hidden Leaf Village with one move. Absolute power displayed!",
                thumbnailURL: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
                duration: 1200, // 20 minutes
                viewCount: 16700000,
                likeCount: 2450000,
                commentCount: 423000,
                creator: narutoCreator,
                category: .anime,
                tags: ["naruto", "pain", "destruction", "almighty push", "village", "power"],
                contentSource: .crunchyroll,
                contentRating: .TV_14,
                isVerified: true
            )
        ]
    }
    
    // 🤖 ROBOT CHICKEN - ADULT SWIM CHAOS
    static var robotChickenVideos: [Video] {
        let robotCreator = User(
            username: "AdultSwimOfficial",
            displayName: "Adult Swim [AS] 🤖",
            email: "chaos@adultswim.com",
            profileImageURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
            isVerified: true
        )
        
        return [
            Video(
                title: "Robot Chicken: Star Wars Parody - Darth Vader's Day Off! 🤖⭐",
                description: "Watch Darth Vader like you've never seen him before! Robot Chicken's hilarious take on Star Wars will have you rolling on the floor laughing!",
                thumbnailURL: "https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
                duration: 660, // 11 minutes
                viewCount: 5600000,
                likeCount: 780000,
                commentCount: 123000,
                creator: robotCreator,
                category: .adultAnimation,
                tags: ["robot chicken", "star wars", "parody", "comedy", "adult swim", "stop motion"],
                contentSource: .adultswim,
                contentRating: .TV_MA,
                language: "English",
                isVerified: true
            ),
            
            Video(
                title: "Robot Chicken: Childhood Toys GONE WRONG! 🧸💀",
                description: "Your favorite childhood toys get the Robot Chicken treatment! Dark, twisted, and absolutely hilarious. Not for the faint of heart!",
                thumbnailURL: "https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
                duration: 720, // 12 minutes
                viewCount: 4200000,
                likeCount: 590000,
                commentCount: 89000,
                creator: robotCreator,
                category: .adultAnimation,
                tags: ["robot chicken", "toys", "childhood", "dark comedy", "twisted", "adult swim"],
                contentSource: .adultswim,
                contentRating: .TV_MA,
                isVerified: true
            )
        ]
    }
    
    // 🎯 KIDS CONTENT - SAFE AND EDUCATIONAL! 
    static var kidsVideos: [Video] {
        let kidsCreator = User(
            username: "SafeKidsChannel",
            displayName: "Safe Kids Learning 🌈",
            email: "safe@kidschannel.com",
            profileImageURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150",
            isVerified: true
        )
        
        let pbsCreator = User(
            username: "PBSKidsOfficial",
            displayName: "PBS Kids 📚",
            email: "kids@pbs.org",
            profileImageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
            isVerified: true
        )
        
        return [
            Video(
                title: "ABC Song with Dancing Animals! 🎵🦁 Learn Your ABCs!",
                description: "Join our friendly animal friends as they sing and dance to the ABC song! Perfect for toddlers learning their letters. Educational and fun!",
                thumbnailURL: "https://images.unsplash.com/photo-1551963831-b3b1ca40c98e?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 180, // 3 minutes - perfect for kids
                viewCount: 2300000,
                likeCount: 345000,
                commentCount: 12000, // Limited comments for safety
                creator: kidsCreator,
                category: .kids,
                tags: ["kids", "abc", "learning", "animals", "educational", "toddlers", "safe"],
                contentSource: .pbsKids,
                contentRating: .TV_Y,
                language: "English",
                isVerified: true
            ),
            
            Video(
                title: "Daniel Tiger's Neighborhood: Sharing is Caring! 🐅❤️",
                description: "Learn about sharing with Daniel Tiger! A gentle lesson about friendship and kindness. Perfect for preschoolers developing social skills.",
                thumbnailURL: "https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 1440, // 24 minutes
                viewCount: 1800000,
                likeCount: 290000,
                commentCount: 8500,
                creator: pbsCreator,
                category: .kids,
                tags: ["daniel tiger", "sharing", "friendship", "preschool", "pbs kids", "social skills"],
                contentSource: .pbsKids,
                contentRating: .TV_Y,
                isVerified: true
            ),
            
            Video(
                title: "Fun Science Experiments for Kids! 🧪🌟 Safe & Easy!",
                description: "Amazing science experiments you can do at home! Adult supervision recommended. Learn about colors, bubbles, and simple chemistry safely!",
                thumbnailURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                duration: 900, // 15 minutes
                viewCount: 3200000,
                likeCount: 450000,
                commentCount: 15600,
                creator: User(
                    username: "ScienceForKids",
                    displayName: "Science for Kids 🔬",
                    email: "learn@scienceforkids.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
                    isVerified: true
                ),
                category: .kids,
                tags: ["kids", "science", "experiments", "educational", "safe", "learning", "STEM"],
                contentSource: .userUploaded,
                contentRating: .TV_Y7,
                isVerified: true
            ),
            
            Video(
                title: "Sesame Street: Cookie Monster's Healthy Snacks! 🍪🥕",
                description: "Cookie Monster learns about healthy eating! Fun lessons about nutrition with everyone's favorite blue monster. Me love healthy cookies!",
                thumbnailURL: "https://images.unsplash.com/photo-1551963831-b3b1ca40c98e?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                duration: 720, // 12 minutes
                viewCount: 2700000,
                likeCount: 380000,
                commentCount: 11200,
                creator: User(
                    username: "SesameStreetOfficial",
                    displayName: "Sesame Street 🏠",
                    email: "friends@sesamestreet.org",
                    profileImageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
                    isVerified: true
                ),
                category: .kids,
                tags: ["sesame street", "cookie monster", "healthy eating", "nutrition", "kids"],
                contentSource: .pbsKids,
                contentRating: .TV_Y,
                isVerified: true
            )
        ]
    }
    
    // 🍽️ MUKBANG - EATING SHOW VIBES
    static var mukbangVideos: [Video] {
        return [
            Video(
                title: "ULTIMATE Korean BBQ Mukbang FEAST! 🥩🔥 ASMR Eating",
                description: "The most satisfying Korean BBQ mukbang ever! Watch me devour pounds of marinated beef, spicy kimchi, and fresh lettuce wraps. Pure eating bliss!",
                thumbnailURL: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
                duration: 3600, // 1 hour - marathon eating!
                viewCount: 8900000,
                likeCount: 1200000,
                commentCount: 234000,
                creator: User(
                    username: "MukbangKingASMR",
                    displayName: "Mukbang King ASMR 👑🍽️",
                    email: "eat@mukbangking.com",
                    profileImageURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
                    isVerified: true
                ),
                category: .mukbang,
                tags: ["mukbang", "korean bbq", "asmr", "eating", "food", "satisfying"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 🔥 TRENDING CONTENT
    static var trendingVideos: [Video] {
        return [
            Video(
                title: "24 HOURS in a Japanese Convenience Store! 🏪",
                description: "I spent 24 hours living in a Japanese 7-Eleven! Trying every snack, sleeping in the store, and discovering Japan's amazing convenience culture!",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                duration: 1800, // 30 minutes
                viewCount: 12400000,
                likeCount: 1890000,
                commentCount: 345000,
                creator: User(
                    username: "JapanChallenges",
                    displayName: "Japan Challenges 🇯🇵",
                    email: "adventure@japanchallenges.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
                    isVerified: true
                ),
                category: .lifestyle,
                tags: ["challenge", "japan", "convenience store", "24 hours", "culture", "adventure"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🎬 MOVIES
    static var movieVideos: [Video] {
        return [
            Video(
                title: "The Lost Kingdom: Epic Fantasy Adventure (Full Movie)",
                description: "A legendary quest begins! Follow brave warriors as they search for the lost kingdom and battle mythical creatures. Award-winning fantasy epic!",
                thumbnailURL: "https://images.unsplash.com/photo-1489599511895-42ac8d2e6286?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
                duration: 7200, // 2 hours
                viewCount: 3400000,
                likeCount: 450000,
                commentCount: 67000,
                creator: User(
                    username: "EpicFilmsStudio",
                    displayName: "Epic Films Studio 🎬",
                    email: "info@epicfilms.com",
                    profileImageURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
                    isVerified: true
                ),
                category: .movies,
                tags: ["fantasy", "adventure", "epic", "full movie", "kingdom", "warriors"],
                contentSource: .archive,
                contentRating: .PG13,
                isVerified: true
            )
        ]
    }
    
    // 🎮 GAMING
    static var gamingVideos: [Video] {
        return [
            Video(
                title: "Fortnite Victory Royale Compilation - INSANE CLUTCHES! 🏆",
                description: "The most epic Fortnite victory royales ever! Watch these insane clutch moments that will leave you speechless. Pro gameplay at its finest!",
                thumbnailURL: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
                duration: 900, // 15 minutes
                viewCount: 6700000,
                likeCount: 890000,
                commentCount: 156000,
                creator: User(
                    username: "ProGamerElite",
                    displayName: "Pro Gamer Elite 🎮",
                    email: "clutch@progamer.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
                    isVerified: true
                ),
                category: .gaming,
                tags: ["fortnite", "victory royale", "gaming", "clutch", "pro player", "compilation"],
                contentSource: .twitch,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 🎵 MUSIC
    static var musicVideos: [Video] {
        return [
            Video(
                title: "Summer Vibes 2024 - Chill Hip Hop Mix 🌊🎵",
                description: "The perfect summer playlist! Smooth hip hop beats to vibe to. Perfect for studying, chilling, or just feeling good. Non-stop good vibes!",
                thumbnailURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
                duration: 3600, // 1 hour mix
                viewCount: 5200000,
                likeCount: 720000,
                commentCount: 89000,
                creator: User(
                    username: "ChillBeatsCollective",
                    displayName: "Chill Beats Collective 🎧",
                    email: "vibes@chillbeats.com",
                    profileImageURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=150",
                    isVerified: true
                ),
                category: .music,
                tags: ["hip hop", "chill", "summer", "vibes", "mix", "playlist", "study music"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 😂 COMEDY
    static var comedyVideos: [Video] {
        return [
            Video(
                title: "When You're the Only One Who Shows Up to Work 😂",
                description: "We've all been there! This hilarious sketch perfectly captures what happens when you're the only responsible one. Relatable comedy gold!",
                thumbnailURL: "https://images.unsplash.com/photo-1517315003714-a071486bd9ea?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
                duration: 240, // 4 minutes
                viewCount: 4100000,
                likeCount: 580000,
                commentCount: 78000,
                creator: User(
                    username: "ComedyCentral",
                    displayName: "Comedy Central 😂",
                    email: "laughs@comedy.com",
                    profileImageURL: "https://images.unsplash.com/photo-1517315003714-a071486bd9ea?w=150",
                    isVerified: true
                ),
                category: .comedy,
                tags: ["comedy", "sketch", "work", "relatable", "funny", "viral"],
                contentSource: .userUploaded,
                contentRating: .TV_PG,
                isVerified: true
            )
        ]
    }
    
    // 📚 EDUCATIONAL
    static var educationalVideos: [Video] {
        return [
            Video(
                title: "How the Internet Actually Works - Explained Simply! 🌐",
                description: "Ever wondered how the internet really works? This easy-to-understand explanation will blow your mind! From cables to satellites to your phone!",
                thumbnailURL: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
                duration: 960, // 16 minutes
                viewCount: 2800000,
                likeCount: 390000,
                commentCount: 45000,
                creator: User(
                    username: "ScienceExplained",
                    displayName: "Science Explained 🔬",
                    email: "learn@scienceexplained.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
                    isVerified: true
                ),
                category: .education,
                tags: ["internet", "technology", "education", "science", "explained", "learning"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 💅 LIFESTYLE
    static var lifestyleVideos: [Video] {
        return [
            Video(
                title: "My 5AM Morning Routine That Changed My Life! ☀️✨",
                description: "Transform your mornings and your life! My productive 5AM routine that boosted my energy, focus, and happiness. Game-changing tips inside!",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                duration: 720, // 12 minutes
                viewCount: 1900000,
                likeCount: 280000,
                commentCount: 34000,
                creator: User(
                    username: "WellnessGuru",
                    displayName: "Wellness Guru ✨",
                    email: "glow@wellnessguru.com",
                    profileImageURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
                    isVerified: true
                ),
                category: .lifestyle,
                tags: ["morning routine", "productivity", "wellness", "lifestyle", "self care", "motivation"],
                contentSource: .userUploaded,
                contentRating: .TV_G,
                isVerified: true
            )
        ]
    }
    
    // 🩳 SHORTS
    static var shortsVideos: [Video] {
        return [
            Video(
                title: "Dog Sees Owner After 6 Months - Pure Joy! 🐕❤️",
                description: "This reunion will melt your heart! Watch this dog's incredible reaction to seeing their owner after 6 months apart. Pure love! #shorts",
                thumbnailURL: "https://images.unsplash.com/photo-1552053831-71594a27632d?w=500",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 30, // 30 seconds
                viewCount: 15600000, // Shorts get massive views!
                likeCount: 2340000,
                commentCount: 456000,
                creator: User(
                    username: "WholesomeVibes",
                    displayName: "Wholesome Vibes 💕",
                    email: "heart@wholesomevibes.com",
                    profileImageURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150",
                    isVerified: true
                ),
                category: .shorts,
                tags: ["dog", "reunion", "wholesome", "pets", "love", "viral", "shorts"],
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