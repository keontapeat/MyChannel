import Foundation

#if DEBUG
struct OwnerProfile {
    static let owner: User = {
        User(
            id: "owner_sbkeonta",
            username: "sbkeonta_",
            displayName: "sbkeonta_",
            email: "owner@mychannel.app",
            profileImageURL: nil,
            bannerImageURL: nil,
            bio: "",
            subscriberCount: 0,
            videoCount: 0,
            isVerified: true,
            isCreator: true,
            location: nil,
            website: nil,
            socialLinks: [],
            totalViews: nil,
            bannerVideoURL: nil,
            bannerVideoMuted: true,
            bannerVideoContentMode: .fill
        )
    }()
}
#endif