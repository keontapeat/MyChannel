import Foundation

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

    // Optional friend list to surface in Top Artists (e.g., IG handles)
    static let instagramFriends: [FriendArtist] = [
        // Prioritized order; first item appears as #1
        FriendArtist(name: "@ysr.loskibrim", instagram: "@ysr.loskibrim", avatar: "asset://YSRLoskiBrim"),
        FriendArtist(name: "@scatzripky6", instagram: "@scatzripky6", avatar: "https://unavatar.io/instagram/scatzripky6"),
        FriendArtist(name: "@kleanupman__", instagram: "@kleanupman__", avatar: "https://unavatar.io/instagram/kleanupman__"),
        FriendArtist(name: "@ynjay_", instagram: "@ynjay_", avatar: "https://unavatar.io/instagram/ynjay_"),
        FriendArtist(name: "@luh_monti45", instagram: "@luh_monti45", avatar: "https://unavatar.io/instagram/luh_monti45"),
        FriendArtist(name: "@ysr.loski", instagram: "@ysr.loski", avatar: "https://unavatar.io/instagram/ysr.loski"),
        FriendArtist(name: "@babyfxce.e", instagram: "@babyfxce.e", avatar: "https://unavatar.io/instagram/babyfxce.e"),
        FriendArtist(name: "@sixwardvon_", instagram: "@sixwardvon_", avatar: "https://unavatar.io/instagram/sixwardvon_"),
        FriendArtist(name: "@riodayung0g", instagram: "@riodayung0g", avatar: "https://unavatar.io/instagram/riodayung0g"),
        FriendArtist(name: "@rmc__mike", instagram: "@rmc__mike", avatar: "https://unavatar.io/instagram/rmc__mike"),
        FriendArtist(name: "@htg.nook", instagram: "@htg.nook", avatar: "https://unavatar.io/instagram/htg.nook"),
        FriendArtist(name: "@barthfrmda6ix", instagram: "@barthfrmda6ix", avatar: "https://unavatar.io/instagram/barthfrmda6ix")
    ]
}

struct FriendArtist: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let instagram: String
    let avatar: String
}