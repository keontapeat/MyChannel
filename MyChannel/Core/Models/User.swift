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
    // Optional video banner. If present, header shows a looping video background instead of an image banner
    let bannerVideoURL: String?
    let bannerVideoMuted: Bool?
    let bannerVideoContentMode: BannerContentMode?
    let bio: String?
    let subscriberCount: Int
    let videoCount: Int
    let isVerified: Bool
    let isCreator: Bool
    let createdAt: Date
    let location: String?
    let website: String?
    let socialLinks: [SocialLink]
    
    // Additional properties for compatibility
    let followerCount: Int
    let followingCount: Int
    let joinDate: Date
    
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
        followerCount: Int? = nil,
        followingCount: Int = 0,
        joinDate: Date? = nil,
        totalViews: Int? = nil,
        totalEarnings: Double? = nil,
        membershipTiers: [MembershipTier]? = nil,
        bannerVideoURL: String? = nil,
        bannerVideoMuted: Bool? = nil,
        bannerVideoContentMode: BannerContentMode? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profileImageURL = profileImageURL
        self.bannerImageURL = bannerImageURL
        self.bannerVideoURL = bannerVideoURL
        self.bannerVideoMuted = bannerVideoMuted
        self.bannerVideoContentMode = bannerVideoContentMode
        self.bio = bio
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
        self.isVerified = isVerified
        self.isCreator = isCreator
        self.createdAt = createdAt
        self.location = location
        self.website = website
        self.socialLinks = socialLinks
        self.followerCount = followerCount ?? subscriberCount
        self.followingCount = followingCount
        self.joinDate = joinDate ?? createdAt
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

// MARK: - Banner Content Mode
enum BannerContentMode: String, Codable {
    case fill // resizeAspectFill
    case fit  // resizeAspect
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

// MARK: - Sample Data Extensions  
#if DEBUG
extension User {
    static let sampleUsers: [User] = [
        User(
            id: "user1",
            username: "sbkeonta_",
            displayName: "Keonta Peat",
            email: "keontapeat@mychannel.live",
            profileImageURL: "https://picsum.photos/200/200?random=1",
            bio: "Shot By Keonta Flint, MI Videographer",
            subscriberCount: 25400,
            videoCount: 156,
            isVerified: true,
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://instagram.com/naturelover_sarah", displayName: "@naturelover_sarah"),
                SocialLink(platform: .twitter, url: "https://twitter.com/sarah_nature", displayName: "@sarah_nature")
            ],
            followingCount: 892,
            totalViews: 2_000_000
        ),
        User(
            id: "user2", 
            username: "chef_marco",
            displayName: "Marco Rodriguez",
            email: "marco@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=2",
            bio: "Professional chef sharing family recipes 👨‍🍳 Making cooking accessible for everyone!",
            subscriberCount: 89300,
            videoCount: 203,
            isVerified: true,
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://instagram.com/chef_marco", displayName: "@chef_marco"),
                SocialLink(platform: .website, url: "https://marcosrecipes.com", displayName: "Marco's Recipes")
            ],
            followingCount: 234
        ),
        User(
            id: "user3",
            username: "tokyo_artist",
            displayName: "Yuki Tanaka", 
            email: "yuki@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=3",
            bio: "Street artist from Tokyo 🎨 Bringing color to the concrete jungle",
            subscriberCount: 15600,
            videoCount: 89,
            isVerified: false,
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://instagram.com/tokyo_artist", displayName: "@tokyo_artist")
            ],
            followingCount: 567
        ),
        User(
            id: "user4",
            username: "fitlife_emma",
            displayName: "Emma Wilson",
            email: "emma@example.com", 
            profileImageURL: "https://picsum.photos/200/200?random=4",
            bio: "Certified personal trainer 💪 Helping you achieve your fitness goals from home",
            subscriberCount: 156700,
            videoCount: 342,
            isVerified: true,
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://instagram.com/fitlife_emma", displayName: "@fitlife_emma"),
                SocialLink(platform: .website, url: "https://emmafitness.com", displayName: "Emma Fitness"),
                SocialLink(platform: .youtube, url: "https://youtube.com/emmawilsonfitness", displayName: "Emma Wilson Fitness")
            ],
            followingCount: 445
        ),
        User(
            id: "user5",
            username: "swift_dev_alex",
            displayName: "Alex Chen",
            email: "alex@example.com",
            profileImageURL: "https://picsum.photos/200/200?random=5", 
            bio: "iOS Developer & Swift enthusiast 📱 Teaching programming through simple tutorials",
            subscriberCount: 45200,
            videoCount: 178,
            isVerified: true,
            socialLinks: [
                SocialLink(platform: .twitter, url: "https://twitter.com/swift_dev_alex", displayName: "@swift_dev_alex"),
                SocialLink(platform: .website, url: "https://alexchen.dev", displayName: "Alex Chen Dev")
            ],
            followingCount: 234
        )
    ]
    
    static let defaultUser = User(
        username: "default_user",
        displayName: "Default User",
        email: "default@mychannel.com"
    )
}
#endif

#Preview("User Model Preview") {
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