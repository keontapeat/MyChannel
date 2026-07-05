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
        
        // DEBUG-only sanity warning. NEVER crash here: channels may be decoded
        // from Firestore, and server-controlled data must not be able to
        // hard-crash the app. Authoring mistakes in bundled sample data are
        // caught (non-fatally) by validateAllChannelURLs(); server data with a
        // bad logo is filtered out during decode in LiveTVCatalogService.
        #if DEBUG
        if logoURL.contains("wikipedia.org") || logoURL.contains("wikimedia.org") || logoURL.hasSuffix(".svg") {
            print("⚠️ [LiveTVChannel] Non-approved logoURL for \"\(name)\": \(logoURL) — use a ytimg.com/approved-CDN JPG/PNG instead.")
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
    
    // Reliable HLS fallback streams (Apple test streams). Used as
    // previewFallbackURL and last-resort playback when a channel stream fails.
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
            
            // Non-fatal: surface loudly in debug without nuking the dev build.
            assertionFailure(errorMessage)
            print(errorMessage)
            return
        }
        
        print("✅ [LiveTVChannel] All \(sampleChannels.count) channel URLs validated - NO Wikipedia/SVG URLs found!")
        #endif
    }
}

// MARK: - 🔥 150+ VERIFIED WORKING CHANNELS - NOVEMBER 2025 🔥
