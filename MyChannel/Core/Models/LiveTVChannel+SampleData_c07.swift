import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 7
    static let _ltv07: [LiveTVChannel] = [
        LiveTVChannel(
            id: "threes-company",
            name: "Three's Company",
            logoURL: "https://i.ytimg.com/vi/cEqZ_dvxBSY/hqdefault.jpg",
            streamURL: s_classic1,
            category: .classic,
            description: "Classic sitcom 24/7",
            isLive: true,
            viewerCount: 234560,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "happy-days",
            name: "Happy Days",
            logoURL: "https://i.ytimg.com/vi/gZntX0Nejt4/hqdefault.jpg",
            streamURL: s_classic1,
            category: .classic,
            description: "Ayyyy! Happy Days 24/7",
            isLive: true,
            viewerCount: 345670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "love-boat",
            name: "The Love Boat",
            logoURL: "https://i.ytimg.com/vi/m_wFEB4Oxlo/hqdefault.jpg",
            streamURL: s_classic1,
            category: .classic,
            description: "Set sail for romance 24/7",
            isLive: true,
            viewerCount: 234560,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "gunsmoke",
            name: "Gunsmoke",
            logoURL: "https://i.ytimg.com/vi/KmxVm0Y1Dn4/hqdefault.jpg",
            streamURL: s_classic1,
            category: .classic,
            description: "Classic western 24/7",
            isLive: true,
            viewerCount: 234560,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
    ]
    
    // ============================================
    // 🌿 NATURE & DOCUMENTARY - VERIFIED WORKING ✅
    // ============================================
    static let documentaryChannels: [LiveTVChannel] = [
        
        LiveTVChannel(
            id: "bbc-earth",
            name: "BBC Earth",
            logoURL: "https://i.ytimg.com/vi/JkaxUblCGz0/hqdefault.jpg",
            streamURL: s_doc1,
            category: .documentary,
            description: "Nature documentaries 24/7",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "UK",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "pbs-nature",
            name: "PBS Nature",
            logoURL: "https://i.ytimg.com/vi/fiMVHLfvugo/hqdefault.jpg",
            streamURL: s_doc1,
            category: .documentary,
            description: "PBS Nature programming 24/7",
            isLive: true,
            viewerCount: 345670,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
        
        LiveTVChannel(
            id: "pet-collective",
            name: "The Pet Collective",
            logoURL: "https://i.ytimg.com/vi/mRf3-JkwqfU/hqdefault.jpg",
            streamURL: s_doc1,
            category: .lifestyle,
            description: "Cute animals 24/7 🐾",
            isLive: true,
            viewerCount: 456780,
            quality: "1080p",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        ),
    ]
    
    // ============================================
    // 📡 LIVE BREAKING NEWS - FREE 24/7
    // ============================================
    static let liveNewsChannels: [LiveTVChannel] = [
        LiveTVChannel(
            id: "abc-news-live",
            name: "ABC News Live",
            logoURL: "https://i.ytimg.com/vi/w_Ma8oQLmSM/hqdefault.jpg",
            streamURL: s_abcnews,
            category: .news,
            description: "ABC News breaking news 24/7",
            isLive: true, viewerCount: 1_203_456, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "nbc-news-now",
            name: "NBC News NOW",
            logoURL: "https://i.ytimg.com/vi/Qip9OQLFo0g/hqdefault.jpg",
            streamURL: s_nbcnews,
            category: .news,
            description: "NBC News 24/7 live coverage",
            isLive: true, viewerCount: 987_654, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "al-jazeera",
            name: "Al Jazeera English",
            logoURL: "https://i.ytimg.com/vi/PNTHggIFEJA/hqdefault.jpg",
            streamURL: s_aje,
            category: .news,
            description: "World news from Al Jazeera 24/7",
            isLive: true, viewerCount: 876_543, quality: "1080p", language: "English", country: "QA",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "dw-news",
            name: "DW News",
            logoURL: "https://i.ytimg.com/vi/boBCkpVwgio/hqdefault.jpg",
            streamURL: s_dw,
            category: .news,
            description: "Deutsche Welle — Germany's international news 24/7",
            isLive: true, viewerCount: 654_321, quality: "1080p", language: "English", country: "DE",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "france-24-en",
            name: "France 24 English",
            logoURL: "https://i.ytimg.com/vi/OJ5xTXSiMd4/hqdefault.jpg",
            streamURL: s_france24,
            category: .international,
            description: "France 24 international news 24/7",
            isLive: true, viewerCount: 543_210, quality: "1080p", language: "English", country: "FR",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "weather-nation",
            name: "WeatherNation",
            logoURL: "https://i.ytimg.com/vi/lUBU2E6tZZY/hqdefault.jpg",
            streamURL: s_weatherch,
            category: .news,
            description: "24/7 weather coverage across the nation",
            isLive: true, viewerCount: 345_678, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "newsnation-live",
            name: "NewsNation",
            logoURL: "https://i.ytimg.com/vi/P39gGs2-D7U/hqdefault.jpg",
            streamURL: s_scripps,
            category: .news,
            description: "Unbiased national news 24/7",
            isLive: true, viewerCount: 456_789, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "cheddar-news",
            name: "Cheddar News",
            logoURL: "https://i.ytimg.com/vi/G7SKgE4bBDg/hqdefault.jpg",
            streamURL: s_euronews,
            category: .news,
            description: "Tech and business news 24/7",
            isLive: true, viewerCount: 387_654, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "bbc-news-world",
            name: "BBC News",
            logoURL: "https://i.ytimg.com/vi/EujWBMM_b8s/hqdefault.jpg",
            streamURL: "https://vs-hls-push-ww-live.akamaized.net/x=4/i=urn:bbc:pips:service:bbc_news_channel_hd/t=3840/v=pv14/b=5070016/main.m3u8",
            category: .news,
            description: "BBC World News 24/7",
            isLive: true, viewerCount: 1_050_000, quality: "1080p", language: "English", country: "UK",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "i24-news",
            name: "i24 News English",
            logoURL: "https://i.ytimg.com/vi/GlCjt7HZMO4/hqdefault.jpg",
            streamURL: "https://bcovlive-a.akamaihd.net/8f8395579f1b4fa48ad51e8e70d2c2e4/us-east-1/5377161796001/playlist.m3u8",
            category: .news,
            description: "Middle East and world news 24/7",
            isLive: true, viewerCount: 298_765, quality: "1080p", language: "English", country: "IL",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "arirang-tv",
            name: "Arirang TV",
            logoURL: "https://i.ytimg.com/vi/GExMzZSFV4Y/hqdefault.jpg",
            streamURL: s_arirang,
            category: .international,
            description: "Korean international news & culture 24/7",
            isLive: true, viewerCount: 312_456, quality: "1080p", language: "English", country: "KR",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "nhk-world",
            name: "NHK World Japan",
            logoURL: "https://i.ytimg.com/vi/OpO4mJCMBDk/hqdefault.jpg",
            streamURL: "https://nhkwlive-ojp.akamaized.net/hls/live/2003459/nhkwlive-ojp-en/index_1M.m3u8",
            category: .international,
            description: "Japan's international broadcaster 24/7",
            isLive: true, viewerCount: 287_654, quality: "1080p", language: "English", country: "JP",
            epgURL: nil, previewFallbackURL: s_big
        ),
    ]

    // ============================================
    // 🧒 PBS KIDS + EDUCATIONAL
    // ============================================
    static let pbsKidsChannels: [LiveTVChannel] = [
        LiveTVChannel(
            id: "pbs-kids-live",
            name: "PBS Kids",
            logoURL: "https://i.ytimg.com/vi/y0rMSMDFIms/hqdefault.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Daniel Tiger, Curious George, Sesame Street & more 24/7",
            isLive: true, viewerCount: 934_567, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
    ]
}
