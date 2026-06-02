import Foundation
import SwiftUI

extension LiveTVChannel {
    // MARK: Chunk 8
    static let _ltv08: [LiveTVChannel] = [
        LiveTVChannel(
            id: "cartoon-network-live",
            name: "Cartoon Network",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video/v4/b9/6e/2f/b96e2feb-31cb-a6e3-9e1a-2e0e07cb18ad/mzl.edfwsgvj.lsr/600x600bb.jpg",
            streamURL: s_kids2,
            category: .kids,
            description: "All-day cartoons from CN 24/7",
            isLive: true, viewerCount: 812_345, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "treehouse-tv",
            name: "Treehouse TV",
            logoURL: "https://is1-ssl.mzstatic.com/image/thumb/Video62/v4/53/33/33/53333372-6d23-07c8-6519-2f91fc98db6c/mzm.kpdggamc.lsr/600x600bb.jpg",
            streamURL: s_pbskids,
            category: .kids,
            description: "Preschool shows for toddlers 24/7",
            isLive: true, viewerCount: 412_300, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "kidstream",
            name: "KidStream",
            logoURL: "https://i.ytimg.com/vi/SiMHTK15Pik/hqdefault.jpg",
            streamURL: s_kids1,
            category: .kids,
            description: "Educational kids content 24/7",
            isLive: true, viewerCount: 298_110, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
    ]

    // ============================================
    // 🏀 MORE SPORTS — STADIUM, MOTOR, OUTDOOR
    // ============================================
    static let extendedSportsChannels: [LiveTVChannel] = [
        LiveTVChannel(
            id: "stadium-sports",
            name: "Stadium",
            logoURL: "https://i.ytimg.com/vi/Rcf4n5G5DXQ/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "College sports & more 24/7",
            isLive: true, viewerCount: 567_890, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "motortrend",
            name: "MotorTrend",
            logoURL: "https://i.ytimg.com/vi/aSiDu3Ywi8E/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "Cars, racing, and automotive 24/7",
            isLive: true, viewerCount: 456_780, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "outside-tv",
            name: "Outside TV",
            logoURL: "https://i.ytimg.com/vi/qR3rK0kZFkg/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "Outdoor adventure sports 24/7",
            isLive: true, viewerCount: 312_450, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "fight-network",
            name: "Fight Network",
            logoURL: "https://i.ytimg.com/vi/Y7dOQukBfOE/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "MMA, boxing, wrestling 24/7",
            isLive: true, viewerCount: 489_320, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "fightful-wrestling",
            name: "Pluto TV Wrestling",
            logoURL: "https://i.ytimg.com/vi/nLS2N9mHWaw/hqdefault.jpg",
            streamURL: s_sports1,
            category: .sports,
            description: "Pro wrestling action 24/7",
            isLive: true, viewerCount: 534_210, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
    ]

    // ============================================
    // 🎨 ARTS, PAINTING & LIFESTYLE EXPANDED
    // ============================================
    static let artsLifestyleChannels: [LiveTVChannel] = [
        LiveTVChannel(
            id: "cooking-channel",
            name: "Cooking Channel",
            logoURL: "https://i.ytimg.com/vi/YD_DNzjhPGE/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .lifestyle,
            description: "Recipes and cooking shows 24/7",
            isLive: true, viewerCount: 567_890, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "love-nature",
            name: "Love Nature",
            logoURL: "https://i.ytimg.com/vi/JkaxUblCGz0/hqdefault.jpg",
            streamURL: s_doc1,
            category: .documentary,
            description: "Wildlife & nature documentaries 24/7",
            isLive: true, viewerCount: 456_780, quality: "4K", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "home-how-to",
            name: "Home & How-To",
            logoURL: "https://i.ytimg.com/vi/vmplK_MOEnc/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .lifestyle,
            description: "DIY, home improvement & gardening 24/7",
            isLive: true, viewerCount: 345_670, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "poker-channel",
            name: "Poker Channel",
            logoURL: "https://i.ytimg.com/vi/kkFFPyLLq9g/hqdefault.jpg",
            streamURL: s_entertain1,
            category: .entertainment,
            description: "World Series of Poker 24/7",
            isLive: true, viewerCount: 289_450, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "crime-investigation",
            name: "Crime + Investigation",
            logoURL: "https://i.ytimg.com/vi/5Ggik1rly3k/hqdefault.jpg",
            streamURL: s_crime1,
            category: .documentary,
            description: "True crime documentaries 24/7",
            isLive: true, viewerCount: 612_345, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "pluto-spanish",
            name: "Pluto TV Español",
            logoURL: "https://i.ytimg.com/vi/lJqbaGloVxg/hqdefault.jpg",
            streamURL: s_rt,
            category: .international,
            description: "Spanish-language content 24/7",
            isLive: true, viewerCount: 723_456, quality: "1080p", language: "Spanish", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "kpop-music",
            name: "K-Pop Music",
            logoURL: "https://i.ytimg.com/vi/kffacxfA7G4/hqdefault.jpg",
            streamURL: s_vevo_pop,
            category: .music,
            description: "K-Pop hits and videos 24/7",
            isLive: true, viewerCount: 876_543, quality: "1080p", language: "Korean", country: "KR",
            epgURL: nil, previewFallbackURL: s_big
        ),
        LiveTVChannel(
            id: "vevo-country",
            name: "Vevo Country",
            logoURL: "https://i.ytimg.com/vi/450p7goxZqg/hqdefault.jpg",
            streamURL: s_vevo_pop,
            category: .music,
            description: "Country music videos 24/7",
            isLive: true, viewerCount: 534_210, quality: "1080p", language: "English", country: "US",
            epgURL: nil, previewFallbackURL: s_big
        ),
    ]
}
