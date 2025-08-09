import SwiftUI
import Foundation

// MARK: - Free Movie Model
struct FreeMovie: Identifiable, Codable {
    let id: String
    let title: String
    let posterURL: String
    let backdropURL: String?
    let overview: String
    let releaseDate: String
    let runtime: Int
    let genre: [MovieGenre]
    let rating: String
    let imdbRating: Double
    let streamingSource: StreamingSource
    let streamURL: String
    let trailerURL: String?
    let cast: [String]
    let director: String
    let year: Int
    let language: String
    let country: String
    let isAvailable: Bool
    
    enum StreamingSource: String, CaseIterable, Codable {
        case tubi = "tubi"
        case plexFree = "plex_free"
        case crackle = "crackle"
        case rokuChannel = "roku_channel"
        case internetArchive = "internet_archive"
        case imdbTV = "imdb_tv"
        case youtube = "youtube"
        
        var displayName: String {
            switch self {
            case .tubi: return "Tubi"
            case .plexFree: return "Plex"
            case .crackle: return "Crackle"
            case .rokuChannel: return "Roku Channel"
            case .internetArchive: return "Internet Archive"
            case .imdbTV: return "IMDb TV"
            case .youtube: return "YouTube Movies"
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
            }
        }
    }
    
    enum MovieGenre: String, CaseIterable, Codable {
        case action = "action"
        case comedy = "comedy"
        case drama = "drama"
        case horror = "horror"
        case thriller = "thriller"
        case romance = "romance"
        case scifi = "sci-fi"
        case fantasy = "fantasy"
        case documentary = "documentary"
        case animation = "animation"
        case crime = "crime"
        case mystery = "mystery"
        case adventure = "adventure"
        case family = "family"
        case western = "western"
        case war = "war"
        case musical = "musical"
        case biography = "biography"
        
        var displayName: String {
            switch self {
            case .action: return "🎬 Action"
            case .comedy: return "😂 Comedy"
            case .drama: return "🎭 Drama"
            case .horror: return "👻 Horror"
            case .thriller: return "😱 Thriller"
            case .romance: return "💕 Romance"
            case .scifi: return "🚀 Sci-Fi"
            case .fantasy: return "🧙‍♂️ Fantasy"
            case .documentary: return "📽️ Documentary"
            case .animation: return "🎨 Animation"
            case .crime: return "🔍 Crime"
            case .mystery: return "🕵️ Mystery"
            case .adventure: return "🗺️ Adventure"
            case .family: return "👨‍👩‍👧‍👦 Family"
            case .western: return "🤠 Western"
            case .war: return "⚔️ War"
            case .musical: return "🎵 Musical"
            case .biography: return "📚 Biography"
            }
        }
    }
    
    var formattedRuntime: String {
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var genreString: String {
        genre.map { $0.rawValue.capitalized }.joined(separator: ", ")
    }
}

// MARK: - Sample Free Movies
extension FreeMovie {
    static let sampleMovies: [FreeMovie] = [
        FreeMovie(
            id: "ia-night-of-the-living-dead",
            title: "Night of the Living Dead",
            posterURL: "https://image.tmdb.org/t/p/w500/bQXEaYLRh1SeDsICoZ6irMIX2bZ.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/3YgK9ZkZ4fU2KqgEBeS3T1jCz2m.jpg",
            overview: "A group barricades themselves in a farmhouse to survive a zombie outbreak.",
            releaseDate: "1968-10-01",
            runtime: 96,
            genre: [.horror, .thriller],
            rating: "Unrated",
            imdbRating: 7.8,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=6G5pyFhmAqE",
            cast: ["Duane Jones", "Judith O'Dea"],
            director: "George A. Romero",
            year: 1968,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-plan-9-from-outer-space-1959",
            title: "Plan 9 from Outer Space",
            posterURL: "https://image.tmdb.org/t/p/w500/9dVZ0KuQWmv2qkCw4qJ9Gx7Vw3K.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/1Gx0S4P0sRti3cfF5oSZX8FoLwq.jpg",
            overview: "Aliens implement 'Plan 9' to raise the dead and stop humanity from creating a doomsday weapon.",
            releaseDate: "1959-07-22",
            runtime: 79,
            genre: [.scifi, .fantasy],
            rating: "Unrated",
            imdbRating: 4.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Plan_9_from_Outer_Space_1959/Plan_9_from_Outer_Space_1959_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=u2ukRYsYPmo",
            cast: ["Bela Lugosi", "Maila Nurmi"],
            director: "Ed Wood",
            year: 1959,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-his-girl-friday-1940",
            title: "His Girl Friday",
            posterURL: "https://image.tmdb.org/t/p/w500/9nX0aPZ3x1iG2R0V3QwVQyqE0Jd.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6k7t9Q4zXb3KtF0z5Zt4yY7Vb1T.jpg",
            overview: "A newspaper editor uses every trick to keep his ex-wife from remarrying as they chase a big story.",
            releaseDate: "1940-01-18",
            runtime: 92,
            genre: [.comedy, .romance],
            rating: "Unrated",
            imdbRating: 7.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=K7wzGFGZ7nM",
            cast: ["Cary Grant", "Rosalind Russell"],
            director: "Howard Hawks",
            year: 1940,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-doa-1950",
            title: "D.O.A.",
            posterURL: "https://image.tmdb.org/t/p/w500/d4wcuG3EWMNAK4lSRrS1YQ7j5wC.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/7G5Qf3wXv0F4h7mWzQu3m1jTjXU.jpg",
            overview: "A poisoned man must find his killer before he dies.",
            releaseDate: "1950-04-21",
            runtime: 83,
            genre: [.crime, .thriller],
            rating: "Unrated",
            imdbRating: 7.1,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/DOA_1950/DOA_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=V9dQ0C6pYt4",
            cast: ["Edmond O'Brien", "Pamela Britton"],
            director: "Rudolph Maté",
            year: 1950,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-detour-1945",
            title: "Detour",
            posterURL: "https://image.tmdb.org/t/p/w500/8mF9QYz9QK4bJ3j6Rr7x9c3ZxJd.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/3qF3W6g3t7i2n0jV3QfG1wXq9Uy.jpg",
            overview: "A down-on-his-luck pianist hitches a ride that leads to murder and double-crosses.",
            releaseDate: "1945-11-30",
            runtime: 68,
            genre: [.crime, .thriller],
            rating: "Unrated",
            imdbRating: 7.2,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Detour1945/Detour_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=8rj2sQXGQ9k",
            cast: ["Tom Neal", "Ann Savage"],
            director: "Edgar G. Ulmer",
            year: 1945,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-the-fast-and-the-furious-1955",
            title: "The Fast and the Furious",
            posterURL: "https://image.tmdb.org/t/p/w500/tqR4K9KQF8aF2F8p6oLJmX6cOGF.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/fuTZJ8yJb1mWgV8nUQJ4x6kQv3P.jpg",
            overview: "A man wrongfully accused of murder escapes custody and enters a cross-border car race.",
            releaseDate: "1955-02-15",
            runtime: 73,
            genre: [.action, .thriller],
            rating: "Unrated",
            imdbRating: 4.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheFastAndTheFurious_1955/TheFastAndTheFurious_1955_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=hsQyDSmJ46c",
            cast: ["John Ireland", "Dorothy Malone"],
            director: "John Ireland",
            year: 1955,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-last-man-on-earth-1964",
            title: "The Last Man on Earth",
            posterURL: "https://image.tmdb.org/t/p/w500/f4x2GQKp7tB9H4mWmFv8V1l8VfP.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/9yqHj1kP3n8u2l6qG1e5k5j7dYk.jpg",
            overview: "A lone survivor of a global plague fights off the infected.",
            releaseDate: "1964-03-08",
            runtime: 86,
            genre: [.scifi, .horror],
            rating: "Unrated",
            imdbRating: 6.7,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheLastManOnEarth1964/TheLastManOnEarth1964_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=haJZ6tWc2Dk",
            cast: ["Vincent Price"],
            director: "Ubaldo Ragona",
            year: 1964,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-suddenly-1954",
            title: "Suddenly",
            posterURL: "https://image.tmdb.org/t/p/w500/4Q3Hnq5x6vT7c2Y2bYv6wGxqf8Q.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/9T2oM5A3tP2v1n7aL3k5j8dS7Qw.jpg",
            overview: "Three assassins take over a family's home to kill the President.",
            releaseDate: "1954-10-07",
            runtime: 77,
            genre: [.crime, .thriller],
            rating: "Unrated",
            imdbRating: 6.7,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Suddenly_1954/Suddenly_1954_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=H2e1x5fH0t8",
            cast: ["Frank Sinatra"],
            director: "Lewis Allen",
            year: 1954,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-strange-love-of-martha-ivers-1946",
            title: "The Strange Love of Martha Ivers",
            posterURL: "https://image.tmdb.org/t/p/w500/9QhV2jV1oZb0HqM7mXkV8qY4VhL.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/8m3l8sYx9fT6jQwV7k1f5h2p3nD.jpg",
            overview: "A complicated web of love and lies ensnares three people.",
            releaseDate: "1946-10-16",
            runtime: 116,
            genre: [.drama, .crime],
            rating: "Unrated",
            imdbRating: 7.2,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheStrangeLoveOfMarthaIvers/TheStrangeLoveOfMarthaIvers_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=G6k4dB1V0d4",
            cast: ["Barbara Stanwyck", "Kirk Douglas"],
            director: "Lewis Milestone",
            year: 1946,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-beat-the-devil-1953",
            title: "Beat the Devil",
            posterURL: "https://image.tmdb.org/t/p/w500/4Jb8yC3h3X7mwr2H6Sx7pS5JQZq.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6h1F1qj4k2wYv5qY3Jv3gU2mC0R.jpg",
            overview: "A group of swindlers scheme to get rich off African uranium.",
            releaseDate: "1953-11-05",
            runtime: 89,
            genre: [.comedy, .adventure],
            rating: "Unrated",
            imdbRating: 6.4,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/beat_the_devil/beat_the_devil_512kb.mp4",
            trailerURL: nil,
            cast: ["Humphrey Bogart", "Jennifer Jones"],
            director: "John Huston",
            year: 1953,
            language: "English",
            country: "US",
            isAvailable: true
        )
    ]
}

// MARK: - Multi-source poster fallbacks
extension FreeMovie {
    var archiveIdentifier: String? {
        if id.hasPrefix("ia-") {
            return String(id.dropFirst(3))
        }
        if let range = streamURL.range(of: "/download/") {
            let rest = streamURL[range.upperBound...]
            if let slash = rest.firstIndex(of: "/") {
                return String(rest[..<slash])
            } else {
                return String(rest)
            }
        }
        return nil
    }
    
    var posterCandidates: [URL] {
        var urls: [URL] = []
        
        if !posterURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let u = URL(string: posterURL) {
            urls.append(u)
        }
        
        if let ia = archiveIdentifier,
           let u = URL(string: "https://archive.org/services/img/\(ia)") {
            urls.append(u)
        }
        
        if let t = trailerURL,
           let vid = Self.youtubeID(from: t),
           let u = URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg") {
            urls.append(u)
        }
        
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
    
    private static func youtubeID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.contains("youtu.be") == true {
            return url.lastPathComponent
        }
        if url.host?.contains("youtube.com") == true {
            if let query = url.query {
                for pair in query.components(separatedBy: "&") {
                    let kv = pair.components(separatedBy: "=")
                    if kv.count == 2, kv[0] == "v" { return kv[1] }
                }
            }
            let comps = url.pathComponents
            if let idx = comps.firstIndex(of: "embed"), idx + 1 < comps.count {
                return comps[idx + 1]
            }
        }
        return nil
    }
}

#Preview {
    VStack {
        ForEach(FreeMovie.sampleMovies.prefix(2)) { movie in
            HStack {
                AsyncImage(url: URL(string: movie.posterURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle().fill(.gray)
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                    Text(movie.streamingSource.displayName)
                        .font(.caption)
                        .foregroundColor(movie.streamingSource.color)
                    Text("⭐ \(movie.imdbRating, specifier: "%.1f")")
                        .font(.caption)
                }
                Spacer()
            }
            .padding()
        }
    }
}