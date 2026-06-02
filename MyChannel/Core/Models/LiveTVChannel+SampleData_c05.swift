import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 5
    static let _ltv05: [LiveTVChannel] = [
        LiveTVChannel(
            id: "nick-jr",
            name: "Nick Jr.",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video62/v4/53/33/33/53333372-6d23-07c8-6519-2f91fc98db6c/mzm.kpdggamc.lsr/600x600bb.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Preschool shows for little ones",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "peppa-pig",
            name: "Peppa Pig",
            logoURL: "https://i.ytimg.com/vi/xzhfEoGkuv4/hqdefault.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Oink oink! Peppa Pig 24/7",
            isLive: true,
            viewerCount: 678900,
            quality: "1080p",
            language: "English",
            country: "UK",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "ryan-friends",
            name: "Ryan and Friends",
            logoURL: "https://i.ytimg.com/vi/RYjg7l5bXJU/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "Ryan's World adventures 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "garfield",
            name: "Garfield and Friends",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video116/v4/73/ba/ed/73baed73-8073-557a-547a-173ae7e75271/pr_source.png/600x600bb.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Lasagna-loving cat 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "baby-shark",
            name: "Baby Shark TV",
            logoURL: "https://i.ytimg.com/vi/XqZsoesa55w/hqdefault.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Doo doo doo doo doo doo 🦈",
            isLive: true,
            viewerCount: 789650,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "lego-kids",
            name: "LEGO Kids TV",
            logoURL: "https://i.ytimg.com/vi/0LTRpZ2xfMw/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "Everything is awesome! 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "kartoon-channel",
            name: "Kartoon Channel!",
            logoURL: "https://i.ytimg.com/vi/SiMHTK15Pik/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Non-stop cartoons 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "transformers",
            name: "Transformers TV",
            logoURL: "https://i.ytimg.com/vi/nLS2N9mHWaw/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Robots in disguise 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "icarly",
            name: "iCarly TV",
            logoURL: "https://i.ytimg.com/vi/qDgL9hLmcbA/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "iCarly episodes 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "90s-kids",
            name: "90's Kids TV",
            logoURL: "https://i.ytimg.com/vi/Df0sHiPa_xc/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Nostalgic 90s cartoons 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "mister-rogers",
            name: "Mister Rogers",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video69/v4/8d/ac/be/8dacbea7-2894-b6ae-3712-7a23bb459f50/mzl.soojzjrj.lsr/600x600bb.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Won't you be my neighbor? 24/7",
            isLive: true,
            viewerCount: 345670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "totally-turtles",
            name: "Totally Turtles",
            logoURL: "https://i.ytimg.com/vi/4c9T2k42MIE/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Cowabunga! TMNT 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "strawberry-shortcake",
            name: "Strawberry Shortcake",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video211/v4/ec/4f/2e/ec4f2e12-851f-5f11-5c81-4be51c9bd69c/Strawberry-Shortcake-Berry-in-the-Big-City_S3_3000x3000-Gracenote-Texted.jpg/600x600bb.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Sweet adventures 24/7",
            isLive: true,
            viewerCount: 234560,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "go-go-gadget",
            name: "Go Go Gadget!",
            logoURL: "https://i.ytimg.com/vi/e-JHfXVlkik/hqdefault.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "Inspector Gadget 24/7",
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
    // 📺 NEWS CHANNELS - VERIFIED WORKING ✅
    // ============================================
    static let newsChannels: [LiveTVChannel] = [
        
        LiveTVChannel(
            id: "cbs-news",
            name: "CBS News 24/7",
            logoURL: "https://i.ytimg.com/vi/AjUz8e5oJrU/hqdefault.jpg",
            streamURL: s_cbsnews,
            category: .news,
            description: "CBS News streaming 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "scripps-news",
            name: "Scripps News",
            logoURL: "https://i.ytimg.com/vi/sY_dyTJZBQQ/hqdefault.jpg",
            streamURL: s_scripps,
            category: .news,
            description: "National and world news 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "sky-news",
            name: "Sky News",
            logoURL: "https://i.ytimg.com/vi/9Auq9mYxFEE/hqdefault.jpg",
            streamURL: "https://skynews-i.akamaihd.net/hls/live/584400/skynews/primary/master.m3u8",
            category: .news,
            description: "Breaking news from UK 24/7",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "UK",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "bloomberg",
            name: "Bloomberg TV+",
            logoURL: "https://i.ytimg.com/vi/dp8PhLsUcFE/hqdefault.jpg",
            streamURL: s_bloomberg2,
            category: .business,
            description: "Business and financial news 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "nasa-tv",
            name: "NASA TV",
            logoURL: "https://i.ytimg.com/vi/nA9UZF-SZoQ/hqdefault.jpg", // NASA Artemis I Launch - official NASA channel
            streamURL: s_nasa,
            category: .documentary,
            description: "Space exploration 24/7",
            isLive: true,
            viewerCount: 345670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://ntv2.akamaized.net/hls/live/2013923/NASA-NTV2-HLS/master.m3u8"
        ),
    ]
    
    // ============================================
    // ⚽ SPORTS CHANNELS - VERIFIED WORKING ✅
    // ============================================
    static let sportsChannels: [LiveTVChannel] = [
        
        LiveTVChannel(
            id: "cbs-sports-hq",
            name: "CBS Sports HQ",
            logoURL: "https://i.ytimg.com/vi/QjqYBGjWFh4/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "24/7 sports news and highlights",
            isLive: true,
            viewerCount: 567890,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
    ]
}
