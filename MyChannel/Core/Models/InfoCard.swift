//
//  InfoCard.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Info Card Model (YouTube-style interactive cards)
struct InfoCard: Identifiable, Codable, Equatable {
    let id: String
    let videoId: String
    let type: InfoCardType
    let title: String
    let message: String?
    let thumbnailURL: String?
    let timestamp: TimeInterval // When to show the card during playback
    let duration: TimeInterval // How long to show the teaser (default 5 seconds)
    let destination: InfoCardDestination
    let customCallToAction: String?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        type: InfoCardType,
        title: String,
        message: String? = nil,
        thumbnailURL: String? = nil,
        timestamp: TimeInterval,
        duration: TimeInterval = 5.0,
        destination: InfoCardDestination,
        customCallToAction: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.videoId = videoId
        self.type = type
        self.title = title
        self.message = message
        self.thumbnailURL = thumbnailURL
        self.timestamp = timestamp
        self.duration = duration
        self.destination = destination
        self.customCallToAction = customCallToAction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var callToAction: String {
        customCallToAction ?? type.defaultCallToAction
    }
    
    var iconName: String {
        type.iconName
    }
}

// MARK: - Info Card Type
enum InfoCardType: String, Codable, CaseIterable {
    case video = "video"
    case playlist = "playlist"
    case channel = "channel"
    case link = "link"
    case poll = "poll"
    case merchandise = "merchandise"
    case donation = "donation"
    case associatedWebsite = "associated_website"
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .playlist: return "Playlist"
        case .channel: return "Channel"
        case .link: return "Link"
        case .poll: return "Poll"
        case .merchandise: return "Merchandise"
        case .donation: return "Donation"
        case .associatedWebsite: return "Associated Website"
        }
    }
    
    var iconName: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .playlist: return "list.bullet.rectangle.fill"
        case .channel: return "person.crop.circle.fill"
        case .link: return "link"
        case .poll: return "chart.bar.fill"
        case .merchandise: return "cart.fill"
        case .donation: return "heart.fill"
        case .associatedWebsite: return "globe"
        }
    }
    
    var defaultCallToAction: String {
        switch self {
        case .video: return "Watch"
        case .playlist: return "View Playlist"
        case .channel: return "Visit Channel"
        case .link: return "Learn More"
        case .poll: return "Vote Now"
        case .merchandise: return "Shop Now"
        case .donation: return "Support"
        case .associatedWebsite: return "Visit Website"
        }
    }
    
    var color: Color {
        switch self {
        case .video: return AppTheme.Colors.primary
        case .playlist: return AppTheme.Colors.secondary
        case .channel: return AppTheme.Colors.verificationBlue
        case .link: return AppTheme.Colors.accent
        case .poll: return .orange
        case .merchandise: return .purple
        case .donation: return .pink
        case .associatedWebsite: return .teal
        }
    }
}

// MARK: - Info Card Destination
enum InfoCardDestination: Codable, Equatable {
    case videoId(String)
    case playlistId(String)
    case channelId(String)
    case externalURL(String)
    case pollId(String)
    case merchandiseURL(String)
    case donationURL(String)
    
    var urlString: String? {
        switch self {
        case .videoId(let id): return "mychannel://video/\(id)"
        case .playlistId(let id): return "mychannel://playlist/\(id)"
        case .channelId(let id): return "mychannel://channel/\(id)"
        case .externalURL(let url): return url
        case .pollId(let id): return "mychannel://poll/\(id)"
        case .merchandiseURL(let url): return url
        case .donationURL(let url): return url
        }
    }
    
    // Custom Codable implementation
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        
        switch type {
        case "videoId": self = .videoId(value)
        case "playlistId": self = .playlistId(value)
        case "channelId": self = .channelId(value)
        case "externalURL": self = .externalURL(value)
        case "pollId": self = .pollId(value)
        case "merchandiseURL": self = .merchandiseURL(value)
        case "donationURL": self = .donationURL(value)
        default: self = .externalURL(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .videoId(let id):
            try container.encode("videoId", forKey: .type)
            try container.encode(id, forKey: .value)
        case .playlistId(let id):
            try container.encode("playlistId", forKey: .type)
            try container.encode(id, forKey: .value)
        case .channelId(let id):
            try container.encode("channelId", forKey: .type)
            try container.encode(id, forKey: .value)
        case .externalURL(let url):
            try container.encode("externalURL", forKey: .type)
            try container.encode(url, forKey: .value)
        case .pollId(let id):
            try container.encode("pollId", forKey: .type)
            try container.encode(id, forKey: .value)
        case .merchandiseURL(let url):
            try container.encode("merchandiseURL", forKey: .type)
            try container.encode(url, forKey: .value)
        case .donationURL(let url):
            try container.encode("donationURL", forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }
}

// MARK: - Sample Data
extension InfoCard {
    static let sampleCards: [InfoCard] = [
        InfoCard(
            videoId: "video-1",
            type: .video,
            title: "Part 2: Advanced Techniques",
            message: "Continue learning with the next video in this series",
            thumbnailURL: "https://picsum.photos/400/225?random=card1",
            timestamp: 30,
            destination: .videoId("video-2")
        ),
        InfoCard(
            videoId: "video-1",
            type: .playlist,
            title: "Complete Tutorial Series",
            message: "Watch all 10 episodes",
            thumbnailURL: "https://picsum.photos/400/225?random=card2",
            timestamp: 60,
            destination: .playlistId("playlist-1")
        ),
        InfoCard(
            videoId: "video-1",
            type: .channel,
            title: "Subscribe to TechMaster",
            message: "Get notified when I post new content",
            thumbnailURL: "https://picsum.photos/100/100?random=avatar1",
            timestamp: 90,
            destination: .channelId("channel-1")
        ),
        InfoCard(
            videoId: "video-1",
            type: .link,
            title: "Download the Source Code",
            message: "Free GitHub repository",
            timestamp: 120,
            destination: .externalURL("https://github.com/example/repo"),
            customCallToAction: "Get Code"
        ),
        InfoCard(
            videoId: "video-1",
            type: .poll,
            title: "What should I cover next?",
            message: "Vote for the next topic",
            timestamp: 150,
            destination: .pollId("poll-1")
        ),
        InfoCard(
            videoId: "video-1",
            type: .merchandise,
            title: "Get My SwiftUI Course",
            message: "50% off this week only!",
            thumbnailURL: "https://picsum.photos/400/225?random=merch1",
            timestamp: 180,
            destination: .merchandiseURL("https://example.com/course"),
            customCallToAction: "Enroll Now"
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("Info Card Types")
                .font(AppTheme.Typography.largeTitle)
                .padding(.top)
            
            ForEach(InfoCard.sampleCards) { card in
                HStack(spacing: 12) {
                    Image(systemName: card.iconName)
                        .font(.title2)
                        .foregroundColor(card.type.color)
                        .frame(width: 44, height: 44)
                        .background(card.type.color.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.title)
                            .font(AppTheme.Typography.headline)
                        
                        if let message = card.message {
                            Text(message)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        HStack {
                            Text("@ \(card.formattedTimestamp)")
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Spacer()
                            
                            Text(card.callToAction)
                                .font(AppTheme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(card.type.color)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.background)
}







