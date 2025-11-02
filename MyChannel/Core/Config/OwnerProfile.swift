import Foundation

struct OwnerProfile {
    static let owner: User = User(
        id: "owner_sbkeonta",
        username: "sbkeonta_",
        displayName: "sbkeonta_",
        email: "owner@mychannel.app"
    )

    // Optional friend list to surface in Top Artists (e.g., IG handles)
    // All friends added back to Top Artists section, including those without profile images
    // Friends without avatars will use default placeholder
    static let instagramFriends: [FriendArtist] = [
        // Friends with local assets (will use asset avatars)
        FriendArtist(name: "HTG Nook", instagram: "@htg.nook", avatar: "asset://HTGNookAvatar"),
        FriendArtist(name: "Scatz Ripky", instagram: "@scatzripky6", avatar: "asset://ScatzAvatar"),
        FriendArtist(name: "Kleanup Man", instagram: "@kleanupman__", avatar: "asset://KleanupManAvatar"),
        FriendArtist(name: "Luh Monti", instagram: "@luh_monti45", avatar: "asset://LuhMontiAvatar"),
        FriendArtist(name: "Six Ward Von", instagram: "@sixwardvon_", avatar: "asset://SixWardVonAvatar"),
        FriendArtist(name: "Barth Baby", instagram: "@barthfrmda6ix", avatar: "asset://BarthBabyAvatar"),
        
        // Friends without profile images (will use default avatar placeholder)
        FriendArtist(name: "YSR Loski Brim", instagram: "@ysr.loskibrim", avatar: "https://i.pravatar.cc/200?u=ysr.loskibrim"),
        FriendArtist(name: "Way P", instagram: "@official.wayp", avatar: "https://i.pravatar.cc/200?u=official.wayp"),
        FriendArtist(name: "YN Jay", instagram: "@ynjay_", avatar: "https://i.pravatar.cc/200?u=ynjay"),
        FriendArtist(name: "RMC Mike", instagram: "@rmc__mike", avatar: "https://i.pravatar.cc/200?u=rmc.mike"),
        FriendArtist(name: "Babyface Rio", instagram: "@babyfxce.e", avatar: "https://i.pravatar.cc/200?u=babyfxce"),
        FriendArtist(name: "Rio Da Yung OG", instagram: "@riodayung0g", avatar: "https://i.pravatar.cc/200?u=riodayung")
    ]
}

struct FriendArtist: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let instagram: String
    let avatar: String
}