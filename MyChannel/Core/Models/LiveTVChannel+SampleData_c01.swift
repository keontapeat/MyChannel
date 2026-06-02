import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 1
    static let _ltv01: [LiveTVChannel] = [
        LiveTVChannel(
            id: "naruto",
            name: "Naruto",
            logoURL: "https://i.ytimg.com/vi/ZnL6hjwcRqQ/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "Believe it! 24/7 Naruto episodes",
            isLive: true,
            viewerCount: 892340,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "one-piece",
            name: "One Piece",
            logoURL: "https://i.ytimg.com/vi/S8_YwFLCh4U/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "Set sail with Luffy! 24/7 One Piece",
            isLive: true,
            viewerCount: 756890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "crunchyroll",
            name: "Crunchyroll",
            logoURL: "https://i.ytimg.com/vi/wVRn1_5uO90/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "The best anime streaming 24/7",
            isLive: true,
            viewerCount: 987650,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "pokemon",
            name: "Pokémon",
            logoURL: "https://i.ytimg.com/vi/yJ2oq33xE_M/hqdefault.jpg",
            streamURL: s_kids1,
            category: .anime,
            description: "Gotta catch 'em all! 24/7 Pokémon",
            isLive: true,
            viewerCount: 678900,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "yugioh",
            name: "Yu-Gi-Oh!",
            logoURL: "https://i.ytimg.com/vi/nubcZ4BDj4o/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "It's time to duel! 24/7",
            isLive: true,
            viewerCount: 534670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "sailor-moon",
            name: "Sailor Moon",
            logoURL: "https://i.ytimg.com/vi/8DQN3vngAEs/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "In the name of the moon! 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        // 🐉🔥 DRAGON BALL Z - THE GOAT 🔥🐉
        LiveTVChannel(
            id: "dragon-ball-z",
            name: "Dragon Ball Z",
            logoURL: "https://i.ytimg.com/vi/TZuJLX5sK14/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "IT'S OVER 9000! 24/7 DBZ 🐉",
            isLive: true,
            viewerCount: 999999,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: s_mux
        ),
        
        LiveTVChannel(
            id: "dragon-ball-super",
            name: "Dragon Ball Super",
            logoURL: "https://i.ytimg.com/vi/6_fXQSobiHs/hqdefault.jpg", // DBS Super Hero Launch
            streamURL: s_kids2,
            category: .anime,
            description: "Ultra Instinct vibes 24/7 ⚡",
            isLive: true,
            viewerCount: 876543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🔥😤 ADULT ANIMATION GOATS 😤🔥
        LiveTVChannel(
            id: "family-guy",
            name: "Family Guy",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video1/v4/6f/62/80/6f62804d-4e16-5948-cbf9-52174b700f45/mzl.kixbbnqo.lsr/600x600bb.jpg", // Family Guy Funniest Moments - 50M+ views
            streamURL: s_entertain2,
            category: .comedy,
            description: "Giggity giggity! 24/7 Family Guy 😂",
            isLive: true,
            viewerCount: 945678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "boondocks",
            name: "The Boondocks",
            logoURL: "https://i.ytimg.com/vi/g37HT4-EtzE/hqdefault.jpg", // Boondocks Best Moments - 10M+ views
            streamURL: s_entertain2,
            category: .comedy,
            description: "Huey & Riley 24/7 🔥😤",
            isLive: true,
            viewerCount: 888888,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "futurama",
            name: "Futurama",
            logoURL: "https://i.ytimg.com/vi/mYvLWHohOlY/hqdefault.jpg", // Futurama Best Moments - 20M+ views
            streamURL: s_entertain2,
            category: .comedy,
            description: "Good news everyone! 24/7 🚀",
            isLive: true,
            viewerCount: 867530,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "robot-chicken",
            name: "Robot Chicken",
            logoURL: "https://i.ytimg.com/vi/opgGQB5AjgU/hqdefault.jpg", // Robot Chicken 2025 Trailer
            streamURL: s_entertain2,
            category: .comedy,
            description: "Stop-motion chaos 24/7 🐔🤖",
            isLive: true,
            viewerCount: 756432,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🦸‍♂️ CARTOON NETWORK CLASSICS 🔥😤
        LiveTVChannel(
            id: "teen-titans",
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
        
        LiveTVChannel(
            id: "courage",
            name: "Courage the Cowardly Dog",
            logoURL: "https://i.ytimg.com/vi/5_sgrl1Xwpw/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "STUPID DOG! 24/7 🐕😱",
            isLive: true,
            viewerCount: 789012,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "scooby-doo",
            name: "Scooby-Doo",
            logoURL: "https://i.ytimg.com/vi/zKWW1LuPylc/hqdefault.jpg", // Scoob! 2020 Trailer
            streamURL: s_kids2,
            category: .kids,
            description: "Scooby-Dooby-Doo! 24/7 🐕🔍",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🤼 WWE - LET'S GOOOO 🤼
        LiveTVChannel(
            id: "wwe",
            name: "WWE",
            logoURL: "https://i.ytimg.com/vi/SsEvqFgqivk/hqdefault.jpg", // WWE 2K24 Official
            streamURL: s_sports1,
            category: .sports,
            description: "AND HIS NAME IS JOHN CENA! 24/7 🤼💪",
            isLive: true,
            viewerCount: 934567,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🔥🔥🔥 NUCLEAR ADDITIONS - ALL THE BANGERS 🔥🔥🔥
        
        // 📺 ADULT SWIM GOATS
        LiveTVChannel(
            id: "american-dad",
            name: "American Dad",
            logoURL: "https://i.ytimg.com/vi/d0EROb04hn8/hqdefault.jpg", // American Dad Movie Trailer
            streamURL: s_entertain2,
            category: .comedy,
            description: "Good morning USA! 24/7 🇺🇸",
            isLive: true,
            viewerCount: 834567,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "south-park",
            name: "South Park",
            logoURL: "https://i.ytimg.com/vi/B3Mj8Ht0g8M/hqdefault.jpg", // South Park Snow Day 2024
            streamURL: s_entertain2,
            category: .comedy,
            description: "Oh my God, they killed Kenny! 24/7",
            isLive: true,
            viewerCount: 923456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "rick-and-morty",
            name: "Rick and Morty",
            logoURL: "https://i.ytimg.com/vi/sBvV1miNoA8/hqdefault.jpg", // Rick and Morty Season 7
            streamURL: s_entertain2,
            category: .comedy,
            description: "Wubba lubba dub dub! 24/7 🥒",
            isLive: true,
            viewerCount: 978654,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "aqua-teen",
            name: "Aqua Teen Hunger Force",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video1/v4/bc/92/44/bc924468-117d-c058-df93-7775a4630cc4/mzl.qqdnqczl.lsr/600x600bb.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "Number one in the hood, G! 24/7 🍟",
            isLive: true,
            viewerCount: 654321,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🎮 CARTOON NETWORK CLASSICS
    ]
}
