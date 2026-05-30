import SwiftUI

enum MusicMood: String, CaseIterable {
    case chill = "Chill"
    case hype = "Hype"
    case focus = "Focus"
    case workout = "Workout"
    case party = "Party"
    case sad = "Sad"
    case happy = "Happy"
    case romantic = "Romantic"
    
    var icon: String {
        switch self {
        case .chill: return "leaf.fill"
        case .hype: return "flame.fill"
        case .focus: return "brain.head.profile"
        case .workout: return "figure.run"
        case .party: return "sparkles"
        case .sad: return "cloud.rain.fill"
        case .happy: return "sun.max.fill"
        case .romantic: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .chill: return .mint
        case .hype: return .orange
        case .focus: return .purple
        case .workout: return .red
        case .party: return .pink
        case .sad: return .blue
        case .happy: return .yellow
        case .romantic: return .red
        }
    }
}

enum MusicGenre: String, CaseIterable {
    case hiphop = "Hip-Hop"
    case rnb = "R&B"
    case pop = "Pop"
    case rock = "Rock"
    case electronic = "Electronic"
    case jazz = "Jazz"
    case country = "Country"
    case gospel = "Gospel"
    
    var searchTerm: String { rawValue }
    
    var color: LinearGradient {
        switch self {
        case .hiphop: return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rnb: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pop: return LinearGradient(colors: [.pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rock: return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .electronic: return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .jazz: return LinearGradient(colors: [.brown, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .country: return LinearGradient(colors: [.yellow, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gospel: return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var icon: String {
        switch self {
        case .hiphop: return "music.mic"
        case .rnb: return "heart.fill"
        case .pop: return "star.fill"
        case .rock: return "guitars.fill"
        case .electronic: return "waveform"
        case .jazz: return "music.quarternote.3"
        case .country: return "music.note"
        case .gospel: return "hands.clap.fill"
        }
    }
}

struct CuratedPlaylist: Identifiable {
    let id: String
    let name: String
    let description: String
    let imageColors: [Color]
    let icon: String
    let songCount: Int
    
    static let featuredPlaylists: [CuratedPlaylist] = [
        CuratedPlaylist(
            id: "810-essentials",
            name: "810 Essentials",
            description: "Essential hits, all day",
            imageColors: [.orange, .red],
            icon: "flame.fill",
            songCount: 50
        ),
        CuratedPlaylist(
            id: "808-heat",
            name: "808 Heat",
            description: "Hottest tracks right now",
            imageColors: [.red, .pink],
            icon: "waveform.path",
            songCount: 30
        ),
        CuratedPlaylist(
            id: "810-classics",
            name: "810 Classics",
            description: "MC Breed, Dayton Family & more",
            imageColors: [.purple, .blue],
            icon: "crown.fill",
            songCount: 40
        ),
        CuratedPlaylist(
            id: "michigan-rap",
            name: "Michigan Rap",
            description: "The whole state goes hard",
            imageColors: [.blue, .cyan],
            icon: "music.mic",
            songCount: 75
        ),
        CuratedPlaylist(
            id: "new-810",
            name: "New 810",
            description: "Fresh releases dropping now",
            imageColors: [.green, .mint],
            icon: "sparkles",
            songCount: 25
        ),
        CuratedPlaylist(
            id: "street-certified",
            name: "Street Certified",
            description: "Real street music",
            imageColors: [.gray, .black],
            icon: "bolt.fill",
            songCount: 45
        )
    ]
}

struct RadioStation: Identifiable {
    let id: String
    let name: String
    let description: String
    let color: Color
    let isLive: Bool
    
    static let featuredStations: [RadioStation] = [
        RadioStation(id: "810-radio", name: "810 Radio", description: "810's #1 station", color: .orange, isLive: true),
        RadioStation(id: "810-underground", name: "810 Underground", description: "Independent artists", color: .purple, isLive: true),
        RadioStation(id: "michigan-hits", name: "Michigan Hits", description: "State-wide bangers", color: .blue, isLive: true),
        RadioStation(id: "throwback-810", name: "Throwback 810", description: "Classic 810 hip-hop", color: .red, isLive: false),
        RadioStation(id: "rnb-soul", name: "R&B Soul", description: "Smooth vibes", color: .pink, isLive: true)
    ]
}

struct MusicChart: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let updateFrequency: String
    
    static let allCharts: [MusicChart] = [
        MusicChart(id: "top-50-810", name: "Top 50: 810", icon: "trophy.fill", color: .orange, updateFrequency: "Updated daily"),
        MusicChart(id: "top-100-usa", name: "Top 100: USA", icon: "flag.fill", color: .blue, updateFrequency: "Updated daily"),
        MusicChart(id: "viral-50", name: "Viral 50", icon: "flame.fill", color: .red, updateFrequency: "Updated daily"),
        MusicChart(id: "hip-hop-charts", name: "Hip-Hop Charts", icon: "music.mic", color: .purple, updateFrequency: "Updated weekly"),
        MusicChart(id: "new-releases", name: "New Releases", icon: "sparkles", color: .green, updateFrequency: "Updated Friday")
    ]
}

