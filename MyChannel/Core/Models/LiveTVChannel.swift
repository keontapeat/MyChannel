import SwiftUI
import Foundation

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
        
        var displayName: String {
            switch self {
            case .news: return "📰 News"
            case .sports: return "⚽ Sports"
            case .entertainment: return "🎭 Entertainment"
            case .movies: return "🎬 Movies"
            case .music: return "🎵 Music"
            case .kids: return "👶 Kids"
            case .documentary: return "📽️ Documentary"
            case .lifestyle: return "✨ Lifestyle"
            case .business: return "💼 Business"
            case .international: return "🌍 International"
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
            }
        }
    }
}

// MARK: - Sample Live TV Channels
extension LiveTVChannel {
    static let sampleChannels: [LiveTVChannel] = [
        // Pluto TV Channels
        LiveTVChannel(
            id: "pluto-cbs-news",
            name: "CBS News",
            logoURL: "https://images.pluto.tv/channels/5421409d14549f8c5b457090/colorLogoPNG.png",
            streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/5421409d14549f8c5b457090/master.m3u8",
            category: .news,
            description: "24/7 breaking news and live coverage",
            isLive: true,
            viewerCount: 15420,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/5421409d14549f8c5b457090/guide.json"
        ),
        LiveTVChannel(
            id: "pluto-mtv-music",
            name: "MTV Music",
            logoURL: "https://images.pluto.tv/channels/5ca673e0d0c88d2f61c6e648/colorLogoPNG.png",
            streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/5ca673e0d0c88d2f61c6e648/master.m3u8",
            category: .music,
            description: "Non-stop music videos and performances",
            isLive: true,
            viewerCount: 8934,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "pluto-comedy-central",
            name: "Comedy Central Pluto TV",
            logoURL: "https://images.pluto.tv/channels/5ca676b0d4c93e92bcb55ab8/colorLogoPNG.png",
            streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/5ca676b0d4c93e92bcb55ab8/master.m3u8",
            category: .entertainment,
            description: "Comedy shows and stand-up specials",
            isLive: true,
            viewerCount: 12567,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        // Plex Live TV Channels
        LiveTVChannel(
            id: "plex-classic-movies",
            name: "Plex Classic Movies",
            logoURL: "https://provider-static.plex.tv/epg/images/ott_channels/logos/plex-classic-movies.png",
            streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/plex-classic-movies/master.m3u8",
            category: .movies,
            description: "Classic Hollywood films 24/7",
            isLive: true,
            viewerCount: 6789,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "roku-nbc-news",
            name: "NBC News Now",
            logoURL: "https://image.roku.com/developer_channels/prod/0fec9cfbaacf5bb4d5c83e32e0a0ca4ce46c9962a8fd1e8c0fe3cdbceaa93c9c.png",
            streamURL: "https://d2gjhy8g9ziabr.cloudfront.net/v1/master/3fec3e5cac39a52b2132f9c66c83dae043dc17d4/prod-samsungtvplus-stitched/roku-nbcnewsnow.m3u8",
            category: .news,
            description: "Breaking news and live coverage from NBC",
            isLive: true,
            viewerCount: 23456,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "samsung-fox-sports",
            name: "Fox Sports",
            logoURL: "https://tvpnlogopeu.samsungcloud.tv/platform/image/sourcelogo/vc/00/02/34/USAJ300000MC_20231011T045244SQUARE.png",
            streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/fox-sports/master.m3u8",
            category: .sports,
            description: "Live sports coverage and highlights",
            isLive: true,
            viewerCount: 18903,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        )
    ]
}

#Preview {
    VStack {
        ForEach(LiveTVChannel.sampleChannels.prefix(3)) { channel in
            HStack {
                AsyncImage(url: URL(string: channel.logoURL)) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle().fill(.gray)
                }
                .frame(width: 60, height: 40)
                .cornerRadius(8)
                
                VStack(alignment: .leading) {
                    Text(channel.name)
                        .font(.headline)
                    Text(channel.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
        }
    }
}