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
        // Artwork from a Hotboy Curry–led release (not a collab where another artist is primary, e.g. Ysr Gramz).
        FeaturedFriendArtist(
            appleMusicId: 1771099410,
            name: "Hotboy Curry",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/03/2e/94/032e947a-77aa-e7ac-b9d6-68ac0936dae5/artwork.jpg/1000x1000bb.jpg",
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
        // https://music.apple.com/us/artist/luh-monti/1656612386
        FeaturedFriendArtist(
            appleMusicId: 1656612386,
            name: "Luh Monti",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/de/e4/d6/dee4d6a0-ab09-f005-bff7-89f3af18d015/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
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
        // https://music.apple.com/us/artist/3200-tre/1491631657
        FeaturedFriendArtist(
            appleMusicId: 1491631657,
            name: "3200 Tre",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/80/e3/f9/80e3f97a-8b05-5be4-00d8-1c213b8006b4/198309462473.png/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "40K",
            monthlyListeners: "30K",
            playCount: "700K"
        ),
        
        // 10. Ktrip — Apple Music ID: 1484873437
        // https://music.apple.com/us/artist/ktrip/1484873437
        FeaturedFriendArtist(
            appleMusicId: 1484873437,
            name: "Ktrip",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/a2/75/3c/a2753c0f-ac18-a4a9-c5b7-52d8517fc825/artwork.jpg/1000x1000bb.jpg",
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
        
        // 12. Babii MOE — Apple Music ID: 1507109510
        // https://music.apple.com/us/artist/babii-moe/1507109510
        FeaturedFriendArtist(
            appleMusicId: 1507109510,
            name: "Babii MOE",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/84/ae/b5/84aeb508-43fb-ddbd-c339-eef52d4f014d/artwork.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "28K",
            monthlyListeners: "22K",
            playCount: "800K"
        ),
        
        // 13. Ftos Twan — Apple Music ID: 1527300992
        // https://music.apple.com/us/artist/ftos-twan/1527300992
        FeaturedFriendArtist(
            appleMusicId: 1527300992,
            name: "Ftos Twan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/be/0d/df/be0ddf50-b7d8-e222-d983-dee26af60055/artwork.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "30K",
            monthlyListeners: "20K",
            playCount: "500K"
        ),
        
        // 14. Scatz — Apple Music ID: 904008025
        // https://music.apple.com/us/artist/scatz/904008025
        FeaturedFriendArtist(
            appleMusicId: 904008025,
            name: "Scatz",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/d6/5a/c8/d65ac829-bbbb-637c-825b-4ac71c76cb31/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "25K",
            monthlyListeners: "18K",
            playCount: "400K"
        ),
        
        // 15. Baby Ghost — Apple Music ID: 1507813989
        // https://music.apple.com/us/artist/baby-ghost/1507813989
        FeaturedFriendArtist(
            appleMusicId: 1507813989,
            name: "Baby Ghost",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ca/f7/e2/caf7e2d8-8f2c-30e7-64ff-d6cc60f05a11/725336485153_cover.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "35K",
            monthlyListeners: "25K",
            playCount: "600K"
        ),
        
        // 16. Way P — Apple Music ID: 1524383650
        FeaturedFriendArtist(
            appleMusicId: 1524383650,
            name: "Way P",
            profileImageURL: "",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "8K",
            monthlyListeners: "5K",
            playCount: "100K"
        ),
        
        // 17. Clean Up Man — Apple Music ID: 1538452293
        // https://music.apple.com/us/artist/clean-up-man/1538452293
        FeaturedFriendArtist(
            appleMusicId: 1538452293,
            name: "Clean Up Man",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/57/00/f3/5700f331-2d06-7f5d-cb98-43970fd52874/14UMGIM00860.rgb.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "18K",
            monthlyListeners: "35K",
            playCount: "800K"
        ),
        
        // 18. Eightball Tank — Apple Music ID: 1492591865
        // https://music.apple.com/us/artist/eightball-tank/1492591865
        FeaturedFriendArtist(
            appleMusicId: 1492591865,
            name: "Eightball Tank",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/80/43/67/80436720-e95e-2df6-6722-e54c4b61c3ae/artwork.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "22K",
            monthlyListeners: "40K",
            playCount: "900K"
        ),
        
        // 19. Ysr Gramz — Apple Music ID: 1490787471
        // https://music.apple.com/us/artist/ysr-gramz/1490787471
        FeaturedFriendArtist(
            appleMusicId: 1490787471,
            name: "Ysr Gramz",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/ee/c6/50/eec65020-6fe8-1fb2-b013-45151a3358c5/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "75K",
            monthlyListeners: "60K",
            playCount: "1.5M"
        ),
        
        // 20. Six Ward Von — Apple Music ID: 1564317122
        // https://music.apple.com/us/artist/six-ward-von/1564317122
        FeaturedFriendArtist(
            appleMusicId: 1564317122,
            name: "Six Ward Von",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/ba/31/3a/ba313a57-7612-1c47-b561-94cac0c56825/artwork.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "28K",
            monthlyListeners: "45K",
            playCount: "1.1M"
        ),
        
        // 21. MIA Patman — Apple Music ID: 1548074075
        // https://music.apple.com/us/artist/mia-patman/1548074075
        FeaturedFriendArtist(
            appleMusicId: 1548074075,
            name: "MIA Patman",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/e0/7a/7d/e07a7d86-719e-5b9a-fbcc-dcc392cf58d9/artwork.jpg/1000x1000bb.jpg",
            location: "MIA, FL",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "20K",
            monthlyListeners: "38K",
            playCount: "950K"
        ),
        
        // 22. Lil Nook — Apple Music ID: 1763508797
        // https://music.apple.com/us/artist/lil-nook/1763508797
        FeaturedFriendArtist(
            appleMusicId: 1763508797,
            name: "Lil Nook",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/a3/ca/75/a3ca75b4-7328-8bf0-e8c3-995f79d4aa7e/artwork.jpg/1000x1000bb.jpg",
            location: "Michigan",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "12K",
            monthlyListeners: "28K",
            playCount: "400K"
        ),
        
        // 23. Jeff Skigh — Apple Music ID: 945119824
        // https://music.apple.com/us/artist/jeff-skigh/945119824
        FeaturedFriendArtist(
            appleMusicId: 945119824,
            name: "Jeff Skigh",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ef/55/de/ef55de9e-ccb4-9094-a656-39e114a7b3a8/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "18K",
            monthlyListeners: "32K",
            playCount: "750K"
        ),
        
        // 24. Homi Michel — Apple Music ID: 1514456557
        // https://music.apple.com/us/artist/homi-michel/1514456557
        FeaturedFriendArtist(
            appleMusicId: 1514456557,
            name: "Homi Michel",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/9e/06/21/9e0621d6-8252-fa1e-9018-d2373577f657/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "24K",
            monthlyListeners: "42K",
            playCount: "900K"
        ),
        
        // 25. KrispyLife Kidd — Apple Music ID: 1477569694
        // https://music.apple.com/us/artist/krispylife-kidd/1477569694
        FeaturedFriendArtist(
            appleMusicId: 1477569694,
            name: "KrispyLife Kidd",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/81/a7/ef/81a7ef94-25da-9023-5605-c4bc32228387/0.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "120K",
            monthlyListeners: "200K",
            playCount: "5M"
        ),
        
        // 26. BBDR Tay — Apple Music ID: 1501537814
        // https://music.apple.com/us/artist/bbdr-tay/1501537814
        FeaturedFriendArtist(
            appleMusicId: 1501537814,
            name: "BBDR Tay",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/46/4f/91/464f919a-1091-eb44-f450-5bbbb5b55b06/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "22K",
            monthlyListeners: "38K",
            playCount: "850K"
        ),
        
        // 27. PaidLife Zar — Apple Music ID: 1501538060
        // https://music.apple.com/us/artist/paidlife-zar/1501538060
        FeaturedFriendArtist(
            appleMusicId: 1501538060,
            name: "PaidLife Zar",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/a9/c3/b9/a9c3b97f-da2a-10fd-a6ab-1b0a9016d4fa/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "20K",
            monthlyListeners: "36K",
            playCount: "800K"
        ),
        
        // 28. Richvon23 — Apple Music ID: 1531986560
        // https://music.apple.com/us/artist/richvon23/1531986560
        FeaturedFriendArtist(
            appleMusicId: 1531986560,
            name: "Richvon23",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/4a/7d/a3/4a7da363-681c-53a6-9801-9adaa53f4598/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "16K",
            monthlyListeners: "30K",
            playCount: "650K"
        ),
        
        // 29. Geeoutto — Apple Music ID: 1583072463
        // https://music.apple.com/us/artist/geeoutto/1583072463
        FeaturedFriendArtist(
            appleMusicId: 1583072463,
            name: "Geeoutto",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/ce/f8/5d/cef85d09-00e9-fb80-5b50-87fd22a5b941/artwork.jpg/1000x1000bb.jpg",
            location: "MIA, FL",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "14K",
            monthlyListeners: "28K",
            playCount: "550K"
        ),
        
        // 30. Mia Curt — Apple Music ID: 1576989709
        // https://music.apple.com/us/artist/mia-curt/1576989709
        FeaturedFriendArtist(
            appleMusicId: 1576989709,
            name: "Mia Curt",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/28/80/85/28808507-e934-39ab-1efc-e9ad16559a61/artwork.jpg/1000x1000bb.jpg",
            location: "MIA, FL",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "12K",
            monthlyListeners: "24K",
            playCount: "480K"
        ),
        
        // 31. Dee Grant — Apple Music ID: 1488384274
        // https://music.apple.com/us/artist/dee-grant/1488384274
        FeaturedFriendArtist(
            appleMusicId: 1488384274,
            name: "Dee Grant",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/69/51/8f/69518f43-14af-7f5e-2230-196808e9c868/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "11K",
            monthlyListeners: "22K",
            playCount: "450K"
        ),
        
        // 32. FTM Bear — Apple Music ID: 1483982707
        // https://music.apple.com/us/artist/ftm-bear/1483982707
        FeaturedFriendArtist(
            appleMusicId: 1483982707,
            name: "FTM Bear",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/35/8d/c6/358dc694-9e74-4b24-ec76-7967673cc7bb/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "13K",
            monthlyListeners: "24K",
            playCount: "470K"
        ),
        
        // 33. Cliff Mac — Apple Music ID: 964080263
        // https://music.apple.com/us/artist/cliff-mac/964080263
        FeaturedFriendArtist(
            appleMusicId: 964080263,
            name: "Cliff Mac",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/62/9b/a5/629ba59a-6c8c-08f3-4a97-20854ecc77a0/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "10K",
            monthlyListeners: "20K",
            playCount: "420K"
        ),
        
        // 34. Obabe — Apple Music ID: 1496302013
        // https://music.apple.com/us/artist/obabe/1496302013
        FeaturedFriendArtist(
            appleMusicId: 1496302013,
            name: "Obabe",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d2/6e/07/d26e0757-1906-3e11-70da-1b582201aef3/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "9K",
            monthlyListeners: "19K",
            playCount: "400K"
        ),
        
        // 35. Velly Beretta — Apple Music ID: 1174001237
        // https://music.apple.com/us/artist/velly-beretta/1174001237
        FeaturedFriendArtist(
            appleMusicId: 1174001237,
            name: "Velly Beretta",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/19/4e/20/194e20d6-b961-bc15-6a24-9363e0c7ee5d/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "14K",
            monthlyListeners: "26K",
            playCount: "520K"
        ),
        
        // 36. King Cashes — Apple Music ID: 1498000463
        // https://music.apple.com/us/artist/king-cashes/1498000463
        FeaturedFriendArtist(
            appleMusicId: 1498000463,
            name: "King Cashes",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/43/10/ca/4310ca10-6cd5-cdfa-4c3d-aff43c8c6cc7/859715880588_cover.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "12K",
            monthlyListeners: "23K",
            playCount: "490K"
        ),
        
        // 37. Detwan Love — Apple Music ID: 1155696158
        // https://music.apple.com/us/artist/detwan-love/1155696158
        FeaturedFriendArtist(
            appleMusicId: 1155696158,
            name: "Detwan Love",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/56/58/29/56582969-77c9-a9b0-a3c5-ce9e9c21dc58/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "11K",
            monthlyListeners: "21K",
            playCount: "460K"
        ),
        
        // 38. Real JT — Apple Music ID: 1422427461
        // https://music.apple.com/us/artist/real-jt/1422427461
        FeaturedFriendArtist(
            appleMusicId: 1422427461,
            name: "Real JT",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/23/84/04/23840407-851e-09a6-cdd9-2384ccab0cc3/198861062401.png/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "10K",
            monthlyListeners: "20K",
            playCount: "440K"
        ),
        
        // 39. Lil Lik — Apple Music ID: 1725106609
        // https://music.apple.com/us/artist/lil-lik/1725106609
        FeaturedFriendArtist(
            appleMusicId: 1725106609,
            name: "Lil Lik",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/9a/a4/72/9aa472a8-524c-ed20-4482-ca8b1b5f0520/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "8K",
            monthlyListeners: "17K",
            playCount: "380K"
        ),
        
        // 40. Stickz — Apple Music ID: 1676978658
        // https://music.apple.com/us/artist/stickz/1676978658
        FeaturedFriendArtist(
            appleMusicId: 1676978658,
            name: "Stickz",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/de/37/d9/de37d99c-c87d-f6a3-3bf4-5f8cd7fc9edc/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "7K",
            monthlyListeners: "16K",
            playCount: "360K"
        ),
        
        // 41. MANNYKEA — Apple Music ID: 1828612897
        // https://music.apple.com/us/artist/mannykea/1828612897
        FeaturedFriendArtist(
            appleMusicId: 1828612897,
            name: "MANNYKEA",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/c6/75/3c/c6753cfc-52d5-b997-7798-bf57165c4f3b/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "6K",
            monthlyListeners: "15K",
            playCount: "340K"
        ),
        
        // 42. Ot Love — Apple Music ID: 1836358576
        // https://music.apple.com/us/artist/ot-love/1836358576
        FeaturedFriendArtist(
            appleMusicId: 1836358576,
            name: "Ot Love",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/87/be/f7/87bef762-24e7-2375-764c-65b92858489f/artwork.jpg/1000x1000bb.jpg",
            location: "Flint, MI",
            genres: ["Hip-Hop", "Michigan Rap"],
            followerCount: "5K",
            monthlyListeners: "14K",
            playCount: "320K"
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
