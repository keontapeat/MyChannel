//
//  WatchHistoryItem.swift
//  MyChannel
//
//  Enhanced watch history tracking for YouTube parity
//

import Foundation

struct WatchHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let contentType: ContentType
    let contentId: String
    let title: String
    let thumbnailURL: String
    let creatorName: String
    let creatorId: String
    let duration: TimeInterval
    let watchedAt: Date
    var watchProgress: Double
    var lastPosition: TimeInterval
    
    enum ContentType: String, Codable, CaseIterable {
        case video
        case flick
        case story
        case liveTV
        case post
        
        var displayName: String {
            switch self {
            case .video: return "Video"
            case .flick: return "Short"
            case .story: return "Story"
            case .liveTV: return "Live TV"
            case .post: return "Post"
            }
        }
        
        var iconName: String {
            switch self {
            case .video: return "play.rectangle.fill"
            case .flick: return "rectangle.portrait.fill"
            case .story: return "circle.fill"
            case .liveTV: return "dot.radiowaves.left.and.right"
            case .post: return "text.bubble.fill"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        contentType: ContentType,
        contentId: String,
        title: String,
        thumbnailURL: String,
        creatorName: String,
        creatorId: String,
        duration: TimeInterval,
        watchedAt: Date = Date(),
        watchProgress: Double = 0.0,
        lastPosition: TimeInterval = 0.0
    ) {
        self.id = id
        self.contentType = contentType
        self.contentId = contentId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.creatorName = creatorName
        self.creatorId = creatorId
        self.duration = duration
        self.watchedAt = watchedAt
        self.watchProgress = watchProgress
        self.lastPosition = lastPosition
    }
    
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
    
    var timeAgo: String {
        watchedAt.timeAgoDisplay
    }
    
    var isCompleted: Bool {
        watchProgress >= 0.9
    }
    
    var canResume: Bool {
        (contentType == .video || contentType == .flick) && watchProgress > 0.05 && watchProgress < 0.9
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WatchHistoryItem, rhs: WatchHistoryItem) -> Bool {
        lhs.id == rhs.id
    }
    
    static func fromVideo(_ video: Video, watchedAt: Date = Date(), progress: Double = 0.0, position: TimeInterval = 0.0) -> WatchHistoryItem {
        WatchHistoryItem(
            contentType: video.isShort ? .flick : .video,
            contentId: video.id,
            title: video.title,
            thumbnailURL: video.thumbnailURL,
            creatorName: video.creator.displayName,
            creatorId: video.creator.id,
            duration: video.duration,
            watchedAt: watchedAt,
            watchProgress: progress,
            lastPosition: position
        )
    }
    
    static func fromStory(_ story: Story, creator: User, watchedAt: Date = Date()) -> WatchHistoryItem {
        WatchHistoryItem(
            contentType: .story,
            contentId: story.id,
            title: creator.displayName + "'s Story",
            thumbnailURL: story.thumbnail ?? story.mediaURL,
            creatorName: creator.displayName,
            creatorId: creator.id,
            duration: story.duration,
            watchedAt: watchedAt,
            watchProgress: 1.0,
            lastPosition: story.duration
        )
    }
    
    func toVideo() -> Video {
        Video(
            id: contentId,
            title: title,
            description: "",
            thumbnailURL: thumbnailURL,
            videoURL: "",
            duration: duration,
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            createdAt: watchedAt,
            creator: User(
                username: creatorId,
                displayName: creatorName,
                email: "",
                profileImageURL: "",
                bannerImageURL: nil,
                bio: nil,
                subscriberCount: 0,
                videoCount: 0,
                isVerified: false,
                isCreator: true
            ),
            category: .entertainment,
            tags: [],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: contentType == .flick ? .portrait : .landscape,
            isLiveStream: contentType == .liveTV,
            contentSource: .userUploaded,
            isVerified: false
        )
    }

    static func fromLiveTV(_ channel: LiveTVChannel, watchedAt: Date = Date(), duration: TimeInterval = 0.0) -> WatchHistoryItem {
        WatchHistoryItem(
            contentType: .liveTV,
            contentId: channel.id,
            title: channel.name,
            thumbnailURL: channel.logoURL,
            creatorName: channel.name,
            creatorId: channel.id,
            duration: duration,
            watchedAt: watchedAt,
            watchProgress: 0.0,
            lastPosition: 0.0
        )
    }
    
    static func fromCommunityPost(_ post: CommunityPost, creator: User, watchedAt: Date = Date()) -> WatchHistoryItem {
        let title = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return WatchHistoryItem(
            contentType: .post,
            contentId: post.id,
            title: title.isEmpty ? "\(creator.displayName)'s Post" : String(title.prefix(120)),
            thumbnailURL: post.imageURLs.first ?? creator.profileImageURL ?? "",
            creatorName: creator.displayName,
            creatorId: creator.id,
            duration: 0,
            watchedAt: watchedAt,
            watchProgress: 1.0,
            lastPosition: 0.0
        )
    }
}

extension Date {
    var isThisMonth: Bool {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return self > monthAgo && !isThisWeek && !isToday && !isYesterday
    }
    
    var historySection: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isThisWeek {
            return "This Week"
        } else if isThisMonth {
            return "This Month"
        } else {
            return "Older"
        }
    }
}
