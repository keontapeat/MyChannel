import SwiftUI
import Foundation

enum MoviePlaybackResolver {
    static func directPlayableURL(for movie: FreeMovie) -> URL? {
        if let url = URL(string: movie.streamURL),
           ["mp4", "m3u8"].contains(url.pathExtension.lowercased()) {
            return url
        }
        if let mapped = directStreamURL(for: movie) {
            return mapped
        }
        return nil
    }

    static func videoIfDirect(from movie: FreeMovie, creator: User = User.defaultUser) -> Video? {
        guard let url = directPlayableURL(for: movie) else { return nil }
        let tags = movie.genre.map { $0.rawValue }
        return Video(
            title: movie.title,
            description: movie.overview,
            thumbnailURL: movie.posterURL,
            videoURL: url.absoluteString,
            duration: TimeInterval(max(60, movie.runtime * 60)),
            viewCount: Int.random(in: 50_000...2_000_000),
            likeCount: Int.random(in: 5_000...200_000),
            creator: creator,
            category: .movies,
            tags: tags,
            isPublic: true,
            quality: [.quality720p, .quality1080p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .archive,
            contentRating: ratingFromString(movie.rating),
            language: movie.language,
            isVerified: true
        )
    }

    static func video(from movie: FreeMovie, creator: User = User.defaultUser) -> Video {
        let playableURL = directPlayableURL(for: movie) ?? fallbackURL(for: movie)
        let tags = movie.genre.map { $0.rawValue }
        return Video(
            title: movie.title,
            description: movie.overview,
            thumbnailURL: movie.posterURL,
            videoURL: playableURL.absoluteString,
            duration: TimeInterval(max(60, movie.runtime * 60)),
            viewCount: Int.random(in: 50_000...2_000_000),
            likeCount: Int.random(in: 5_000...200_000),
            creator: creator,
            category: .movies,
            tags: tags,
            isPublic: true,
            quality: [.quality720p, .quality1080p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .archive,
            contentRating: ratingFromString(movie.rating),
            language: movie.language,
            isVerified: true
        )
    }

    private static func ratingFromString(_ rating: String) -> Video.ContentRating? {
        switch rating.uppercased() {
        case "G": return .G
        case "PG": return .PG
        case "PG-13", "PG13": return .PG13
        case "R": return .R
        case "NC-17", "NC17": return .NC17
        default: return nil
        }
    }

    private static func directStreamURL(for movie: FreeMovie) -> URL? {
        let id = movie.id.lowercased()

        if id.contains("ia-night-of-the-living-dead") {
            return URL(string: "https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4")
        }
        if id.contains("ia-plan-9-from-outer-space-1959") {
            return URL(string: "https://archive.org/download/Plan_9_from_Outer_Space_1959/Plan_9_from_Outer_Space_1959_512kb.mp4")
        }
        if id.contains("ia-his-girl-friday-1940") {
            return URL(string: "https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4")
        }
        if id.contains("ia-doa-1950") {
            return URL(string: "https://archive.org/download/DOA_1950/DOA_512kb.mp4")
        }
        if id.contains("ia-detour-1945") {
            return URL(string: "https://archive.org/download/Detour1945/Detour_512kb.mp4")
        }
        if id.contains("ia-the-fast-and-the-furious-1955") {
            return URL(string: "https://archive.org/download/TheFastAndTheFurious_1955/TheFastAndTheFurious_1955_512kb.mp4")
        }
        if id.contains("ia-last-man-on-earth-1964") {
            return URL(string: "https://archive.org/download/TheLastManOnEarth1964/TheLastManOnEarth1964_512kb.mp4")
        }
        if id.contains("ia-suddenly-1954") {
            return URL(string: "https://archive.org/download/Suddenly_1954/Suddenly_1954_512kb.mp4")
        }
        if id.contains("ia-strange-love-of-martha-ivers-1946") {
            return URL(string: "https://archive.org/download/TheStrangeLoveOfMarthaIvers/TheStrangeLoveOfMarthaIvers_512kb.mp4")
        }
        if id.contains("ia-beat-the-devil-1953") {
            return URL(string: "https://archive.org/download/beat_the_devil/beat_the_devil_512kb.mp4")
        }

        return nil
    }

    // Stable demo fallbacks (never used by the Play button in MovieDetailView)
    private static func fallbackURL(for movie: FreeMovie) -> URL {
        let candidates = [
            "https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
        ]
        return URL(string: candidates.absHash(movie.id)!)!
    }
}

// Small helper to deterministically pick a fallback URL
private extension Array where Element == String {
    func absHash(_ key: String) -> String? {
        guard !isEmpty else { return nil }
        let idx = abs(key.hashValue) % count
        return self[idx]
    }
}