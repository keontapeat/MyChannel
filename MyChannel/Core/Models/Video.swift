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
    var visibility: VisibilityStatus = .public
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
    
    // Additional properties for compatibility
    var isSponsored: Bool?
    var chapters: [Chapter]? // YouTube-style chapters
    var videoCards: [VideoCard]? // YouTube-style video cards
    var endScreens: [EndScreen]? // YouTube-style end screens
    var ageRestricted: Bool?
    var madeForKids: Bool?
    var allowComments: Bool?
    var filmingLocation: String?
    var isPremiere: Bool?
    var transcript: VideoTranscript?
    
    // 🔥 NEW: MyChannel University Properties
    var isUniversityContent: Bool?  // Creator tagged this for University
    var universityCareerPaths: [String]?  // Career path IDs this video teaches
    var universitySkillTags: [String]?  // Specific skills covered
    var universityDifficultyLevel: UniversityVideo.DifficultyLevel?  // Difficulty level
    var universityCertificateEligible: Bool?  // Eligible for certificate tracking
    
    // ✅ Additional properties for Vertex AI agents
    var isTrending: Bool?  // For PlacementOptimizationAgent
    var hasCopyrightStrike: Bool?  // For PlacementOptimizationAgent
    
    // MARK: - Custom Coding Keys
    private enum CodingKeys: String, CodingKey {
        case id, title, description, thumbnailURL, videoURL, duration
        case viewCount, likeCount, dislikeCount, commentCount
        case createdAt, updatedAt, creatorId, creator, category
        case tags, isPublic, visibility, quality, aspectRatio, isLiveStream
        case scheduledAt, contentSource, externalID, contentRating
        case language, subtitles, isVerified, monetization, isSponsored, chapters
        case ageRestricted, madeForKids, allowComments, filmingLocation, isPremiere
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
        if let visibilityRaw = try container.decodeIfPresent(String.self, forKey: .visibility),
           let parsedVisibility = VisibilityStatus(rawValue: visibilityRaw.lowercased()) {
            visibility = parsedVisibility
            isPublic = parsedVisibility == .public
        } else {
            visibility = isPublic ? .public : .private
        }
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
        isSponsored = try container.decodeIfPresent(Bool.self, forKey: .isSponsored)
        chapters = try container.decodeIfPresent([Chapter].self, forKey: .chapters)
        ageRestricted = try container.decodeIfPresent(Bool.self, forKey: .ageRestricted)
        madeForKids = try container.decodeIfPresent(Bool.self, forKey: .madeForKids)
        allowComments = try container.decodeIfPresent(Bool.self, forKey: .allowComments)
        filmingLocation = try container.decodeIfPresent(String.self, forKey: .filmingLocation)
        isPremiere = try container.decodeIfPresent(Bool.self, forKey: .isPremiere)
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
        try container.encode(visibility.rawValue, forKey: .visibility)
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
        try container.encodeIfPresent(isSponsored, forKey: .isSponsored)
        try container.encodeIfPresent(chapters, forKey: .chapters)
        try container.encodeIfPresent(ageRestricted, forKey: .ageRestricted)
        try container.encodeIfPresent(madeForKids, forKey: .madeForKids)
        try container.encodeIfPresent(allowComments, forKey: .allowComments)
        try container.encodeIfPresent(filmingLocation, forKey: .filmingLocation)
        try container.encodeIfPresent(isPremiere, forKey: .isPremiere)
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
        visibility: VisibilityStatus? = nil,
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
        monetization: MonetizationSettings? = nil,
        isSponsored: Bool? = nil,
        chapters: [Chapter]? = nil,
        ageRestricted: Bool? = nil,
        madeForKids: Bool? = nil,
        allowComments: Bool? = nil,
        filmingLocation: String? = nil,
        isPremiere: Bool? = nil
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
        if let visibility = visibility {
            self.visibility = visibility
            self.isPublic = visibility == .public
        } else {
            self.visibility = isPublic ? .public : .private
            self.isPublic = isPublic
        }
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
        self.isSponsored = isSponsored
        self.chapters = chapters
        self.ageRestricted = ageRestricted
        self.madeForKids = madeForKids
        self.allowComments = allowComments
        self.filmingLocation = filmingLocation
        self.isPremiere = isPremiere
    }

    // MARK: - Chapters
    struct Chapter: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let start: TimeInterval
        let thumbnailURL: String?
        
        init(id: String = UUID().uuidString, title: String, start: TimeInterval, thumbnailURL: String? = nil) {
            self.id = id
            self.title = title
            self.start = start
            self.thumbnailURL = thumbnailURL
        }
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
        // 🔥 REAL-TIME ANALYTICS: Always show a sane, human-friendly "time ago"
        // Avoid weird strings like "in 0s" when server timestamps are slightly in the future
        let now = Date()
        
        // If createdAt is somehow in the future (clock skew / server timestamp),
        // treat it as "Just now" instead of "in 0s"
        if createdAt > now {
            return "Just now"
        }
        
        // Use our optimized helper for consistent, YouTube-style strings
        return createdAt.timeAgoDisplay
    }
    
    var uploadTimeAgo: String {
        return timeAgo // Same as timeAgo for consistency
    }
    
    var isNew: Bool {
        Date().timeIntervalSince(createdAt) < 24 * 60 * 60 // Less than 24 hours
    }

    // MARK: - Chapters parsing fallback from description
    var parsedChaptersFromDescription: [Chapter] {
        // Parse common timestamp formats like "0:00 Intro" or "1:23 - Topic"
        // Keep it lightweight: scan lines in description
        let lines = description.components(separatedBy: .newlines)
        var chapters: [Chapter] = []
        let regex = try? NSRegularExpression(pattern: "^\\s*(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s*[-–—]?\\s*(.+)$", options: [.caseInsensitive])
        for line in lines {
            guard let regex = regex else { continue }
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            if let m = regex.firstMatch(in: line, options: [], range: full) {
                let hRange = m.range(at: 3)
                let hasHours = hRange.location != NSNotFound
                let mm = Int(ns.substring(with: m.range(at: 1))) ?? 0
                let ss = Int(ns.substring(with: m.range(at: 2))) ?? 0
                let hh = hasHours ? (Int(ns.substring(with: hRange)) ?? 0) : 0
                let title = ns.substring(with: m.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                let total = hasHours ? (hh * 3600 + mm * 60 + ss) : (mm * 60 + ss)
                if total >= 0, !title.isEmpty {
                    chapters.append(Chapter(title: title, start: TimeInterval(total)))
                }
            }
        }
        return chapters
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
    
    enum VisibilityStatus: String, Codable, CaseIterable {
        case `public` = "public"
        case unlisted = "unlisted"
        case `private` = "private"
        
        var displayName: String {
            switch self {
            case .public: return "Public"
            case .unlisted: return "Unlisted"
            case .private: return "Private"
            }
        }
        
        var iconName: String {
            switch self {
            case .public: return "globe"
            case .unlisted: return "link"
            case .private: return "lock.fill"
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
            case .jikan, .anilist: return "play.tv.fill"
            case .archive: return "archivebox"
            case .youtube: return "play.rectangle"
            case .vimeo: return "v.circle"
            case .twitch: return "gamecontroller"
            case .dailymotion: return "play.circle"
            case .crunchyroll: return "play.tv.fill"
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
    
    // MARK: - 💰 Ad Placement Settings (YouTube-style)
    struct AdBreaks: Codable {
        let preRoll: Bool
        let midRoll: Bool
        let postRoll: Bool
        let midRollInterval: Int?  // Seconds between mid-roll ads (e.g., 480 = 8 minutes)
        
        init(
            preRoll: Bool = true,
            midRoll: Bool = true,
            postRoll: Bool = false,
            midRollInterval: Int? = 480
        ) {
            self.preRoll = preRoll
            self.midRoll = midRoll
            self.postRoll = postRoll
            self.midRollInterval = midRollInterval
        }
    }
    
    // MARK: - Monetization Settings
    struct MonetizationSettings: Codable {
        let isMonetized: Bool
        let adBreaks: AdBreaks?       // 💰 NEW: Simple boolean flags for YouTube-style ads
        let adBreakTimestamps: [AdBreak]?  // Original time-based ad breaks (for advanced control)
        let sponsorSegments: [SponsorSegment]?
        let merchandise: [MerchandiseItem]?
        let donationEnabled: Bool
        let subscriptionTier: SubscriptionTier?
        let totalRevenue: Double
        
        init(
            isMonetized: Bool = false,
            adBreaks: AdBreaks? = nil,
            adBreakTimestamps: [AdBreak]? = nil,
            sponsorSegments: [SponsorSegment]? = nil,
            merchandise: [MerchandiseItem]? = nil,
            donationEnabled: Bool = false,
            subscriptionTier: SubscriptionTier? = nil,
            totalRevenue: Double = 0.0
        ) {
            self.isMonetized = isMonetized
            self.adBreaks = adBreaks
            self.adBreakTimestamps = adBreakTimestamps
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
    // ✅ Added missing cases for RTB compatibility
    case howTo = "how_to"
    case scienceTech = "science_tech"
    case food = "food"
    case fashion = "fashion"
    case autos = "autos"
    case peopleBlogs = "people_blogs"
    case nonprofits = "nonprofits"
    case shopping = "shopping"  // ✅ Also needed for AdTargetingAGI
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
        // ✅ New categories
        case .howTo: return "How-To & Style"
        case .scienceTech: return "Science & Technology"
        case .food: return "Food & Drink"
        case .fashion: return "Fashion & Style"
        case .autos: return "Autos & Vehicles"
        case .peopleBlogs: return "People & Blogs"
        case .nonprofits: return "Nonprofits & Activism"
        case .shopping: return "Shopping"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .movies: return "tv"
        case .tvShows: return "tv.and.hifispeaker.fill"
        case .anime: return "play.tv.fill"
        case .kids: return "face.smiling.inverse" // 🎯 KID-FRIENDLY ICON
        case .mukbang: return "fork.knife"
        case .documentaries: return "doc.on.doc"
        case .shorts: return "rectangle.portrait"
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .cooking: return "fork.knife"
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
        case .entertainment: return "star.fill"
        case .cartoons: return "scribble.variable"
        case .adultAnimation: return "moon.stars.fill"
        case .howTo: return "hand.raised"
        case .scienceTech: return "atom"
        case .food: return "fork.knife"
        case .fashion: return "tshirt"
        case .autos: return "car"
        case .peopleBlogs: return "person.2"
        case .nonprofits: return "heart.circle"
        case .shopping: return "cart"
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
        case .howTo: return .blue
        case .scienceTech: return .cyan
        case .food: return .orange
        case .fashion: return .pink
        case .autos: return .gray
        case .peopleBlogs: return .indigo
        case .nonprofits: return .green
        case .shopping: return .red
        case .other: return .secondary
        }
    }
}

// MARK: - Sample Data Extensions
extension Video {
    static var sampleVideos: [Video] {
        guard AppConfig.Features.enableMockData else { return [] }
        return [
        Video(
            title: "Amazing Sunset Timelapse",
            description: "Beautiful sunset captured in 4K quality",
            thumbnailURL: "https://picsum.photos/400/600?random=1",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            duration: 45,
            viewCount: 125000,
            likeCount: 8950,
            commentCount: 234,
            creator: User.sampleUsers[0],
            category: .lifestyle,
            chapters: [
                Chapter(title: "Intro", start: 0),
                Chapter(title: "Golden Hour", start: 10),
                Chapter(title: "Afterglow", start: 25)
            ]
        ),
        Video(
            title: "Cooking the Perfect Pasta",
            description: "Step-by-step guide to making restaurant-quality pasta at home",
            thumbnailURL: "https://picsum.photos/400/600?random=2",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            duration: 120,
            viewCount: 89000,
            likeCount: 6700,
            commentCount: 189,
            creator: User.sampleUsers[2],
            category: .cooking,
            chapters: [
                Chapter(title: "Ingredients", start: 0),
                Chapter(title: "Sauce", start: 30),
                Chapter(title: "Plating", start: 90)
            ]
        ),
        Video(
            title: "Latest Tech Gadgets Review",
            description: "Comprehensive review of the newest tech gadgets",
            thumbnailURL: "https://picsum.photos/400/600?random=3",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            duration: 180,
            viewCount: 234000,
            likeCount: 12450,
            commentCount: 567,
            creator: User.sampleUsers[0],
            category: .technology
        ),
        Video(
            title: "Funny Pet Compilation",
            description: "Hilarious moments with our furry friends",
            thumbnailURL: "https://picsum.photos/400/600?random=4",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
            duration: 60,
            viewCount: 456000,
            likeCount: 23000,
            commentCount: 1200,
            creator: User.sampleUsers[4],
            category: .entertainment
        ),
        Video(
            title: "Travel Vlog: Tokyo Adventures",
            description: "Exploring the vibrant streets of Tokyo",
            thumbnailURL: "https://picsum.photos/400/600?random=5",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            duration: 200,
            viewCount: 178000,
            likeCount: 9800,
            commentCount: 345,
            creator: User.sampleUsers[3],
            category: .travel
        ),
        Video(
            title: "Music Production Tutorial",
            description: "Learn how to produce beats like a pro",
            thumbnailURL: "https://picsum.photos/400/600?random=6",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            duration: 150,
            viewCount: 67000,
            likeCount: 4500,
            commentCount: 123,
            creator: User.sampleUsers[1],
            category: .music
        ),
        Video(
            title: "Fitness Workout Routine",
            description: "30-minute full body workout you can do at home",
            thumbnailURL: "https://picsum.photos/400/600?random=7",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
            duration: 1800,
            viewCount: 89000,
            likeCount: 6700,
            commentCount: 234,
            creator: User.sampleUsers[0],
            category: .fitness
        ),
        Video(
            title: "Art Tutorial: Digital Painting",
            description: "Create stunning digital art with these techniques",
            thumbnailURL: "https://picsum.photos/400/600?random=8",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
            duration: 240,
            viewCount: 34000,
            likeCount: 2100,
            commentCount: 89,
            creator: User.sampleUsers[2],
            category: .art
        ),
        // Extra catalog to keep the feed rich for new users
        Video(
            title: "City Night Drive 4K",
            description: "Cruising through a neon city at night",
            thumbnailURL: "https://picsum.photos/seed/nightdrive/400/600",
            videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            duration: 420,
            viewCount: 210000,
            likeCount: 9800,
            commentCount: 312,
            creator: User.sampleUsers[1],
            category: .entertainment
        ),
        Video(
            title: "Cozy Lofi Beats",
            description: "2 hours of lofi for focus and chill",
            thumbnailURL: "https://picsum.photos/seed/lofibeats/400/600",
            videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
            duration: 7200,
            viewCount: 560000,
            likeCount: 32000,
            commentCount: 2200,
            creator: User.sampleUsers[0],
            category: .music
        ),
        Video(
            title: "Drone Over the City",
            description: "4K cinematic drone footage",
            thumbnailURL: "https://picsum.photos/seed/drone/400/600",
            videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            duration: 210,
            viewCount: 210000,
            likeCount: 9700,
            commentCount: 300,
            creator: User.sampleUsers[1],
            category: .travel
        ),
        Video(
            title: "Cooking Street Tacos",
            description: "Fast and tasty street tacos",
            thumbnailURL: "https://picsum.photos/seed/tacos/400/600",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            duration: 360,
            viewCount: 88000,
            likeCount: 5600,
            commentCount: 145,
            creator: User.sampleUsers[2],
            category: .cooking
        ),
        Video(
            title: "Workout HIIT Session",
            description: "15-minute HIIT routine",
            thumbnailURL: "https://picsum.photos/seed/hiit/400/600",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
            duration: 900,
            viewCount: 99000,
            likeCount: 7100,
            commentCount: 210,
            creator: User.sampleUsers[0],
            category: .fitness
        ),
        Video(
            title: "Coding SwiftUI Tips",
            description: "10 pro tips for SwiftUI",
            thumbnailURL: "https://picsum.photos/seed/swiftui/400/600",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            duration: 480,
            viewCount: 44000,
            likeCount: 3400,
            commentCount: 90,
            creator: User.sampleUsers[3],
            category: .technology
        ),
        Video(
            title: "Warzone Highlights",
            description: "Best clutch moments this week",
            thumbnailURL: "https://i.ytimg.com/vi/x9v2Q8l2dY4/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=x9v2Q8l2dY4",
            duration: 900,
            viewCount: 980000,
            likeCount: 54000,
            commentCount: 6500,
            creator: User(
                username: "cod_channel",
                displayName: "COD Highlights",
                email: "cod@yt.com",
                profileImageURL: "https://i.pravatar.cc/200?u=cod",
                isVerified: true,
                isCreator: true
            ),
            category: .gaming,
            contentSource: .youtube,
            externalID: "x9v2Q8l2dY4",
            isVerified: true
        ),
        Video(
            title: "Detroit Music – Rebound",
            description: "Scatz - Rebound (Official Music Video)",
            thumbnailURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=71GJrAY54Ew",
            duration: 94,
            viewCount: 5000,
            likeCount: 191,
            commentCount: 12,
            creator: User(
                username: "scatz",
                displayName: "Scatz",
                email: "music@artist.com",
                profileImageURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
                isVerified: true,
                isCreator: true
            ),
            category: .music,
            contentSource: .youtube,
            externalID: "71GJrAY54Ew",
            isVerified: true
        ),
        Video(
            title: "Free Movie: Big Buck Bunny",
            description: "Classic open movie in HD",
            thumbnailURL: "https://i.ytimg.com/vi/aqz-KE-bpKQ/hqdefault.jpg",
            videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            duration: 596,
            viewCount: 1500000,
            likeCount: 120000,
            commentCount: 9000,
            creator: User.sampleUsers[3],
            category: .movies
        )
        ]
    }
}

#Preview("Video Model Preview") {
    VStack(spacing: 20) {
        Text("Video Models")
            .font(AppTheme.Typography.largeTitle)
        
        ForEach(Array(Video.sampleVideos.prefix(2)), id: \.id) { video in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(video.title)
                        .font(AppTheme.Typography.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(video.formattedDuration)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(video.description)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    Label("\(video.formattedViewCount) views", systemImage: "eye")
                    Spacer()
                    Label("\(video.formattedLikeCount) likes", systemImage: "heart")
                    Spacer()
                    Label("\(video.timeAgo)", systemImage: "clock")
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                
                HStack {
                    Text("@\(video.creator.username)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Spacer()
                    
                    Text(video.category.displayName)
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(video.category.color.opacity(0.2))
                        .foregroundColor(video.category.color)
                        .cornerRadius(8)
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }
    .padding()
    .background(AppTheme.Colors.background)
}

// MARK: - Video Card Model
struct VideoCard: Identifiable, Codable {
    let id: String
    let type: CardType
    let title: String
    let subtitle: String?
    let thumbnailURL: String?
    let timestamp: TimeInterval // When to show the card
    let metadata: [String: Any]?
    
    enum CardType: String, Codable, CaseIterable {
        case video = "video"
        case playlist = "playlist"
        case channel = "channel"
        case link = "link"
        case poll = "poll"
    }
    
    // Custom coding for metadata
    private enum CodingKeys: String, CodingKey {
        case id, type, title, subtitle, thumbnailURL, timestamp
    }
    
    init(id: String, type: CardType, title: String, subtitle: String? = nil, thumbnailURL: String? = nil, timestamp: TimeInterval, metadata: [String: Any]? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(CardType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        metadata = nil // For now, we'll handle this separately if needed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Video Transcript Model
struct VideoTranscript: Codable {
    let language: String
    let segments: [TranscriptSegment]
    let isAutoGenerated: Bool
    let confidence: Double?
    
    struct TranscriptSegment: Identifiable, Codable {
        let id: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
        let confidence: Double?
    }
}







