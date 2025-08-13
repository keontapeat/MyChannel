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
        // 1) Al Jazeera English (stable)
        LiveTVChannel(
            id: "aje-english",
            name: "Al Jazeera English",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Al_Jazeera_English_logo.svg/512px-Al_Jazeera_English_logo.svg.png",
            streamURL: "https://live-hls-web-aje.getaj.net/AJE/01.m3u8",
            category: .news,
            description: "Global news and analysis from Al Jazeera English",
            isLive: true,
            viewerCount: 31200,
            quality: "HD",
            language: "English",
            country: "International",
            epgURL: nil
        ),
        // 2) DW English (stable)
        LiveTVChannel(
            id: "dw-english",
            name: "DW English",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/Deutsche_Welle_logo.svg/512px-Deutsche_Welle_logo.svg.png",
            streamURL: "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8",
            category: .international,
            description: "Deutsche Welle’s international news channel",
            isLive: true,
            viewerCount: 22100,
            quality: "HD",
            language: "English",
            country: "International",
            epgURL: nil
        ),
        // 3) France 24 English (stable)
        LiveTVChannel(
            id: "france24-en",
            name: "France 24 (English)",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/FRANCE_24_logo.svg/512px-FRANCE_24_logo.svg.png",
            streamURL: "https://static.france24.com/live/F24_EN_LO_HLS/live_web.m3u8",
            category: .international,
            description: "International news from France 24 in English",
            isLive: true,
            viewerCount: 18750,
            quality: "HD",
            language: "English",
            country: "International",
            epgURL: nil
        ),
        // The rest of the sample lineup (unchanged order is fine for demo)
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
        ),
        LiveTVChannel(
            id: "trt-world",
            name: "TRT World",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/TRT_World_logo.svg/512px-TRT_World_logo.svg.png",
            streamURL: "https://tv-trtworld.live.trt.com.tr/master_720.m3u8",
            category: .international,
            description: "Global news and current affairs from TRT World",
            isLive: true,
            viewerCount: 16340,
            quality: "HD",
            language: "English",
            country: "International",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "bloomberg-us",
            name: "Bloomberg TV",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/Bloomberg_logo.svg/512px-Bloomberg_logo.svg.png",
            streamURL: "https://www.bloomberg.com/media-manifest/streams/us.m3u8",
            category: .business,
            description: "Live business and financial news from Bloomberg",
            isLive: true,
            viewerCount: 29870,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "nasa-public",
            name: "NASA TV Public",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/NASA_logo.svg/512px-NASA_logo.svg.png",
            streamURL: "https://ntv1-aka.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8",
            category: .documentary,
            description: "Live NASA events, launches, and educational programming",
            isLive: true,
            viewerCount: 15450,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil
        ),
        LiveTVChannel(
            id: "nhk-world",
            name: "NHK World Japan",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/NHK-World.svg/512px-NHK-World.svg.png",
            streamURL: "https://nhkworld.webcdn.stream.ne.jp/www11/nhkworld-tv/global/2639429/live.m3u8",
            category: .international,
            description: "Japan’s international broadcasting service in English",
            isLive: true,
            viewerCount: 14210,
            quality: "HD",
            language: "English",
            country: "Japan",
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