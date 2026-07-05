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