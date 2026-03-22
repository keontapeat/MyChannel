import Foundation

// MARK: - Featured Friend Artists
// These are your real friends/artists that show first in "Pinned Artists"
// Each maps to a real Apple Music artist ID so their music loads via iTunes API

struct FeaturedFriendArtist {
    let appleMusicId: Int
    let name: String
    let profileImageURL: String
    let location: String
    let genres: [String]
    let followerCount: String
    let monthlyListeners: String
    let playCount: String
    
    /// Convert to CatalogArtist for navigation
    var catalogArtist: CatalogArtist {
        let validImage = profileImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : profileImageURL
        return CatalogArtist(
            id: appleMusicId,
            name: name,
            linkUrl: "https://music.apple.com/us/artist/\(appleMusicId)",
            artworkUrl: validImage
        )
    }
}

// MARK: - Your Friends List

extension FeaturedFriendArtist {
    
    /// Featured friend artists — pinned slots on the Pinned Artists section
    static let friends: [FeaturedFriendArtist] = [
        // 1. MIA Ghost — Apple Music ID: 1582746406
        FeaturedFriendArtist(
            appleMusicId: 1582746406,
            name: "MIA Ghost",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/AMCArtistImages221/v4/6b/0a/73/6b0a73c2-3a2e-c498-b1db-4c36d1bc2267/ami-identity-5a0c0ad3d0e4bae91a58d2dca03d1da6-2025-02-12T01-03-52.773Z_cropped.png/1000x1000bb.jpg",
            location: "MIA, FL",
            genres: ["Hip-Hop", "Underground"],
            followerCount: "12.5K",
            monthlyListeners: "45K",
            playCount: "2.8M"
        ),
        
        // 2. Lil Donny — Apple Music ID: 1857859662
        FeaturedFriendArtist(
            appleMusicId: 1857859662,
            name: "Lil Donny",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/eb/7e/e4/eb7ee452-1528-befb-ca06-d116d62fb761/199976204823-copy-953b0c18.png/600x600bb.jpg",
            location: "Hip-Hop",
            genres: ["Hip-Hop", "Rap"],
            followerCount: "3.2K",
            monthlyListeners: "15K",
            playCount: "420K"
        ),
        
        // 3. Mia Getem — Apple Music ID: 1798000837
        FeaturedFriendArtist(
            appleMusicId: 1798000837,
            name: "Mia Getem",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/AMCArtistImages211/v4/ab/0b/1f/ab0b1f47-1249-1e9e-7b50-1f8bda964af2/ami-identity.png/1000x1000bb.jpg",
            location: "Hip-Hop",
            genres: ["Hip-Hop", "Rap"],
            followerCount: "1.5K",
            monthlyListeners: "8K",
            playCount: "150K"
        ),
        
        // 4. Bk BabyDumpper — Apple Music ID: 1709296525
        FeaturedFriendArtist(
            appleMusicId: 1709296525,
            name: "Bk BabyDumpper",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "12K",
            monthlyListeners: "8K",
            playCount: "100K"
        ),
        
        // 5. Hotboy Curry — Apple Music ID: 1771099410
        FeaturedFriendArtist(
            appleMusicId: 1771099410,
            name: "Hotboy Curry",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "35K",
            monthlyListeners: "25K",
            playCount: "600K"
        ),
        
        // 6. Ysr Loski — Apple Music ID: 1511351716
        FeaturedFriendArtist(
            appleMusicId: 1511351716,
            name: "Ysr Loski",
            profileImageURL: "",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "30K",
            monthlyListeners: "20K",
            playCount: "500K"
        ),
        
        // 7. Luh Monti — Apple Music ID: 1656612386
        FeaturedFriendArtist(
            appleMusicId: 1656612386,
            name: "Luh Monti",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "25K",
            monthlyListeners: "18K",
            playCount: "400K"
        ),
        
        // 8. Babyfxce E — Apple Music ID: 1573432856
        FeaturedFriendArtist(
            appleMusicId: 1573432856,
            name: "Babyfxce E",
            profileImageURL: "",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "100K",
            monthlyListeners: "80K",
            playCount: "2M"
        ),
        
        // 9. 3200 Tre — Apple Music ID: 1491631657
        FeaturedFriendArtist(
            appleMusicId: 1491631657,
            name: "3200 Tre",
            profileImageURL: "",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "40K",
            monthlyListeners: "30K",
            playCount: "700K"
        ),
        
        // 10. Ktrip — Apple Music ID: 1484873437
        FeaturedFriendArtist(
            appleMusicId: 1484873437,
            name: "Ktrip",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "15K",
            monthlyListeners: "10K",
            playCount: "200K"
        ),
        
        // 11. Baby Ju — Apple Music ID: 1649723396
        FeaturedFriendArtist(
            appleMusicId: 1649723396,
            name: "Baby Ju",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "12K",
            monthlyListeners: "8K",
            playCount: "150K"
        ),
        
        // 12. Ftos Twan — Apple Music ID: 1527300992
        FeaturedFriendArtist(
            appleMusicId: 1527300992,
            name: "Ftos Twan",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "30K",
            monthlyListeners: "20K",
            playCount: "500K"
        ),
        
        // 13. Scatz — Apple Music ID: 904008025
        FeaturedFriendArtist(
            appleMusicId: 904008025,
            name: "Scatz",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "25K",
            monthlyListeners: "18K",
            playCount: "400K"
        ),
        
        // 14. Baby Ghost — Apple Music ID: 1507813989
        FeaturedFriendArtist(
            appleMusicId: 1507813989,
            name: "Baby Ghost",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "35K",
            monthlyListeners: "25K",
            playCount: "600K"
        ),
        
        // 15. Way P — Apple Music ID: 1524383650
        FeaturedFriendArtist(
            appleMusicId: 1524383650,
            name: "Way P",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "8K",
            monthlyListeners: "5K",
            playCount: "100K"
        )
    ]
    
    /// MIA Ghost albums to feature in the Albums section
    static let miaGhostAlbums: [String] = [
        "Be Foreal MIA Ghost",
        "MIA Ghost",
        "MIA Ghost EP",
        "MIA Ghost mixtape"
    ]
}
