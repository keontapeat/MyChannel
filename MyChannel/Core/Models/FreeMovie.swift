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
    let rating: String // PG, PG-13, R, etc.
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
        // Tubi Movies
        FreeMovie(
            id: "tubi-john-wick",
            title: "John Wick",
            posterURL: "https://image.tmdb.org/t/p/w500/fZPSd91yGE9fCcCe6OoQr6E3Bev.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/umC04Cozevu8nn3JTDJ1pc7PVTn.jpg",
            overview: "An ex-hit-man comes out of retirement to track down the gangsters that took everything from him.",
            releaseDate: "2014-10-24",
            runtime: 101,
            genre: [.action, .thriller, .crime],
            rating: "R",
            imdbRating: 7.4,
            streamingSource: .tubi,
            streamURL: "https://tubitv.com/movies/312005/john_wick",
            trailerURL: "https://www.youtube.com/watch?v=C0BMx-qxsP4",
            cast: ["Keanu Reeves", "Michael Nyqvist", "Alfie Allen"],
            director: "Chad Stahelski",
            year: 2014,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "plex-the-matrix",
            title: "The Matrix",
            posterURL: "https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/icmmSD4vTTDKOq2vvdulafOGw93.jpg",
            overview: "A computer hacker learns from mysterious rebels about the true nature of his reality.",
            releaseDate: "1999-03-31",
            runtime: 136,
            genre: [.action, .scifi, .thriller],
            rating: "R",
            imdbRating: 8.7,
            streamingSource: .plexFree,
            streamURL: "https://watch.plex.tv/movie/the-matrix",
            trailerURL: "https://www.youtube.com/watch?v=vKQi3bBA1y8",
            cast: ["Keanu Reeves", "Laurence Fishburne", "Carrie-Anne Moss"],
            director: "The Wachowskis",
            year: 1999,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "crackle-the-karate-kid",
            title: "The Karate Kid",
            posterURL: "https://image.tmdb.org/t/p/w500/jkTnTMhTjdnNMoF7VlFhWJr6aYw.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6Ezme5ceRJ2iB2Lz8F4nxLHgxgj.jpg",
            overview: "A martial arts master agrees to teach karate to a bullied teenager.",
            releaseDate: "1984-06-22",
            runtime: 126,
            genre: [.drama, .family, .action],
            rating: "PG",
            imdbRating: 7.3,
            streamingSource: .crackle,
            streamURL: "https://www.crackle.com/watch/the-karate-kid",
            trailerURL: "https://www.youtube.com/watch?v=r40JL3hcBSE",
            cast: ["Ralph Macchio", "Pat Morita", "Elisabeth Shue"],
            director: "John G. Avildsen",
            year: 1984,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "internet-archive-night-of-living-dead",
            title: "Night of the Living Dead",
            posterURL: "https://image.tmdb.org/t/p/w500/inNUOa9WZGdyRXQlt7eqmHtCttl.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/5P1z9j8P1G8Q6G0FVP0x3SJJLFj.jpg",
            overview: "A ragtag group of Pennsylvanians barricade themselves in an old farmhouse to remain safe from bloodthirsty zombies.",
            releaseDate: "1968-10-01",
            runtime: 96,
            genre: [.horror, .thriller],
            rating: "Unrated",
            imdbRating: 7.8,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/details/night_of_the_living_dead",
            trailerURL: "https://www.youtube.com/watch?v=6G5pyFhmAqE",
            cast: ["Duane Jones", "Judith O'Dea", "Karl Hardman"],
            director: "George A. Romero",
            year: 1968,
            language: "English",
            country: "US",
            isAvailable: true
        )
    ]
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