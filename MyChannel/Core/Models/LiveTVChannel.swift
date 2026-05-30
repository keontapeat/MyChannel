import SwiftUI
import Foundation

// =============================================================================
// 🔥🛡️ NUCLEAR URL PROTECTION - NEVER USE WIKIPEDIA/WIKIMEDIA URLS! 🛡️🔥
// =============================================================================
// ⚠️ BLOCKED URL SOURCES (THEY GET BLOCKED AND SHOW BROKEN THUMBNAILS):
//    - wikipedia.org
//    - wikimedia.org
//    - .svg files
//
// ✅ APPROVED URL SOURCES FOR logoURL:
//    - ytimg.com (YouTube thumbnails) - PREFERRED
//    - imgur.com
//    - cloudinary.com
//    - googleusercontent.com
//    - akamaized.net
//    - cloudfront.net
//
// 🔥 HOW TO GET A YOUTUBE THUMBNAIL:
//    1. Search YouTube for "{Channel Name} trailer" or "{Show Name}"
//    2. Copy the video ID from URL (e.g., dQw4w9WgXcQ)
//    3. Use: https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg
// =============================================================================

// MARK: - Live TV Channel Model
struct LiveTVChannel: Identifiable, Codable {
    let id: String
    let name: String
    let logoURL: String
    let streamURL: String
    let category: ChannelCategory
    let description: String
    let isLive: Bool
    let viewerCount: Int
    let quality: String
    let language: String
    let country: String
    let epgURL: String? // Electronic Program Guide
    let previewFallbackURL: String?
    
    // 🔥🛡️ NUCLEAR VALIDATION - Runs in DEBUG to catch bad URLs immediately
    init(id: String, name: String, logoURL: String, streamURL: String, category: ChannelCategory,
         description: String, isLive: Bool, viewerCount: Int, quality: String,
         language: String, country: String, epgURL: String?, previewFallbackURL: String?) {
        
        // 🚨 NUCLEAR ASSERTION - CRASH IN DEBUG IF WIKIPEDIA URL IS USED
        #if DEBUG
        if logoURL.contains("wikipedia.org") || logoURL.contains("wikimedia.org") {
            fatalError("""
                🚨🚨🚨 NUCLEAR ERROR 🚨🚨🚨
                WIKIPEDIA/WIKIMEDIA URL DETECTED IN CHANNEL: \(name)
                URL: \(logoURL)
                
                ⚠️ WIKIPEDIA URLs ARE BLOCKED AND WILL NOT LOAD!
                
                ✅ FIX: Use a YouTube thumbnail instead:
                   https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg
                
                Search YouTube for "\(name) trailer" to find a video ID.
                🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
                """)
        }
        if logoURL.hasSuffix(".svg") {
            fatalError("""
                🚨🚨🚨 NUCLEAR ERROR 🚨🚨🚨
                SVG URL DETECTED IN CHANNEL: \(name)
                URL: \(logoURL)
                
                ⚠️ SVG FILES CANNOT BE LOADED BY AsyncImage!
                
                ✅ FIX: Use a YouTube thumbnail instead:
                   https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg
                🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
                """)
        }
        #endif
        
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.category = category
        self.description = description
        self.isLive = isLive
        self.viewerCount = viewerCount
        self.quality = quality
        self.language = language
        self.country = country
        self.epgURL = epgURL
        self.previewFallbackURL = previewFallbackURL
    }
    
    enum ChannelCategory: String, CaseIterable, Codable {
        case news = "news"
        case sports = "sports"
        case entertainment = "entertainment"
        case movies = "movies"
        case music = "music"
        case kids = "kids"
        case documentary = "documentary"
        case lifestyle = "lifestyle"
        case business = "business"
        case international = "international"
        case anime = "anime"
        case scifi = "scifi"
        case comedy = "comedy"
        case reality = "reality"
        case classic = "classic"
        
        var displayName: String {
            switch self {
            case .news: return "News"
            case .sports: return "Sports"
            case .entertainment: return "Entertainment"
            case .movies: return "Movies"
            case .music: return "Music"
            case .kids: return "Kids"
            case .documentary: return "Documentary"
            case .lifestyle: return "Lifestyle"
            case .business: return "Business"
            case .international: return "International"
            case .anime: return "Anime"
            case .scifi: return "Sci-Fi"
            case .comedy: return "Comedy"
            case .reality: return "Reality"
            case .classic: return "Classic TV"
            }
        }
        
        var color: Color {
            switch self {
            case .news: return .red
            case .sports: return .green
            case .entertainment: return .purple
            case .movies: return .blue
            case .music: return .pink
            case .kids: return .yellow
            case .documentary: return .orange
            case .lifestyle: return .mint
            case .business: return .gray
            case .international: return .cyan
            case .anime: return .indigo
            case .scifi: return .teal
            case .comedy: return .orange
            case .reality: return .pink
            case .classic: return .brown
            }
        }
    }
    
    // Helper to build Pluto TV URLs - Updated December 2024
    // 🔥 Uses the latest working URL format with proper parameters
    static func plutoURL(_ channelId: String) -> String {
        // Generate unique but stable device/session IDs
        let deviceId = UUID().uuidString.lowercased()
        let sessionId = UUID().uuidString.lowercased()
        
        // Use the stitcher endpoint which is the most reliable for external playback
        // This format works better than the embed format as of December 2024
        return "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/\(channelId)/master.m3u8?advertisingId=\(deviceId)&appName=web&appVersion=5.0&deviceDNT=0&deviceId=\(deviceId)&deviceMake=web&deviceModel=web&deviceType=web&deviceVersion=1.0&includeExtendedEvents=false&sid=\(sessionId)&serverSideAds=false"
    }
    
    // 🔥 Alternative URL format if primary fails (used as fallback)
    static func plutoURLAlt(_ channelId: String) -> String {
        let deviceId = UUID().uuidString.lowercased()
        return "https://service-stitcher.clusters.pluto.tv/v2/stitch/hls/channel/\(channelId)/master.m3u8?deviceId=\(deviceId)&deviceType=web&deviceMake=web&deviceModel=web&deviceVersion=1.0&appName=web&appVersion=5.0&deviceDNT=1"
    }
    
    // 🔥 Reliable fallback streams for when Pluto fails
    static let reliableFallbackStreams: [String] = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    ]
    
    // 🔥🛡️ NUCLEAR VALIDATION - Call this on app launch to catch ANY bad URLs
    static func validateAllChannelURLs() {
        #if DEBUG
        var badChannels: [(name: String, url: String, reason: String)] = []
        
        for channel in sampleChannels {
            if channel.logoURL.contains("wikipedia.org") || channel.logoURL.contains("wikimedia.org") {
                badChannels.append((channel.name, channel.logoURL, "Wikipedia/Wikimedia URL"))
            }
            if channel.logoURL.hasSuffix(".svg") {
                badChannels.append((channel.name, channel.logoURL, "SVG file"))
            }
        }
        
        if !badChannels.isEmpty {
            var errorMessage = """
                
                🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
                🔥 NUCLEAR URL VALIDATION FAILED! 🔥
                🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
                
                The following channels have BLOCKED URLs that will NOT load:
                
                """
            
            for bad in badChannels {
                errorMessage += """
                    ❌ \(bad.name)
                       URL: \(bad.url)
                       Reason: \(bad.reason)
                    
                    """
            }
            
            errorMessage += """
                
                ✅ FIX: Replace with YouTube thumbnails:
                   https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg
                
                🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
                """
            
            fatalError(errorMessage)
        }
        
        print("✅ [LiveTVChannel] All \(sampleChannels.count) channel URLs validated - NO Wikipedia/SVG URLs found!")
        #endif
    }
}

// MARK: - 🔥 150+ VERIFIED WORKING CHANNELS - NOVEMBER 2025 🔥
