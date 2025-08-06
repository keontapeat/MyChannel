//
//  User.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let profileImageURL: String?
    let bannerImageURL: String?
    let bio: String?
    let subscriberCount: Int
    let videoCount: Int
    let isVerified: Bool
    let isCreator: Bool
    let createdAt: Date
    let location: String?
    let website: String?
    let socialLinks: [SocialLink]
    
    // Creator-specific properties
    let totalViews: Int?
    let totalEarnings: Double?
    let membershipTiers: [MembershipTier]?
    
    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        email: String,
        profileImageURL: String? = nil,
        bannerImageURL: String? = nil,
        bio: String? = nil,
        subscriberCount: Int = 0,
        videoCount: Int = 0,
        isVerified: Bool = false,
        isCreator: Bool = false,
        createdAt: Date = Date(),
        location: String? = nil,
        website: String? = nil,
        socialLinks: [SocialLink] = [],
        totalViews: Int? = nil,
        totalEarnings: Double? = nil,
        membershipTiers: [MembershipTier]? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profileImageURL = profileImageURL
        self.bannerImageURL = bannerImageURL
        self.bio = bio
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
        self.isVerified = isVerified
        self.isCreator = isCreator
        self.createdAt = createdAt
        self.location = location
        self.website = website
        self.socialLinks = socialLinks
        self.totalViews = totalViews
        self.totalEarnings = totalEarnings
        self.membershipTiers = membershipTiers
    }
    
    // MARK: - Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Social Link Model
struct SocialLink: Identifiable, Codable, Equatable {
    let id: String
    let platform: SocialPlatform
    let url: String
    let displayName: String
    
    init(
        id: String = UUID().uuidString,
        platform: SocialPlatform,
        url: String,
        displayName: String
    ) {
        self.id = id
        self.platform = platform
        self.url = url
        self.displayName = displayName
    }
    
    // MARK: - Equatable
    static func == (lhs: SocialLink, rhs: SocialLink) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Social Platform Enum
enum SocialPlatform: String, CaseIterable, Codable {
    case twitter = "twitter"
    case instagram = "instagram"
    case tiktok = "tiktok"
    case youtube = "youtube"
    case twitch = "twitch"
    case website = "website"
    case discord = "discord"
    case linkedin = "linkedin"
    
    var displayName: String {
        switch self {
        case .twitter: return "Twitter"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .twitch: return "Twitch"
        case .website: return "Website"
        case .discord: return "Discord"
        case .linkedin: return "LinkedIn"
        }
    }
    
    var iconName: String {
        switch self {
        case .twitter: return "message"
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .twitch: return "tv"
        case .website: return "globe"
        case .discord: return "bubble.left.and.bubble.right"
        case .linkedin: return "person.2"
        }
    }
}

// MARK: - Membership Tier Model
struct MembershipTier: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let currency: String
    let benefits: [String]
    let badgeColor: String
    let isActive: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        price: Double,
        currency: String = "USD",
        benefits: [String],
        badgeColor: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.currency = currency
        self.benefits = benefits
        self.badgeColor = badgeColor
        self.isActive = isActive
    }
    
    // MARK: - Equatable
    static func == (lhs: MembershipTier, rhs: MembershipTier) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data
extension User {
    static let sampleUsers: [User] = [
        User(
            username: "techcreator",
            displayName: "Tech Creator",
            email: "tech@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=1",
            bannerImageURL: "https://picsum.photos/800/200?random=1",
            bio: "Creating amazing tech content daily! 🚀",
            subscriberCount: 125000,
            videoCount: 245,
            isVerified: true,
            isCreator: true,
            location: "San Francisco, CA",
            website: "https://techcreator.com",
            socialLinks: [
                SocialLink(platform: .twitter, url: "https://twitter.com/techcreator", displayName: "@techcreator"),
                SocialLink(platform: .instagram, url: "https://instagram.com/techcreator", displayName: "@techcreator")
            ],
            totalViews: 2500000,
            totalEarnings: 15000.0,
            membershipTiers: [
                MembershipTier(
                    name: "Supporter",
                    description: "Support the channel and get exclusive perks",
                    price: 4.99,
                    benefits: ["Early access to videos", "Custom badge", "Monthly Q&A"],
                    badgeColor: "4ECDC4"
                ),
                MembershipTier(
                    name: "Pro Member",
                    description: "Get premium content and direct access",
                    price: 9.99,
                    benefits: ["All Supporter benefits", "Private Discord", "1-on-1 monthly call"],
                    badgeColor: "FF6B6B"
                )
            ]
        ),
        User(
            username: "artisfun",
            displayName: "Creative Artist",
            email: "artist@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=2",
            bannerImageURL: "https://picsum.photos/800/200?random=2",
            bio: "Digital art tutorials and speedpaints ✨",
            subscriberCount: 89000,
            videoCount: 156,
            isVerified: false,
            isCreator: true,
            location: "New York, NY",
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://instagram.com/artisfun", displayName: "@artisfun"),
                SocialLink(platform: .website, url: "https://artisfun.com", displayName: "artisfun.com")
            ],
            totalViews: 1800000,
            totalEarnings: 8500.0
        ),
        User(
            username: "gamingpro",
            displayName: "Gaming Pro",
            email: "gaming@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=3",
            bannerImageURL: "https://picsum.photos/800/200?random=3",
            bio: "Professional gamer sharing tips and gameplay 🎮",
            subscriberCount: 456000,
            videoCount: 389,
            isVerified: true,
            isCreator: true,
            location: "Los Angeles, CA",
            socialLinks: [
                SocialLink(platform: .twitch, url: "https://twitch.tv/gamingpro", displayName: "gamingpro"),
                SocialLink(platform: .twitter, url: "https://twitter.com/gamingpro", displayName: "@gamingpro")
            ],
            totalViews: 5600000,
            totalEarnings: 28900.0
        ),
        User(
            username: "musicmaker",
            displayName: "Music Maker",
            email: "music@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=4",
            bannerImageURL: "https://picsum.photos/800/200?random=4",
            bio: "Creating beats and teaching music production 🎵",
            subscriberCount: 234000,
            videoCount: 167,
            isVerified: true,
            isCreator: true,
            location: "Nashville, TN",
            socialLinks: [
                SocialLink(platform: .youtube, url: "https://youtube.com/musicmaker", displayName: "Music Maker"),
                SocialLink(platform: .website, url: "https://musicmaker.com", displayName: "musicmaker.com")
            ],
            totalViews: 3400000,
            totalEarnings: 19500.0
        )
    ]
    
    // Add a safe, default user to use as a fallback
    static let defaultUser = User(
        username: "user",
        displayName: "User",
        email: "user@example.com",
        bio: "Loading...",
        isCreator: false
    )
}

struct User_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("User Models")
                .font(AppTheme.Typography.largeTitle)
            
            ForEach(User.sampleUsers.prefix(2)) { user in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(user.displayName)
                            .font(AppTheme.Typography.headline)
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        Spacer()
                    }
                    
                    Text("@\(user.username)")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if let bio = user.bio {
                        Text(bio)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    HStack {
                        Label("\(user.subscriberCount.formatted()) subscribers", systemImage: "person.2")
                        Spacer()
                        Label("\(user.videoCount) videos", systemImage: "play.rectangle")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .cardStyle()
                .padding(.horizontal)
            }
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}