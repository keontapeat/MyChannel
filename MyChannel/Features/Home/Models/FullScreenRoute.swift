import Foundation
import SwiftUI

enum FullScreenRoute: Identifiable {
    case video(Video)
    case movie(FreeMovie)
    case search
    case stories(AssetStory)
    case allMovies
    case allLiveTV
    case trending
    case artistDetail(name: String, avatar: String, videos: [Video], totalViews: Int)
    case artistMusicProfile(CatalogArtist)
    case filmmakerDetail(name: String, films: [FreeMovie])
    case channelDetail(name: String, avatar: String, subscribers: Int, totalViews: Int, videos: [Video])
    case publicProfile(User)
    case liveStream(FirestoreLiveStream)
    case custom(String)

    var id: String {
        switch self {
        case .video(let v): return "video-\(v.id)"
        case .movie(let m): return "movie-\(m.id)"
        case .search: return "search"
        case .stories(let s): return "stories-\(s.id)"
        case .allMovies: return "allMovies"
        case .allLiveTV: return "allLiveTV"
        case .trending: return "trending"
        case .artistDetail(let name, _, _, _): return "artist-\(name)"
        case .artistMusicProfile(let a): return "artistMusic-\(a.id)"
        case .filmmakerDetail(let name, _): return "filmmaker-\(name)"
        case .channelDetail(let name, _, _, _, _): return "channel-\(name)"
        case .publicProfile(let user): return "profile-\(user.id)"
        case .liveStream(let s): return "live-\(s.id)"
        case .custom(let id): return id
        }
    }
}
