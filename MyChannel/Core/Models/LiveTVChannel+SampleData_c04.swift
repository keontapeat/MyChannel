import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 4
    static let _ltv04: [LiveTVChannel] = [
        LiveTVChannel(
            id: "james-bond",
            name: "James Bond 007",
            logoURL: "https://i.ytimg.com/vi/BIhNsAtPbPI/hqdefault.jpg",
            streamURL: s_movie2,
            category: .movies,
            description: "Bond. James Bond. 24/7 🔫🍸",
            isLive: true,
            viewerCount: 923456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "fast-furious",
            name: "Fast & Furious",
            logoURL: "https://i.ytimg.com/vi/aSiDu3Ywi8E/hqdefault.jpg",
            streamURL: s_movie2,
            category: .movies,
            description: "FAMILY! 24/7 🚗💨",
            isLive: true,
            viewerCount: 956789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "cops",
            name: "Cops",
            logoURL: "https://i.ytimg.com/vi/J6klPWDavvU/hqdefault.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "Bad boys bad boys! 24/7 🚔",
            isLive: true,
            viewerCount: 789012,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "ridiculousness",
            name: "Ridiculousness",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video60/v4/3f/6c/1d/3f6c1d99-4137-b66d-a35f-d40fa5d60ffe/mzl.smusveuq.lsr/600x600bb.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "Rob Dyrdek! 24/7 😂📱",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🏀 SPORTS HEAT
        LiveTVChannel(
            id: "nba-tv",
            name: "NBA TV",
            logoURL: "https://i.ytimg.com/vi/VQpr5FHoGGY/hqdefault.jpg", // NBA Best Plays
            streamURL: s_sports1,
            category: .sports,
            description: "Basketball 24/7 🏀🔥",
            isLive: true,
            viewerCount: 945678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "espn-classic",
            name: "ESPN Classic",
            logoURL: "https://i.ytimg.com/vi/3LEeiRb-49M/hqdefault.jpg", // ESPN SportsCenter Classic
            streamURL: s_sports1,
            category: .sports,
            description: "Legendary games 24/7 🏆",
            isLive: true,
            viewerCount: 823456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🦸‍♂️ TEEN TITANS GO! 🦸‍♂️
        LiveTVChannel(
            id: "teen-titans-2",
            name: "Teen Titans Go!",
            logoURL: "https://i.ytimg.com/vi/l0vuBG3EDqg/hqdefault.jpg", // Teen Titans Go HBO Max
            streamURL: s_kids2,
            category: .kids,
            description: "Titans GO! 24/7 🦸‍♂️💥",
            isLive: true,
            viewerCount: 823456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🚀 SCI-FI - Legendary shows
        LiveTVChannel(
            id: "star-trek",
            name: "Star Trek",
            logoURL: "https://i.ytimg.com/vi/hfSu24kzwp4/hqdefault.jpg",
            streamURL: s_scifi1,
            category: .scifi,
            description: "Live long and prosper! 24/7 Star Trek",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "stargate",
            name: "Stargate",
            logoURL: "https://i.ytimg.com/vi/ZuNLaM4q4qU/hqdefault.jpg",
            streamURL: s_scifi1,
            category: .scifi,
            description: "Gate travel 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "doctor-who",
            name: "Doctor Who Classic",
            logoURL: "https://i.ytimg.com/vi/fVQyYJ8Rl7o/hqdefault.jpg",
            streamURL: s_scifi1,
            category: .scifi,
            description: "Allons-y! Classic Doctor Who 24/7",
            isLive: true,
            viewerCount: 389450,
            quality: "1080p",
            language: "English",
            country: "UK",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🔥 REALITY BANGERS
        LiveTVChannel(
            id: "hells-kitchen",
            name: "Hell's Kitchen",
            logoURL: "https://i.ytimg.com/vi/YD_DNzjhPGE/hqdefault.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "IT'S RAW! Gordon Ramsay 24/7",
            isLive: true,
            viewerCount: 678900,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "survivor",
            name: "Survivor",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Features/c0/45/a2/dj.ccllwbph.jpg/600x600bb.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "Outwit. Outplay. Outlast. 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "amazing-race",
            name: "The Amazing Race",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video1/v4/be/8f/a4/be8fa42f-1336-dd12-ad5e-f34fa8f85e16/mzl.inpojjko.lsr/600x600bb.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "Race around the world 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "ink-master",
            name: "Ink Master",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video118/v4/6d/9a/05/6d9a05ad-bf72-3704-9931-b4fec0cc08d7/mzl.kexftmij.lsr/600x600bb.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "Tattoo competition 24/7",
            isLive: true,
            viewerCount: 389450,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "big-brother",
            name: "Big Brother",
            logoURL: "https://i.ytimg.com/vi/kkFFPyLLq9g/hqdefault.jpg",
            streamURL: s_reality1,
            category: .reality,
            description: "Expect the unexpected 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 😂 COMEDY GOLD
        LiveTVChannel(
            id: "wild-n-out",
            name: "Wild 'N Out",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Features/31/79/12/dj.rrwkdjsc.jpg/600x600bb.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "Nick Cannon's Wild 'N Out 24/7",
            isLive: true,
            viewerCount: 678900,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "tosh",
            name: "Tosh.0",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/2b/d7/ec/2bd7ecfb-d07b-4053-e38a-b5eb3bbe1a91/mza_6674222021050700152.jpg/600x600bb.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "Daniel Tosh comedy 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "comedy-central",
            name: "Comedy Central",
            logoURL: "https://i.ytimg.com/vi/FDV_Nqb1BCA/hqdefault.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "Stand-up and sketch comedy 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "tv-land-sitcoms",
            name: "TV Land Sitcoms",
            logoURL: "https://i.ytimg.com/vi/6b0ftfKFEJg/hqdefault.jpg",
            streamURL: s_classic1,
            category: .comedy,
            description: "Classic sitcoms 24/7",
            isLive: true,
            viewerCount: 345670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
    ]
    
    // ============================================
    // 👶 KIDS CHANNELS - VERIFIED WORKING ✅
    // ============================================
    static let kidsChannels: [LiveTVChannel] = [
        
        LiveTVChannel(
            id: "nickelodeon",
            name: "Nickelodeon",
            logoURL: "https://i.ytimg.com/vi/Df0sHiPa_xc/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "Classic Nick shows 24/7",
            isLive: true,
            viewerCount: 789650,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
    ]
}
