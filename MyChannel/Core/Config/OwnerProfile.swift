import Foundation

struct OwnerProfile {
    static let owner: User = User(
        id: "owner_sbkeonta",
        username: "sbkeonta_",
        displayName: "sbkeonta_",
        email: "owner@mychannel.app"
    )

    // Optional friend list to surface in Top Artists (e.g., IG handles)
    // Only friends with actual local assets (profile images)
    static let instagramFriends: [FriendArtist] = [
        // Friends with local assets (will use asset avatars)
        FriendArtist(name: "HTG Nook", instagram: "@htg.nook", avatar: "asset://HTGNookAvatar"),
        FriendArtist(name: "Scatz Ripky", instagram: "@scatzripky6", avatar: "asset://ScatzAvatar"),
        FriendArtist(name: "Kleanup Man", instagram: "@kleanupman__", avatar: "asset://KleanupManAvatar"),
        FriendArtist(name: "Luh Monti", instagram: "@luh_monti45", avatar: "asset://LuhMontiAvatar"),
        FriendArtist(name: "Six Ward Von", instagram: "@sixwardvon_", avatar: "asset://SixWardVonAvatar"),
        FriendArtist(name: "Barth Baby", instagram: "@barthfrmda6ix", avatar: "asset://BarthBabyAvatar")
    ]
}

struct FriendArtist: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let instagram: String
    let avatar: String
}