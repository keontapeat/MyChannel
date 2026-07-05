import SwiftUI
import Foundation

enum MoviePlaybackResolver {
    /// Deterministic, stable Video id for a movie so that watch progress,
    /// continue-watching and history map to the SAME document across launches
    /// (Firestore `watch_progress/{userId}_{videoId}`). Without this, each play
    /// created a random UUID and resume/continue-watching never worked.
    static func stableVideoID(for movie: FreeMovie) -> String {
        "movie-\(movie.id)"
    }

    /// Recover the originating FreeMovie.id from a stable Video id.
    static func movieID(fromVideoID videoID: String) -> String? {
        videoID.hasPrefix("movie-") ? String(videoID.dropFirst("movie-".count)) : nil
    }

    static func directPlayableURL(for movie: FreeMovie) -> URL? {
        if let url = URL(string: movie.streamURL),
           ["mp4", "m3u8"].contains(url.pathExtension.lowercased()),
           !isTrailerURL(url) {
            return url
        }
        if let mapped = directStreamURL(for: movie) {
            return mapped
        }
        return nil
    }

    /// A "…Trailer…" archive asset is only a preview, not the full film (this is
    /// all that legally exists for the copyrighted studio titles in our catalog).
    /// Treat it as a trailer, never as a full stream, so the UI never falsely
    /// advertises "Play Now" for a 2-minute trailer.
    static func isTrailerURL(_ url: URL) -> Bool {
        url.absoluteString.range(of: "trailer", options: .caseInsensitive) != nil
    }

    /// A web "where-to-watch" link (e.g. a Tubi/Roku provider page from the remote
    /// catalog) — not a directly playable media file. These should open externally.
    static func externalWatchURL(for movie: FreeMovie) -> URL? {
        guard directPlayableURL(for: movie) == nil,
              let url = URL(string: movie.streamURL),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              !["mp4", "m3u8"].contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }

    static func videoIfDirect(from movie: FreeMovie, creator: User = User.defaultUser) -> Video? {
        guard let url = directPlayableURL(for: movie) else { return nil }
        let tags = movie.genre.map { $0.rawValue }
        return Video(
            id: stableVideoID(for: movie),
            title: movie.title,
            description: movie.overview,
            thumbnailURL: movie.posterURL,
            videoURL: url.absoluteString,
            duration: TimeInterval(max(60, movie.runtime * 60)),
            viewCount: stableViewCount(for: movie),
            likeCount: stableLikeCount(for: movie),
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
            id: stableVideoID(for: movie),
            title: movie.title,
            description: movie.overview,
            thumbnailURL: movie.posterURL,
            videoURL: playableURL.absoluteString,
            duration: TimeInterval(max(60, movie.runtime * 60)),
            viewCount: stableViewCount(for: movie),
            likeCount: stableLikeCount(for: movie),
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

    // MARK: - Deterministic display stats
    // Swift's String.hashValue is randomly seeded per process, so it can't be used
    // for values that must stay stable across launches. Use a fixed FNV-1a hash so
    // a movie's view/like counts don't shuffle every time it's opened.

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func stableViewCount(for movie: FreeMovie) -> Int {
        50_000 + Int(stableHash("v-\(movie.id)") % 1_950_000)
    }

    private static func stableLikeCount(for movie: FreeMovie) -> Int {
        5_000 + Int(stableHash("l-\(movie.id)") % 195_000)
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