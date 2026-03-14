//
//  User.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable, Equatable, Hashable {
    
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case id, username, displayName, email
        case profileImageURL, bannerImageURL, bannerVideoURL
        case bannerVideoMuted, bannerVideoContentMode
        case bio, subscriberCount, videoCount
        case isVerified, isCreator, createdAt
        case location, website, socialLinks
        case followerCount, followingCount, joinDate
        case totalViews, totalEarnings, membershipTiers
        case showWebsiteOnProfile, showOnlineStatus, verificationBadge
    }
    let id: String
    let username: String
    let displayName: String
    let email: String
    let profileImageURL: String?
    let bannerImageURL: String?
    // Optional video banner. If present, header shows a looping video background instead of an image banner
    let bannerVideoURL: String?
    let bannerVideoMuted: Bool?
    let bannerVideoContentMode: UserBannerContentMode?
    let bio: String?
    let subscriberCount: Int
    let videoCount: Int
    let isVerified: Bool
    let isCreator: Bool
    let createdAt: Date
    let location: String?
    let website: String?
    let showWebsiteOnProfile: Bool?
    let showOnlineStatus: Bool?
    let socialLinks: [SocialLink]
    
    // Additional properties for compatibility
    let followerCount: Int
    let followingCount: Int
    let joinDate: Date
    
    // Creator-specific properties
    let totalViews: Int?
    let totalEarnings: Double?
    let membershipTiers: [MembershipTier]?
    
    // Verification badge
    let verificationBadge: VerificationBadge?
    
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
        showWebsiteOnProfile: Bool? = nil,
        showOnlineStatus: Bool? = nil,
        socialLinks: [SocialLink] = [],
        followerCount: Int? = nil,
        followingCount: Int = 0,
        joinDate: Date? = nil,
        totalViews: Int? = nil,
        totalEarnings: Double? = nil,
        membershipTiers: [MembershipTier]? = nil,
        verificationBadge: VerificationBadge? = nil,
        bannerVideoURL: String? = nil,
        bannerVideoMuted: Bool? = nil,
        bannerVideoContentMode: UserBannerContentMode? = nil
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
        self.showWebsiteOnProfile = showWebsiteOnProfile
        self.showOnlineStatus = showOnlineStatus
        self.socialLinks = socialLinks
        self.followerCount = followerCount ?? subscriberCount
        self.followingCount = followingCount
        self.joinDate = joinDate ?? createdAt
        self.totalViews = totalViews
        self.totalEarnings = totalEarnings
        self.membershipTiers = membershipTiers
        self.verificationBadge = verificationBadge
    }
    
    // MARK: - Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        bannerImageURL = try container.decodeIfPresent(String.self, forKey: .bannerImageURL)
        bannerVideoURL = try container.decodeIfPresent(String.self, forKey: .bannerVideoURL)
        bannerVideoMuted = try container.decodeIfPresent(Bool.self, forKey: .bannerVideoMuted)
        bannerVideoContentMode = try container.decodeIfPresent(UserBannerContentMode.self, forKey: .bannerVideoContentMode)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        subscriberCount = try container.decodeIfPresent(Int.self, forKey: .subscriberCount) ?? 0
        videoCount = try container.decodeIfPresent(Int.self, forKey: .videoCount) ?? 0
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isCreator = try container.decodeIfPresent(Bool.self, forKey: .isCreator) ?? false
        
        // Handle Date decoding
        if let timestamp = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }
        
        location = try container.decodeIfPresent(String.self, forKey: .location)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        showWebsiteOnProfile = try container.decodeIfPresent(Bool.self, forKey: .showWebsiteOnProfile)
        showOnlineStatus = try container.decodeIfPresent(Bool.self, forKey: .showOnlineStatus)
        socialLinks = try container.decodeIfPresent([SocialLink].self, forKey: .socialLinks) ?? []
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? subscriberCount
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        
        // Handle joinDate
        if let joinTimestamp = try? container.decode(Double.self, forKey: .joinDate) {
            joinDate = Date(timeIntervalSince1970: joinTimestamp)
        } else {
            joinDate = createdAt
        }
        
        totalViews = try container.decodeIfPresent(Int.self, forKey: .totalViews)
        totalEarnings = try container.decodeIfPresent(Double.self, forKey: .totalEarnings)
        membershipTiers = try container.decodeIfPresent([MembershipTier].self, forKey: .membershipTiers)
        verificationBadge = try container.decodeIfPresent(VerificationBadge.self, forKey: .verificationBadge)
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(bannerImageURL, forKey: .bannerImageURL)
        try container.encodeIfPresent(bannerVideoURL, forKey: .bannerVideoURL)
        try container.encodeIfPresent(bannerVideoMuted, forKey: .bannerVideoMuted)
        try container.encodeIfPresent(bannerVideoContentMode, forKey: .bannerVideoContentMode)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encode(subscriberCount, forKey: .subscriberCount)
        try container.encode(videoCount, forKey: .videoCount)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(isCreator, forKey: .isCreator)
        try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(showWebsiteOnProfile, forKey: .showWebsiteOnProfile)
        try container.encodeIfPresent(showOnlineStatus, forKey: .showOnlineStatus)
        try container.encode(socialLinks, forKey: .socialLinks)
        try container.encode(followerCount, forKey: .followerCount)
        try container.encode(followingCount, forKey: .followingCount)
        try container.encode(joinDate.timeIntervalSince1970, forKey: .joinDate)
        try container.encodeIfPresent(totalViews, forKey: .totalViews)
        try container.encodeIfPresent(totalEarnings, forKey: .totalEarnings)
        try container.encodeIfPresent(membershipTiers, forKey: .membershipTiers)
        try container.encodeIfPresent(verificationBadge, forKey: .verificationBadge)
    }
}

// MARK: - Banner Content Mode
enum UserBannerContentMode: String, Codable {
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
// MARK: - Verification & Owner Extensions
extension User {
    /// 🔥 YOUTUBE PARITY: Owner emails that should be automatically verified
    private static let ownerEmails: Set<String> = [
        "keontapeat@mychannel.live",
        "keontapeat@gmail.com"
    ]
    
    /// Check if this user is the owner
    var isOwner: Bool {
        Self.ownerEmails.contains(email.lowercased())
    }
    
    /// 🔥 YOUTUBE PARITY: Show verification badge if verified OR if owner
    var shouldShowVerificationBadge: Bool {
        isVerified || isOwner
    }
    
    /// Get effective verification status (verified OR owner)
    var effectiveIsVerified: Bool {
        isVerified || isOwner
    }
    
    /// Create an updated copy of the user with new values
    func updating(
        videoCount: Int? = nil,
        totalViews: Int? = nil,
        subscriberCount: Int? = nil,
        totalEarnings: Double? = nil
    ) -> User {
        User(
            id: self.id,
            username: self.username,
            displayName: self.displayName,
            email: self.email,
            profileImageURL: self.profileImageURL,
            bannerImageURL: self.bannerImageURL,
            bio: self.bio,
            subscriberCount: subscriberCount ?? self.subscriberCount,
            videoCount: videoCount ?? self.videoCount,
            isVerified: self.isVerified,
            isCreator: self.isCreator,
            createdAt: self.createdAt,
            location: self.location,
            website: self.website,
            showWebsiteOnProfile: self.showWebsiteOnProfile,
            showOnlineStatus: self.showOnlineStatus,
            socialLinks: self.socialLinks,
            followerCount: self.followerCount,
            followingCount: self.followingCount,
            joinDate: self.joinDate,
            totalViews: totalViews ?? self.totalViews,
            totalEarnings: totalEarnings ?? self.totalEarnings,
            membershipTiers: self.membershipTiers,
            verificationBadge: self.verificationBadge,
            bannerVideoURL: self.bannerVideoURL,
            bannerVideoMuted: self.bannerVideoMuted,
            bannerVideoContentMode: self.bannerVideoContentMode
        )
    }
    
    /// Get verification status from badge
    var verificationStatus: VerificationStatus {
        verificationBadge?.status ?? (isVerified ? .verified : .notEligible)
    }
    
    /// Create a copy with updated verification
    func replacingVerification(isVerified: Bool, badge: VerificationBadge) -> User {
        User(
            id: self.id,
            username: self.username,
            displayName: self.displayName,
            email: self.email,
            profileImageURL: self.profileImageURL,
            bannerImageURL: self.bannerImageURL,
            bio: self.bio,
            subscriberCount: self.subscriberCount,
            videoCount: self.videoCount,
            isVerified: isVerified,
            isCreator: self.isCreator,
            createdAt: self.createdAt,
            location: self.location,
            website: self.website,
            showWebsiteOnProfile: self.showWebsiteOnProfile,
            showOnlineStatus: self.showOnlineStatus,
            socialLinks: self.socialLinks,
            followerCount: self.followerCount,
            followingCount: self.followingCount,
            joinDate: self.joinDate,
            totalViews: self.totalViews,
            totalEarnings: self.totalEarnings,
            membershipTiers: self.membershipTiers,
            verificationBadge: badge,
            bannerVideoURL: self.bannerVideoURL,
            bannerVideoMuted: self.bannerVideoMuted,
            bannerVideoContentMode: self.bannerVideoContentMode
        )
    }
}

extension User {
    static let sampleUsers: [User] = [
        User(
            username: "techcreator",
            displayName: "Tech Creator",
            email: "tech@example.com",
            profileImageURL: "https://example.com/profile1.jpg",
            bio: "Creating amazing tech content for everyone!",
            subscriberCount: 125000,
            videoCount: 89,
            isVerified: true,
            isCreator: true,
            followerCount: 125000,
            followingCount: 250,
            totalViews: 2500000
        ),
        User(
            username: "gamer_pro",
            displayName: "Gaming Pro",
            email: "gamer@example.com",
            profileImageURL: "https://example.com/profile2.jpg",
            bio: "Professional gamer and content creator",
            subscriberCount: 89000,
            videoCount: 156,
            isVerified: true,
            isCreator: true,
            followerCount: 89000,
            followingCount: 180,
            totalViews: 1800000
        ),
        User(
            username: "lifestyle_vlogger",
            displayName: "Lifestyle Vlogger",
            email: "lifestyle@example.com",
            profileImageURL: "https://example.com/profile3.jpg",
            bio: "Sharing my daily life and adventures",
            subscriberCount: 67000,
            videoCount: 234,
            isVerified: false,
            isCreator: true,
            followerCount: 67000,
            followingCount: 320,
            totalViews: 1200000
        ),
        User(
            username: "music_artist",
            displayName: "Music Artist",
            email: "music@example.com",
            profileImageURL: "https://example.com/profile4.jpg",
            bio: "Independent musician sharing original content",
            subscriberCount: 45000,
            videoCount: 78,
            isVerified: false,
            isCreator: true,
            followerCount: 45000,
            followingCount: 150,
            totalViews: 900000
        ),
        User(
            username: "regular_user",
            displayName: "Regular User",
            email: "user@example.com",
            subscriberCount: 0,
            videoCount: 0,
            isVerified: false,
            isCreator: false,
            followerCount: 25,
            followingCount: 100
        )
    ]
    
    static let defaultUser = User(
        username: "defaultuser",
        displayName: "Default User",
        email: "default@mychannel.com"
    )
}

#Preview("User Model Preview") {
    VStack(spacing: 20) {
        Text("User Models")
            .font(AppTheme.Typography.largeTitle)
        
        ForEach(Array(User.sampleUsers.prefix(2)), id: \.id) { user in
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







