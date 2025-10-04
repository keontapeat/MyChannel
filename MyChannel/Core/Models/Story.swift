//
//  Story.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Foundation

// MARK: - Story Model
struct Story: Identifiable, Codable, Equatable {
    let id: String
    let creatorId: String
    let mediaURL: String
    let mediaType: MediaType
    let duration: TimeInterval
    let caption: String?
    let text: String?
    let createdAt: Date
    let expiresAt: Date
    let viewCount: Int
    let isViewed: Bool
    let thumbnail: String?
    let isLive: Bool
    
    // Story content array for multi-slide stories
    let content: [StoryContent]
    
    // Story metadata
    let backgroundColor: String?
    let textColor: String?
    let music: StoryMusic?
    let stickers: [StorySticker]
    let polls: [StoryPoll]
    let links: [StoryLink]
    
    init(
        id: String = UUID().uuidString,
        creatorId: String,
        mediaURL: String,
        mediaType: MediaType,
        duration: TimeInterval = 15.0,
        caption: String? = nil,
        text: String? = nil,
        createdAt: Date = Date(),
        expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date(),
        viewCount: Int = 0,
        isViewed: Bool = false,
        thumbnail: String? = nil,
        isLive: Bool = false,
        content: [StoryContent] = [],
        backgroundColor: String? = nil,
        textColor: String? = nil,
        music: StoryMusic? = nil,
        stickers: [StorySticker] = [],
        polls: [StoryPoll] = [],
        links: [StoryLink] = []
    ) {
        self.id = id
        self.creatorId = creatorId
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.duration = duration
        self.caption = caption
        self.text = text
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.viewCount = viewCount
        self.isViewed = isViewed
        self.thumbnail = thumbnail
        self.isLive = isLive
        self.content = content.isEmpty ? [StoryContent(id: id, url: mediaURL, type: mediaType, duration: duration, text: text, backgroundColor: backgroundColor)] : content
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.music = music
        self.stickers = stickers
        self.polls = polls
        self.links = links
    }
    
    enum MediaType: String, Codable, CaseIterable {
        case image = "image"
        case video = "video"
        case text = "text"
        case music = "music"
        
        var displayName: String {
            switch self {
            case .image: return "Photo"
            case .video: return "Video"
            case .text: return "Text"
            case .music: return "Music"
            }
        }
        
        var iconName: String {
            switch self {
            case .image: return "photo"
            case .video: return "video"
            case .text: return "text.bubble"
            case .music: return "music.note"
            }
        }
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    var creator: User? {
        User.sampleUsers.first { $0.id == creatorId }
    }
    
    static func == (lhs: Story, rhs: Story) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Story Content
struct StoryContent: Identifiable, Codable, Equatable {
    let id: String
    let url: String
    let type: Story.MediaType
    let duration: TimeInterval
    let text: String?
    let backgroundColor: String?
    
    init(
        id: String = UUID().uuidString,
        url: String,
        type: Story.MediaType,
        duration: TimeInterval = 15.0,
        text: String? = nil,
        backgroundColor: String? = nil
    ) {
        self.id = id
        self.url = url
        self.type = type
        self.duration = duration
        self.text = text
        self.backgroundColor = backgroundColor
    }
    
    static func == (lhs: StoryContent, rhs: StoryContent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Story Music
struct StoryMusic: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let previewURL: String
    let duration: TimeInterval
    let startTime: TimeInterval
    
    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        previewURL: String,
        duration: TimeInterval = 30.0,
        startTime: TimeInterval = 0.0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.previewURL = previewURL
        self.duration = duration
        self.startTime = startTime
    }
}

// MARK: - Story Sticker
struct StorySticker: Identifiable, Codable, Equatable {
    let id: String
    let type: StickerType
    let x: Double
    let y: Double
    let scale: Double
    let rotation: Double
    let data: StickerData
    
    init(
        id: String = UUID().uuidString,
        type: StickerType,
        x: Double,
        y: Double,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        data: StickerData
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.data = data
    }
    
    enum StickerType: String, Codable, CaseIterable {
        case emoji = "emoji"
        case gif = "gif"
        case location = "location"
        case mention = "mention"
        case hashtag = "hashtag"
        case time = "time"
        case weather = "weather"
        case poll = "poll"
        case countdown = "countdown"
        
        var displayName: String {
            switch self {
            case .emoji: return "Emoji"
            case .gif: return "GIF"
            case .location: return "Location"
            case .mention: return "Mention"
            case .hashtag: return "Hashtag"
            case .time: return "Time"
            case .weather: return "Weather"
            case .poll: return "Poll"
            case .countdown: return "Countdown"
            }
        }
    }
}

// MARK: - Sticker Data
enum StickerData: Codable, Equatable {
    case emoji(String)
    case gif(String)
    case location(String, Double, Double) // name, lat, lng
    case mention(User)
    case hashtag(String)
    case time(Date)
    case weather(String, String) // condition, temperature
    case poll(question: String, options: [String], votes: [Int])
    case countdown(title: String, endTime: Date)
    
    var displayText: String {
        switch self {
        case .emoji(let emoji):
            return emoji
        case .gif:
            return "GIF"
        case .location(let name, _, _):
            return name
        case .mention(let user):
            return "@\(user.username)"
        case .hashtag(let tag):
            return "#\(tag)"
        case .time(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        case .weather(let condition, let temp):
            return "\(condition) \(temp)"
        case .poll(let question, _, _):
            return question
        case .countdown(let title, _):
            return title
        }
    }
}

// MARK: - Story Poll
struct StoryPoll: Identifiable, Codable, Equatable {
    let id: String
    let question: String
    let options: [PollOption]
    let x: Double
    let y: Double
    let expiresAt: Date
    
    init(
        id: String = UUID().uuidString,
        question: String,
        options: [PollOption],
        x: Double,
        y: Double,
        expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.x = x
        self.y = y
        self.expiresAt = expiresAt
    }
    
    struct PollOption: Identifiable, Codable, Equatable {
        let id: String
        let text: String
        let voteCount: Int
        let color: String
        
        init(
            id: String = UUID().uuidString,
            text: String,
            voteCount: Int = 0,
            color: String = "#FF6B6B"
        ) {
            self.id = id
            self.text = text
            self.voteCount = voteCount
            self.color = color
        }
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var totalVotes: Int {
        options.reduce(0) { $0 + $1.voteCount }
    }
}

// MARK: - Story Link
struct StoryLink: Identifiable, Codable, Equatable {
    let id: String
    let url: String
    let title: String
    let description: String?
    let imageURL: String?
    let x: Double
    let y: Double
    
    init(
        id: String = UUID().uuidString,
        url: String,
        title: String,
        description: String? = nil,
        imageURL: String? = nil,
        x: Double,
        y: Double
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.x = x
        self.y = y
    }
}

// MARK: - Story Collection
struct StoryCollection: Identifiable, Equatable {
    let id: String
    let creatorId: String
    let stories: [Story]
    let lastUpdated: Date
    
    init(
        id: String = UUID().uuidString,
        creatorId: String,
        stories: [Story],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.creatorId = creatorId
        self.stories = stories
        self.lastUpdated = lastUpdated
    }
    
    var creator: User? {
        User.sampleUsers.first { $0.id == creatorId }
    }
    
    var activeStories: [Story] {
        stories.filter { !$0.isExpired }.sorted { $0.createdAt < $1.createdAt }
    }
    
    var hasUnviewedStories: Bool {
        activeStories.contains { !$0.isViewed }
    }
    
    var latestStory: Story? {
        activeStories.last
    }
    
    static func == (lhs: StoryCollection, rhs: StoryCollection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data
extension Story {
    // Removed sample stories to create authentic experience
    // Users will only see stories from people they actually follow
    static let sampleStories: [Story] = []
    
    // Also remove sample collections since they depend on sample stories
    static let sampleCollections: [StoryCollection] = []
}

#Preview {
    VStack(spacing: 20) {
        Text("Story System")
            .font(.largeTitle)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Authentic Stories Experience:")
                .font(.headline)
            
            let features = [
                "No mock stories for new users",
                "Stories only from followed creators",
                "Real-time story loading",
                "Interactive stickers",
                "Location tags",
                "User mentions",
                "Polls and questions",
                "Music integration"
            ]
            
            ForEach(features, id: \.self) { feature in
                HStack {
                    Text("•")
                        .foregroundColor(.blue)
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}