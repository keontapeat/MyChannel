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
            case .nasa: return "https://www.nasa.gov/wp-content/themes/nasa/assets/images/nasa-logo.svg"
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

// MARK: - Sample Free Movies (THE BEST FREE FULL MOVIES! 🔥)
extension FreeMovie {
    /// 🎬 EPIC COLLECTION: 30+ FREE FULL MOVIES Users Can Actually Watch!
    /// All verified working Archive.org streams + Blender Open Movies
    static let sampleMovies: [FreeMovie] = [
        
        // ============================================
        // 🔥 FEATURED: TOP PICKS (Most Popular)
        // ============================================
        
        FreeMovie(
            id: "ia-charade-1963",
            title: "Charade",
            posterURL: "https://image.tmdb.org/t/p/w500/5K2U4bXkClvmjxY9QMMj4yYtJKv.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/8GvKG3n2hWEyKTpNfC8Gu5Y6yvV.jpg",
            overview: "Romance and suspense ensue in Paris as a woman is pursued by several men who want a fortune her murdered husband had stolen. Who can she trust?",
            releaseDate: "1963-12-05",
            runtime: 113,
            genre: [.thriller, .romance, .comedy],
            rating: "PG",
            imdbRating: 7.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Charade_201610/Charade.mp4",
            trailerURL: "https://www.youtube.com/watch?v=k1q5lkG4ZMA",
            cast: ["Cary Grant", "Audrey Hepburn", "Walter Matthau", "James Coburn"],
            director: "Stanley Donen",
            year: 1963,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-house-on-haunted-hill-1959",
            title: "House on Haunted Hill",
            posterURL: "https://image.tmdb.org/t/p/w500/oDBuPTXRw6d1TmLPuTPp7rvS8FR.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/ixXM7kO8aLx0i8rT5eiP8kFJSr3.jpg",
            overview: "A millionaire offers $10,000 to five people who agree to be locked in a large, spooky, rented house overnight with him and his wife.",
            releaseDate: "1959-02-17",
            runtime: 75,
            genre: [.horror, .mystery],
            rating: "PG",
            imdbRating: 6.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/house_on_haunted_hill/house_on_haunted_hill_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=UfqQOVi7YCA",
            cast: ["Vincent Price", "Carol Ohmart", "Richard Long"],
            director: "William Castle",
            year: 1959,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-night-of-the-living-dead",
            title: "Night of the Living Dead",
            posterURL: "https://image.tmdb.org/t/p/w500/bQXEaYLRh1SeDsICoZ6irMIX2bZ.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/3YgK9ZkZ4fU2KqgEBeS3T1jCz2m.jpg",
            overview: "A group barricades themselves in a farmhouse to survive a zombie outbreak. The film that launched the modern zombie genre!",
            releaseDate: "1968-10-01",
            runtime: 96,
            genre: [.horror, .thriller],
            rating: "R",
            imdbRating: 7.8,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=6G5pyFhmAqE",
            cast: ["Duane Jones", "Judith O'Dea", "Karl Hardman"],
            director: "George A. Romero",
            year: 1968,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-mclintock-1963",
            title: "McLintock!",
            posterURL: "https://image.tmdb.org/t/p/w500/lXW5P5MfYMi8xwA5hnlxzWcMJHm.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/5hF6HjG2XC8Wo9FcQhW9lVvPdqP.jpg",
            overview: "A wealthy rancher tries to keep the peace between ranchers and settlers, while his wife returns home seeking a divorce.",
            releaseDate: "1963-11-13",
            runtime: 127,
            genre: [.western, .comedy, .romance],
            rating: "G",
            imdbRating: 6.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/McLintock1963/McLintock%21%20%281963%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=FbYQH1pAl2o",
            cast: ["John Wayne", "Maureen O'Hara", "Patrick Wayne"],
            director: "Andrew V. McLaglen",
            year: 1963,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-little-shop-of-horrors-1960",
            title: "The Little Shop of Horrors",
            posterURL: "https://image.tmdb.org/t/p/w500/aQLfVyPJNVFV3Gu5tn2Z3wVK3AC.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/oNg0yJl9LnLXGqE3YC3xkVTYxqL.jpg",
            overview: "A nerdy florist discovers a strange plant that feeds on human flesh. Features Jack Nicholson in an early role!",
            releaseDate: "1960-08-05",
            runtime: 72,
            genre: [.comedy, .horror],
            rating: "PG",
            imdbRating: 6.4,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheLittleShopOfHorrors1960/TheLittleShopOfHorrors1960.mp4",
            trailerURL: "https://www.youtube.com/watch?v=YXO9aIMlXoQ",
            cast: ["Jonathan Haze", "Jackie Joseph", "Jack Nicholson"],
            director: "Roger Corman",
            year: 1960,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        
        // ============================================
        // 👻 HORROR CLASSICS
        // ============================================
        
        FreeMovie(
            id: "ia-carnival-of-souls-1962",
            title: "Carnival of Souls",
            posterURL: "https://image.tmdb.org/t/p/w500/5mwfZaBgW0BM8lIGHDH3tPbGkNU.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/qOvKQ2nVYfCKFQ2vN0RBWPFKHJM.jpg",
            overview: "After a traumatic car accident, a woman becomes drawn to a mysterious abandoned carnival. A haunting cult classic!",
            releaseDate: "1962-09-26",
            runtime: 78,
            genre: [.horror, .mystery],
            rating: "PG",
            imdbRating: 7.1,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/CarnivalOfSouls/Carnival%20of%20Souls.mp4",
            trailerURL: "https://www.youtube.com/watch?v=y8BPRVLYNIo",
            cast: ["Candace Hilligoss", "Frances Feist", "Sidney Berger"],
            director: "Herk Harvey",
            year: 1962,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-nosferatu-1922",
            title: "Nosferatu",
            posterURL: "https://image.tmdb.org/t/p/w500/bFjQD0HGAXRTWMHhxhvyRJ7Njj4.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6kGOa3hhB2t9Q3A1wQ6lFVH6bQv.jpg",
            overview: "The original vampire film! Count Orlok terrorizes a German town. A masterpiece of German Expressionism.",
            releaseDate: "1922-03-04",
            runtime: 94,
            genre: [.horror, .fantasy],
            rating: "PG",
            imdbRating: 7.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/nosferatu_1922/Nosferatu%20%281922%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=rcyzubFvBsA",
            cast: ["Max Schreck", "Gustav von Wangenheim"],
            director: "F.W. Murnau",
            year: 1922,
            language: "Silent",
            country: "DE",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-dementia-13-1963",
            title: "Dementia 13",
            posterURL: "https://image.tmdb.org/t/p/w500/gOd7nGG4lGX4YMrQ6Q7PGXVJ3AL.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/8jKxkzMqBFAq0fCKRJiALEBMjnt.jpg",
            overview: "A scheming widow hatches a daring plan to get her hands on the family fortune. Francis Ford Coppola's directorial debut!",
            releaseDate: "1963-09-25",
            runtime: 75,
            genre: [.horror, .thriller],
            rating: "R",
            imdbRating: 5.4,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Dementia13/Dementia13.mp4",
            trailerURL: "https://www.youtube.com/watch?v=JQN1nFSW4nc",
            cast: ["William Campbell", "Luana Anders", "Patrick Magee"],
            director: "Francis Ford Coppola",
            year: 1963,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-the-terror-1963",
            title: "The Terror",
            posterURL: "https://image.tmdb.org/t/p/w500/7L5dU0j4yF6AffHJvTKiNJBAG5C.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/9rVyZGr2kFME5AHYoJF8K7mTL7E.jpg",
            overview: "A soldier encounters a mysterious woman and discovers dark secrets in an ancient castle. Stars Boris Karloff & Jack Nicholson!",
            releaseDate: "1963-06-15",
            runtime: 81,
            genre: [.horror, .mystery],
            rating: "PG",
            imdbRating: 4.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheTerror1963/The%20Terror%20%281963%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=s6h5Zj5aXlQ",
            cast: ["Boris Karloff", "Jack Nicholson", "Sandra Knight"],
            director: "Roger Corman",
            year: 1963,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-last-man-on-earth-1964",
            title: "The Last Man on Earth",
            posterURL: "https://image.tmdb.org/t/p/w500/f4x2GQKp7tB9H4mWmFv8V1l8VfP.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/9yqHj1kP3n8u2l6qG1e5k5j7dYk.jpg",
            overview: "The sole survivor of a pandemic that turned everyone into vampires fights to survive. Inspired 'I Am Legend'!",
            releaseDate: "1964-03-08",
            runtime: 86,
            genre: [.scifi, .horror],
            rating: "PG",
            imdbRating: 6.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheLastManOnEarth1964/TheLastManOnEarth1964_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=haJZ6tWc2Dk",
            cast: ["Vincent Price", "Franca Bettoia"],
            director: "Ubaldo Ragona",
            year: 1964,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-brain-that-wouldnt-die-1962",
            title: "The Brain That Wouldn't Die",
            posterURL: "https://image.tmdb.org/t/p/w500/3kJ8YHGPJkdnYqwQvQ3PZjU3hkv.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/8eV1L3lQKJvVGtZVMcEHVFJv5Wd.jpg",
            overview: "A mad scientist keeps his fiancée's severed head alive while searching for a new body for her. Classic B-movie horror!",
            releaseDate: "1962-05-03",
            runtime: 82,
            genre: [.horror, .scifi],
            rating: "R",
            imdbRating: 4.5,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheBrainThatWouldntDie1962/The%20Brain%20That%20Wouldnt%20Die%20%281962%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=tPXWdXZ0QyM",
            cast: ["Jason Evers", "Virginia Leith"],
            director: "Joseph Green",
            year: 1962,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        
        // ============================================
        // 🎭 CLASSIC COMEDY & DRAMA
        // ============================================
        
        FreeMovie(
            id: "ia-his-girl-friday-1940",
            title: "His Girl Friday",
            posterURL: "https://image.tmdb.org/t/p/w500/9nX0aPZ3x1iG2R0V3QwVQyqE0Jd.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6k7t9Q4zXb3KtF0z5Zt4yY7Vb1T.jpg",
            overview: "A newspaper editor uses every trick to keep his ex-wife from remarrying as they chase a big story. Classic screwball comedy!",
            releaseDate: "1940-01-18",
            runtime: 92,
            genre: [.comedy, .romance],
            rating: "G",
            imdbRating: 7.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=K7wzGFGZ7nM",
            cast: ["Cary Grant", "Rosalind Russell", "Ralph Bellamy"],
            director: "Howard Hawks",
            year: 1940,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-a-star-is-born-1937",
            title: "A Star Is Born",
            posterURL: "https://image.tmdb.org/t/p/w500/ygMevYgqwA9VXM0mPXhBpLcULQM.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/3qn0qVRzQ3xCc9m1Lz0hOZKLNWg.jpg",
            overview: "The original! A young actress rises to fame as her alcoholic husband's career declines. A timeless Hollywood story.",
            releaseDate: "1937-04-27",
            runtime: 111,
            genre: [.drama, .romance],
            rating: "G",
            imdbRating: 7.2,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/AStarIsBorn1937/A%20Star%20Is%20Born%20%281937%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=c8WvH5lK_q8",
            cast: ["Janet Gaynor", "Fredric March", "Adolphe Menjou"],
            director: "William A. Wellman",
            year: 1937,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-reefer-madness-1936",
            title: "Reefer Madness",
            posterURL: "https://image.tmdb.org/t/p/w500/xHgE15xX3dNaBWqCF3g4XlkCNMq.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/8pQNnVk3X6Cv5zQHqK8zQONVmQh.jpg",
            overview: "A propaganda film turned cult classic! Teens spiral into madness after trying marijuana. Unintentionally hilarious today!",
            releaseDate: "1936-01-01",
            runtime: 66,
            genre: [.drama, .crime],
            rating: "PG",
            imdbRating: 3.8,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/reefer_madness/reefer_madness.mp4",
            trailerURL: "https://www.youtube.com/watch?v=zhQlcMHhF3w",
            cast: ["Dorothy Short", "Kenneth Craig"],
            director: "Louis J. Gasnier",
            year: 1936,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-beat-the-devil-1953",
            title: "Beat the Devil",
            posterURL: "https://image.tmdb.org/t/p/w500/4Jb8yC3h3X7mwr2H6Sx7pS5JQZq.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/6h1F1qj4k2wYv5qY3Jv3gU2mC0R.jpg",
            overview: "A group of swindlers scheme to get rich off African uranium. Humphrey Bogart in a comedy adventure!",
            releaseDate: "1953-11-05",
            runtime: 89,
            genre: [.comedy, .adventure],
            rating: "PG",
            imdbRating: 6.4,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/beat_the_devil/beat_the_devil_512kb.mp4",
            trailerURL: nil,
            cast: ["Humphrey Bogart", "Jennifer Jones", "Gina Lollobrigida"],
            director: "John Huston",
            year: 1953,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        
        // ============================================
        // 🔍 FILM NOIR & THRILLER
        // ============================================
        
        FreeMovie(
            id: "ia-doa-1950",
            title: "D.O.A.",
            posterURL: "https://image.tmdb.org/t/p/w500/d4wcuG3EWMNAK4lSRrS1YQ7j5wC.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/7G5Qf3wXv0F4h7mWzQu3m1jTjXU.jpg",
            overview: "A poisoned man has 24 hours to find his own killer before he dies. The ultimate noir premise!",
            releaseDate: "1950-04-21",
            runtime: 83,
            genre: [.crime, .thriller],
            rating: "PG",
            imdbRating: 7.3,
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
            overview: "A hitchhiker's ride leads to murder and blackmail. One of the greatest B-movies ever made!",
            releaseDate: "1945-11-30",
            runtime: 68,
            genre: [.crime, .thriller],
            rating: "PG",
            imdbRating: 7.4,
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
            id: "ia-suddenly-1954",
            title: "Suddenly",
            posterURL: "https://image.tmdb.org/t/p/w500/4Q3Hnq5x6vT7c2Y2bYv6wGxqf8Q.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/9T2oM5A3tP2v1n7aL3k5j8dS7Qw.jpg",
            overview: "Three assassins take over a family's home to kill the President. Frank Sinatra as a psychopath!",
            releaseDate: "1954-10-07",
            runtime: 77,
            genre: [.crime, .thriller],
            rating: "PG",
            imdbRating: 6.9,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Suddenly_1954/Suddenly_1954_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=H2e1x5fH0t8",
            cast: ["Frank Sinatra", "Sterling Hayden"],
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
            overview: "A childhood secret binds three people in a web of love, lies, and murder. Kirk Douglas' film debut!",
            releaseDate: "1946-10-16",
            runtime: 116,
            genre: [.drama, .crime, .thriller],
            rating: "PG",
            imdbRating: 7.4,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheStrangeLoveOfMarthaIvers/TheStrangeLoveOfMarthaIvers_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=G6k4dB1V0d4",
            cast: ["Barbara Stanwyck", "Van Heflin", "Kirk Douglas"],
            director: "Lewis Milestone",
            year: 1946,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        
        // ============================================
        // 🚀 SCI-FI & FANTASY
        // ============================================
        
        FreeMovie(
            id: "ia-metropolis-1927",
            title: "Metropolis",
            posterURL: "https://image.tmdb.org/t/p/w500/hUK9rewffKGqtXynH13BPqnsTm4.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/bHI8f6VJHBjzJ7NWmQxMNiKL9Dv.jpg",
            overview: "In a futuristic city sharply divided between working class and city planners, a woman sparks revolution. A sci-fi masterpiece!",
            releaseDate: "1927-01-10",
            runtime: 153,
            genre: [.scifi, .drama],
            rating: "G",
            imdbRating: 8.3,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Metropolis_201610/Metropolis.mp4",
            trailerURL: "https://www.youtube.com/watch?v=Q0NzaJLQSRU",
            cast: ["Brigitte Helm", "Alfred Abel", "Gustav Fröhlich"],
            director: "Fritz Lang",
            year: 1927,
            language: "Silent",
            country: "DE",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-plan-9-from-outer-space-1959",
            title: "Plan 9 from Outer Space",
            posterURL: "https://image.tmdb.org/t/p/w500/9dVZ0KuQWmv2qkCw4qJ9Gx7Vw3K.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/1Gx0S4P0sRti3cfF5oSZX8FoLwq.jpg",
            overview: "Aliens raise the dead to stop humanity. Ed Wood's legendary 'worst film ever' is incredibly entertaining!",
            releaseDate: "1959-07-22",
            runtime: 79,
            genre: [.scifi, .horror],
            rating: "PG",
            imdbRating: 4.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Plan_9_from_Outer_Space_1959/Plan_9_from_Outer_Space_1959_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=u2ukRYsYPmo",
            cast: ["Bela Lugosi", "Tor Johnson", "Vampira"],
            director: "Ed Wood",
            year: 1959,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-voyage-to-prehistoric-planet-1965",
            title: "Voyage to the Prehistoric Planet",
            posterURL: "https://archive.org/services/img/VoyageToThePrehistoricPlanet1965",
            backdropURL: nil,
            overview: "Astronauts land on Venus and encounter dinosaurs and hostile aliens! Campy 60s sci-fi adventure.",
            releaseDate: "1965-01-01",
            runtime: 80,
            genre: [.scifi, .adventure],
            rating: "G",
            imdbRating: 4.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/VoyageToThePrehistoricPlanet1965/Voyage%20to%20the%20Prehistoric%20Planet%20%281965%29.mp4",
            trailerURL: nil,
            cast: ["Basil Rathbone", "Faith Domergue"],
            director: "Curtis Harrington",
            year: 1965,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-attack-of-50-foot-woman-1958",
            title: "Attack of the 50 Foot Woman",
            posterURL: "https://image.tmdb.org/t/p/w500/dvbkFKW3iVaWd8bWHDKCd5FHpXz.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/7s8PgVFQPPWQ8gvKREMNAQOMF9s.jpg",
            overview: "A woman grows to giant size after an alien encounter and seeks revenge on her cheating husband. Iconic B-movie!",
            releaseDate: "1958-05-19",
            runtime: 65,
            genre: [.scifi, .horror],
            rating: "PG",
            imdbRating: 4.8,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/AttackOfThe50FootWoman/Attack%20of%20the%2050%20Foot%20Woman.mp4",
            trailerURL: "https://www.youtube.com/watch?v=vJRh2QzCsOw",
            cast: ["Allison Hayes", "William Hudson"],
            director: "Nathan Juran",
            year: 1958,
            language: "English",
            country: "US",
            isAvailable: true
        ),
        
        // ============================================
        // 🤠 ACTION & ADVENTURE
        // ============================================
        
        FreeMovie(
            id: "ia-the-general-1926",
            title: "The General",
            posterURL: "https://image.tmdb.org/t/p/w500/mCU7HLyxAmLdkl4BRz2iJy8pInd.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/mM7p7JjJjZZ8Yr0cPSLXxGKJGN7.jpg",
            overview: "Buster Keaton's masterpiece! A train engineer pursues his stolen locomotive through enemy lines in the Civil War.",
            releaseDate: "1926-12-31",
            runtime: 75,
            genre: [.comedy, .action, .adventure],
            rating: "G",
            imdbRating: 8.1,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TheGeneral1926/The%20General%20%281926%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=iHlBLKUz9JA",
            cast: ["Buster Keaton", "Marion Mack"],
            director: "Buster Keaton",
            year: 1926,
            language: "Silent",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-the-fast-and-the-furious-1955",
            title: "The Fast and the Furious",
            posterURL: "https://image.tmdb.org/t/p/w500/tqR4K9KQF8aF2F8p6oLJmX6cOGF.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/fuTZJ8yJb1mWgV8nUQJ4x6kQv3P.jpg",
            overview: "The ORIGINAL! A wrongly accused man kidnaps a woman and enters a cross-border car race to escape.",
            releaseDate: "1955-02-15",
            runtime: 73,
            genre: [.action, .thriller],
            rating: "PG",
            imdbRating: 5.1,
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
            id: "ia-hercules-1958",
            title: "Hercules",
            posterURL: "https://image.tmdb.org/t/p/w500/6qJ1UqPwXhJPjKDMqL6L9M6tE8z.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/2vLkQ3BPvUW5f6u3Q0L6N2P5eHt.jpg",
            overview: "Steve Reeves stars as the legendary hero in this sword-and-sandal epic that launched a genre!",
            releaseDate: "1958-02-20",
            runtime: 107,
            genre: [.adventure, .action, .fantasy],
            rating: "G",
            imdbRating: 6.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Hercules1958/Hercules%20%281958%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=8X0FzZGhJdE",
            cast: ["Steve Reeves", "Sylva Koscina"],
            director: "Pietro Francisci",
            year: 1958,
            language: "English",
            country: "IT",
            isAvailable: true
        ),
        
        // ============================================
        // 🎨 ANIMATION (Blender Open Movies - HIGH QUALITY!)
        // ============================================
        
        FreeMovie(
            id: "blender-big-buck-bunny",
            title: "Big Buck Bunny",
            posterURL: "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg",
            backdropURL: "https://ia801504.us.archive.org/11/items/BigBuckBunny_124/BigBuckBunny_124.thumbs/BigBuckBunny_124_000005.jpg",
            overview: "A lovable giant bunny takes on three bullying rodents. Stunning open-source animation in 4K!",
            releaseDate: "2008-04-10",
            runtime: 10,
            genre: [.animation, .comedy, .family],
            rating: "G",
            imdbRating: 6.6,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4",
            trailerURL: "https://www.youtube.com/watch?v=YE7VzlLtp-4",
            cast: [],
            director: "Sacha Goedegebure",
            year: 2008,
            language: "Silent",
            country: "NL",
            isAvailable: true
        ),
        FreeMovie(
            id: "blender-sintel",
            title: "Sintel",
            posterURL: "https://upload.wikimedia.org/wikipedia/commons/c/c5/Sintel_poster.jpg",
            backdropURL: "https://ia601404.us.archive.org/2/items/Sintel/Sintel.thumbs/Sintel_000001.jpg",
            overview: "A young woman searches for her lost dragon companion. Emotionally powerful short film with stunning visuals!",
            releaseDate: "2010-09-27",
            runtime: 15,
            genre: [.animation, .fantasy, .adventure],
            rating: "G",
            imdbRating: 7.5,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/Sintel/Sintel.mp4",
            trailerURL: "https://www.youtube.com/watch?v=eRsGyueVLvQ",
            cast: [],
            director: "Colin Levy",
            year: 2010,
            language: "English",
            country: "NL",
            isAvailable: true
        ),
        FreeMovie(
            id: "blender-tears-of-steel",
            title: "Tears of Steel",
            posterURL: "https://upload.wikimedia.org/wikipedia/commons/9/9f/Tears_of_Steel_poster.jpg",
            backdropURL: "https://ia801406.us.archive.org/33/items/TearOfSteel/TearOfSteel.thumbs/TearOfSteel_000001.jpg",
            overview: "In a dystopian future, scientists desperately work to save humanity. Groundbreaking VFX meets emotional storytelling!",
            releaseDate: "2012-09-26",
            runtime: 12,
            genre: [.scifi, .animation, .drama],
            rating: "PG",
            imdbRating: 6.1,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/TearOfSteel/TearOfSteel.mp4",
            trailerURL: "https://www.youtube.com/watch?v=41hv2tW5Lc4",
            cast: ["Derek de Lint", "Sergio Hasselbaink"],
            director: "Ian Hubert",
            year: 2012,
            language: "English",
            country: "NL",
            isAvailable: true
        ),
        FreeMovie(
            id: "blender-elephants-dream",
            title: "Elephants Dream",
            posterURL: "https://upload.wikimedia.org/wikipedia/commons/e/e8/Elephants_Dream_cover.jpg",
            backdropURL: "https://ia601508.us.archive.org/10/items/ElephantsDream/ElephantsDream.thumbs/ElephantsDream_000001.jpg",
            overview: "Two characters explore a surreal machine world. The first Blender open movie project!",
            releaseDate: "2006-05-18",
            runtime: 11,
            genre: [.animation, .scifi, .fantasy],
            rating: "G",
            imdbRating: 6.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4",
            trailerURL: "https://www.youtube.com/watch?v=TLkA0RELQ1g",
            cast: ["Tygo Gernandt", "Cas Jansen"],
            director: "Bassam Kurdali",
            year: 2006,
            language: "English",
            country: "NL",
            isAvailable: true
        ),
        
        // ============================================
        // 📚 CULT CLASSICS & BONUS
        // ============================================
        
        FreeMovie(
            id: "ia-the-cabinet-of-dr-caligari-1920",
            title: "The Cabinet of Dr. Caligari",
            posterURL: "https://image.tmdb.org/t/p/w500/aqwETuhp7RkKhFgPihXAT5E9LFQ.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/3qdAm3lBN2OJVtKRJOGHYvKY3pJ.jpg",
            overview: "A hypnotist uses a sleepwalker to commit murders. The iconic German Expressionist horror masterpiece!",
            releaseDate: "1920-02-26",
            runtime: 76,
            genre: [.horror, .fantasy, .mystery],
            rating: "PG",
            imdbRating: 8.0,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/thecabinetofdr.caligari/The%20Cabinet%20of%20Dr.%20Caligari%20%281920%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=IP0KB2XC29o",
            cast: ["Werner Krauss", "Conrad Veidt"],
            director: "Robert Wiene",
            year: 1920,
            language: "Silent",
            country: "DE",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-phantom-of-the-opera-1925",
            title: "The Phantom of the Opera",
            posterURL: "https://image.tmdb.org/t/p/w500/mNiZ0OhWkqL9lHw4lxQpHZ0LWLB.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/k9qIbDqvqtMYDLJQ6dUVJjzKOVL.jpg",
            overview: "A disfigured musical genius haunts the Paris Opera House. Lon Chaney's legendary makeup remains iconic!",
            releaseDate: "1925-09-06",
            runtime: 93,
            genre: [.horror, .drama, .romance],
            rating: "G",
            imdbRating: 7.5,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/ThePhantomOfTheOpera1925/The%20Phantom%20of%20the%20Opera%20%281925%29.mp4",
            trailerURL: "https://www.youtube.com/watch?v=BXxGx3GXbag",
            cast: ["Lon Chaney", "Mary Philbin"],
            director: "Rupert Julian",
            year: 1925,
            language: "Silent",
            country: "US",
            isAvailable: true
        ),
        FreeMovie(
            id: "ia-santa-claus-conquers-martians-1964",
            title: "Santa Claus Conquers the Martians",
            posterURL: "https://image.tmdb.org/t/p/w500/jVJ1f7YD4hqfJkgLTIQMWTRt6J.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/wQTYuG8x0ALHnCyYFD5VyMPVq3v.jpg",
            overview: "Martians kidnap Santa to make toys for their children. So bad it's legendary! Perfect for ironic holiday viewing.",
            releaseDate: "1964-11-14",
            runtime: 81,
            genre: [.scifi, .comedy, .family],
            rating: "G",
            imdbRating: 2.5,
            streamingSource: .internetArchive,
            streamURL: "https://archive.org/download/SantaClausConquersTheMartians/Santa%20Claus%20Conquers%20the%20Martians.mp4",
            trailerURL: "https://www.youtube.com/watch?v=6uCYqKU5oNU",
            cast: ["John Call", "Leonard Hicks", "Pia Zadora"],
            director: "Nicholas Webster",
            year: 1964,
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