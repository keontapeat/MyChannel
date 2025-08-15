import Foundation

struct OwnerProfile {
    static let owner: User = {
        User(
            id: "owner_sbkeonta",
            username: "sbkeonta_",
            displayName: "sbkeonta_",
            email: "owner@mychannel.app",
            profileImageURL: "https://i.pravatar.cc/200?u=sbkeonta_",
            bannerImageURL: nil,
            bio: """
Cinematographer
Shot By Keonta
Flint, MI Videographer
shotbykeonta.store
""",
            subscriberCount: 2230,
            videoCount: 336,
            isVerified: true,
            isCreator: true,
            location: "Flint, MI",
            website: "https://shotbykeonta.store",
            socialLinks: [
                SocialLink(platform: .instagram, url: "https://www.instagram.com/sbkeonta_/", displayName: "@sbkeonta_"),
                SocialLink(platform: .website, url: "https://shotbykeonta.store", displayName: "shotbykeonta.store")
            ],
            totalViews: 1_000_000,
            bannerVideoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            bannerVideoMuted: true,
            bannerVideoContentMode: .fill
        )
    }()
}