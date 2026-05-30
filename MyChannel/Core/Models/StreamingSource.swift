import Foundation
import SwiftUI

extension FreeMovie {
    enum StreamingSource: String, CaseIterable, Codable {
        case tubi = "tubi"
        case plexFree = "plex_free"
        case crackle = "crackle"
        case rokuChannel = "roku_channel"
        case internetArchive = "internet_archive"
        case imdbTV = "imdb_tv"
        case youtube = "youtube"
        case pexels = "pexels"
        case pixabay = "pixabay"
        case nasa = "nasa"
    
        var displayName: String {
            switch self {
            case .tubi: return "Tubi"
            case .plexFree: return "Plex"
            case .crackle: return "Crackle"
            case .rokuChannel: return "Roku Channel"
            case .internetArchive: return "Internet Archive"
            case .imdbTV: return "IMDb TV"
            case .youtube: return "YouTube Movies"
            case .pexels: return "Pexels"
            case .pixabay: return "Pixabay"
            case .nasa: return "NASA"
            }
        }
    
        var logoURL: String {
            switch self {
            case .tubi: return "https://tubitv.com/assets/images/tubi-logo.png"
            case .plexFree: return "https://www.plex.tv/wp-content/uploads/2018/01/plex-logo-dark.png"
            case .crackle: return "https://www.crackle.com/assets/images/crackle-logo.png"
            case .rokuChannel: return "https://image.roku.com/developer_channels/prod/channel-icon.png"
            case .internetArchive: return "https://archive.org/images/ia_logo.png"
            case .imdbTV: return "https://m.media-amazon.com/images/G/01/IMDb/BG_rectangle.png"
            case .youtube: return "https://www.youtube.com/s/desktop/youtube-logo.png"
            case .pexels: return "https://images.pexels.com/lib/api/pexels.png"
            case .pixabay: return "https://pixabay.com/static/img/logo_square.png"
            case .nasa: return "https://i.ytimg.com/vi/21X5lGlDOfg/hqdefault.jpg"
            }
        }
    
        var color: Color {
            switch self {
            case .tubi: return .orange
            case .plexFree: return .yellow
            case .crackle: return .red
            case .rokuChannel: return .purple
            case .internetArchive: return .blue
            case .imdbTV: return .yellow
            case .youtube: return .red
            case .pexels: return .green
            case .pixabay: return .teal
            case .nasa: return .indigo
            }
        }
    }

}