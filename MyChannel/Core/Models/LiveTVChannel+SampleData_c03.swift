import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 3
    static let _ltv03: [LiveTVChannel] = [
        LiveTVChannel(
            id: "demon-slayer",
            name: "Demon Slayer",
            logoURL: "https://i.ytimg.com/vi/TcuxuwtIhtY/hqdefault.jpg", // Demon Slayer Hashira Training
            streamURL: s_kids2,
            category: .anime,
            description: "Hinokami Kagura! 24/7 🔥⚔️",
            isLive: true,
            viewerCount: 989876,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "jujutsu-kaisen",
            name: "Jujutsu Kaisen",
            logoURL: "https://i.ytimg.com/vi/pkKu9hLT-t8/hqdefault.jpg", // JJK opening
            streamURL: s_kids2,
            category: .anime,
            description: "Domain Expansion! 24/7 👹",
            isLive: true,
            viewerCount: 998765,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🔥🔥🔥 BLACK EXCELLENCE TV - THE CLASSICS 🔥🔥🔥
        LiveTVChannel(
            id: "martin",
            name: "Martin",
            logoURL: "https://i.ytimg.com/vi/I8xwjH_Y8ms/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "GINA! You so crazy! 24/7 😂🔥",
            isLive: true,
            viewerCount: 945678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "fresh-prince",
            name: "The Fresh Prince of Bel-Air",
            logoURL: "https://i.ytimg.com/vi/ghMFFe2Q9hA/hqdefault.jpg", // Fresh Prince Reunion
            streamURL: s_entertain1,
            category: .comedy,
            description: "In West Philadelphia born and raised! 24/7 👑",
            isLive: true,
            viewerCount: 978654,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "everybody-hates-chris",
            name: "Everybody Hates Chris",
            logoURL: "https://i.ytimg.com/vi/zZHvnqZlfbo/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "Chris Rock narrates! 24/7 😂",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "bernie-mac",
            name: "The Bernie Mac Show",
            logoURL: "https://i.ytimg.com/vi/ePb05qGF7ps/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "America! 24/7 🇺🇸😂",
            isLive: true,
            viewerCount: 823456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "my-wife-kids",
            name: "My Wife and Kids",
            logoURL: "https://i.ytimg.com/vi/VqakNNyVk-g/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "Damon Wayans classic! 24/7 👨‍👩‍👧‍👦",
            isLive: true,
            viewerCount: 789012,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "wayans-bros",
            name: "The Wayans Bros.",
            logoURL: "https://i.ytimg.com/vi/kUJcPME1T5o/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "Shawn & Marlon! 24/7 😂",
            isLive: true,
            viewerCount: 756789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "in-living-color",
            name: "In Living Color",
            logoURL: "https://i.ytimg.com/vi/WLVzwUP22rA/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .comedy,
            description: "Where legends started! 24/7 🌈🔥",
            isLive: true,
            viewerCount: 834567,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "chappelle",
            name: "Chappelle's Show",
            logoURL: "https://i.ytimg.com/vi/JNN7OCrSpbw/hqdefault.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "I'm Rick James! 24/7 😂🔥",
            isLive: true,
            viewerCount: 956789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "key-peele",
            name: "Key & Peele",
            logoURL: "https://i.ytimg.com/vi/Dd7FixvoKBw/hqdefault.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "A-A-RON! 24/7 😂",
            isLive: true,
            viewerCount: 912345,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🎤 MUSIC CHANNELS - THE VIBES 🎤
        LiveTVChannel(
            id: "bet-jams",
            name: "BET Jams",
            logoURL: "https://i.ytimg.com/vi/JYdoJcV25f0/hqdefault.jpg",
            streamURL: s_vevo_hip,
            category: .music,
            description: "Hip-hop hits 24/7 🎤🔥",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "bet-soul",
            name: "BET Soul",
            logoURL: "https://i.ytimg.com/vi/3AtDnEC4zak/hqdefault.jpg",
            streamURL: s_music1,
            category: .music,
            description: "R&B classics 24/7 🎵❤️",
            isLive: true,
            viewerCount: 789012,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "mtv-hits",
            name: "MTV Hits",
            logoURL: "https://i.ytimg.com/vi/X9fLbfzCqWw/hqdefault.jpg",
            streamURL: s_vevo_pop,
            category: .music,
            description: "2000s bangers 24/7 📀🔥",
            isLive: true,
            viewerCount: 845678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "vh1",
            name: "VH1 Pluto TV",
            logoURL: "https://i.ytimg.com/vi/lJqbaGloVxg/hqdefault.jpg",
            streamURL: s_music1,
            category: .music,
            description: "Classic music TV 24/7 📺🎵",
            isLive: true,
            viewerCount: 756789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 📺 MORE CARTOON NETWORK HEAT
        LiveTVChannel(
            id: "regular-show",
            name: "Regular Show",
            logoURL: "https://i.ytimg.com/vi/y894QNtX0VA/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "OOOOOH! 24/7 🐦🦝",
            isLive: true,
            viewerCount: 823456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "adventure-time",
            name: "Adventure Time",
            logoURL: "https://i.ytimg.com/vi/LhQizg-KDXM/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Mathematical! 24/7 🗡️🐕",
            isLive: true,
            viewerCount: 912345,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "gumball",
            name: "The Amazing World of Gumball",
            logoURL: "https://i.ytimg.com/vi/MrKbsv4OXQA/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Amazing chaos! 24/7 🐱🐟",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "clarence",
            name: "Clarence",
            logoURL: "https://i.ytimg.com/vi/mTm8sK52q0U/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Underrated gem! 24/7 👦",
            isLive: true,
            viewerCount: 654321,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "steven-universe",
            name: "Steven Universe",
            logoURL: "https://i.ytimg.com/vi/eY52Zsg-KVI/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "The feels! 24/7 💎✨",
            isLive: true,
            viewerCount: 845678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🎬 ACTION & MOVIES
    ]
}
