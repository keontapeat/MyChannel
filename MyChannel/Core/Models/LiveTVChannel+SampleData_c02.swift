import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 2
    static let _ltv02: [LiveTVChannel] = [
        LiveTVChannel(
            id: "johnny-bravo",
            name: "Johnny Bravo",
            logoURL: "https://i.ytimg.com/vi/VVggZDdg4sY/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Do the monkey with me! 24/7 💪😎",
            isLive: true,
            viewerCount: 723456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "dexters-lab",
            name: "Dexter's Laboratory",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video/b9/bb/44/mzl.ekiaettn.jpg/600x600bb.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Omelette du fromage! 24/7 🔬",
            isLive: true,
            viewerCount: 756789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "powerpuff-girls",
            name: "The Powerpuff Girls",
            logoURL: "https://i.ytimg.com/vi/f7MiaSr-0ug/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Sugar, spice, everything nice! 24/7 💚💖💙",
            isLive: true,
            viewerCount: 812345,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "ed-edd-eddy",
            name: "Ed, Edd n Eddy",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video/46/2a/a5/mzl.aeelrlhg.jpg/600x600bb.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Jawbreakers! 24/7 🍬",
            isLive: true,
            viewerCount: 789456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "codename-knd",
            name: "Codename: Kids Next Door",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Features/4d/dd/f5/dj.ipvozibz.jpg/600x600bb.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Kids Next Door, BATTLESTATIONS! 24/7",
            isLive: true,
            viewerCount: 698765,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "samurai-jack",
            name: "Samurai Jack",
            logoURL: "https://i.ytimg.com/vi/4iBU_D36-AA/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "Gotta get back, back to the past! 24/7 ⚔️",
            isLive: true,
            viewerCount: 845678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🍕 NICKELODEON CLASSICS
        LiveTVChannel(
            id: "spongebob",
            name: "SpongeBob SquarePants",
            logoURL: "https://i.ytimg.com/vi/ZbhRD9lGios/hqdefault.jpg", // SpongeBob Movie 2025
            streamURL: s_kids1,
            category: .kids,
            description: "I'M READY! 24/7 🧽",
            isLive: true,
            viewerCount: 999888,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "fairly-oddparents",
            name: "The Fairly OddParents",
            logoURL: "https://i.ytimg.com/vi/no8vgXg_rlw/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "Obtuse, rubber goose! 24/7 ✨",
            isLive: true,
            viewerCount: 876543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "danny-phantom",
            name: "Danny Phantom",
            logoURL: "https://i.ytimg.com/vi/2djx83-4XNY/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "He's a phantom! 24/7 👻",
            isLive: true,
            viewerCount: 765432,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "avatar",
            name: "Avatar: The Last Airbender",
            logoURL: "https://i.ytimg.com/vi/WdudOdxs7aU/hqdefault.jpg", // Avatar Netflix Final Trailer
            streamURL: s_kids2,
            category: .anime,
            description: "Water. Earth. Fire. Air. 24/7 🌊🪨🔥💨",
            isLive: true,
            viewerCount: 987654,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🎬 MORE BANGERS
        LiveTVChannel(
            id: "simpsons",
            name: "The Simpsons",
            logoURL: "https://i.ytimg.com/vi/DX1iplQQJTo/hqdefault.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "D'oh! 24/7 🍩",
            isLive: true,
            viewerCount: 956789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "king-of-hill",
            name: "King of the Hill",
            logoURL: "https://i.ytimg.com/vi/dQkJ5K-JTPU/hqdefault.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "I tell you hwat! 24/7 🍺",
            isLive: true,
            viewerCount: 823456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "bobs-burgers",
            name: "Bob's Burgers",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video5/v4/7a/d8/a6/7ad8a6e1-76c4-b135-6ff1-fd6d916ecb23/mzl.vokzsxrx.lsr/600x600bb.jpg",
            streamURL: s_entertain2,
            category: .comedy,
            description: "Burger of the day! 24/7 🍔",
            isLive: true,
            viewerCount: 789012,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🎮 GAMING & ACTION
        LiveTVChannel(
            id: "sonic",
            name: "Sonic the Hedgehog",
            logoURL: "https://i.ytimg.com/vi/nBbbyLxPdSE/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Gotta go fast! 24/7 🦔💨",
            isLive: true,
            viewerCount: 856789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "looney-tunes",
            name: "Looney Tunes",
            logoURL: "https://i.ytimg.com/vi/nalw1XRAiMI/hqdefault.jpg", // Looney Tunes Cartoons HBO Max
            streamURL: s_kids2,
            category: .kids,
            description: "That's all folks! 24/7 🐰🦆",
            isLive: true,
            viewerCount: 912345,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "tom-jerry",
            name: "Tom & Jerry",
            logoURL: "https://i.ytimg.com/vi/E7lwxBBnGEg/hqdefault.jpg", // Tom & Jerry 2021 Movie
            streamURL: s_kids2,
            category: .kids,
            description: "Classic cat & mouse! 24/7 🐱🐭",
            isLive: true,
            viewerCount: 945678,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        // 🔥 MORE ANIME HEAT
        LiveTVChannel(
            id: "bleach",
            name: "Bleach",
            logoURL: "https://i.ytimg.com/vi/78WIYzX_m98/hqdefault.jpg", // Bleach TYBW Jump Festa
            streamURL: s_kids2,
            category: .anime,
            description: "Bankai! 24/7 ⚔️",
            isLive: true,
            viewerCount: 867543,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "death-note",
            name: "Death Note",
            logoURL: "https://i.ytimg.com/vi/NlJZ-YgAt-c/hqdefault.jpg",
            streamURL: s_kids2,
            category: .anime,
            description: "I'll take a potato chip... AND EAT IT! 24/7 📓",
            isLive: true,
            viewerCount: 923456,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "attack-titan",
            name: "Attack on Titan",
            logoURL: "https://i.ytimg.com/vi/o_go-8TFBXs/hqdefault.jpg", // AOT Final Season Trailer
            streamURL: s_kids2,
            category: .anime,
            description: "SHINZOU WO SASAGEYO! 24/7 🗡️",
            isLive: true,
            viewerCount: 978654,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        )
    ]

    // MARK: - fireChannels Part B (My Hero → end)
    static let _fireChannels_b: [LiveTVChannel] = [
        LiveTVChannel(
            id: "my-hero",
            name: "My Hero Academia",
            logoURL: "https://i.ytimg.com/vi/i5gsMF3yZ60/hqdefault.jpg", // MHA Season 4 Crunchyroll
            streamURL: s_kids2,
            category: .anime,
            description: "PLUS ULTRA! 24/7 💪🦸",
            isLive: true,
            viewerCount: 956789,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
    ]
}
