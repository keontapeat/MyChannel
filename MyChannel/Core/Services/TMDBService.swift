import Foundation

// MARK: - TMDB Service
// Uses TMDB for discovery and watch-provider availability. Requires TMDB_API_KEY in environment.
// Note: TMDB does not provide direct stream URLs. We surface provider deep links for external playback.
final class TMDBService {
    static let shared = TMDBService()
    private init() {}

    private struct Config {
        static var apiKey: String { AppSecrets.tmdbAPIKey }
        static let base = URL(string: "https://api.themoviedb.org/3")!
        static let imageBase = "https://image.tmdb.org/t/p"
    }

    struct TMDBMovie: Decodable {
        let id: Int
        let title: String?
        let name: String?
        let overview: String?
        let release_date: String?
        let poster_path: String?
        let backdrop_path: String?
        let original_language: String?
        let vote_average: Double?
    }

    struct DiscoverResponse: Decodable { let results: [TMDBMovie] }

    struct ProvidersResponse: Decodable {
        let results: [String: CountryAvailability]
        struct CountryAvailability: Decodable {
            let link: String?
            let flatrate: [Provider]?
            let free: [Provider]?
            let ads: [Provider]?
        }
        struct Provider: Decodable { let provider_id: Int; let provider_name: String }
    }

    struct MovieDetails: Decodable { let runtime: Int?; let genres: [Genre]?; struct Genre: Decodable { let name: String } }
    struct VideosResponse: Decodable { let results: [Video]; struct Video: Decodable { let key: String; let name: String?; let site: String; let type: String; let official: Bool? } }

    // Common US free providers worth surfacing
    private let preferredFreeProviders: Set<String> = [
        "Tubi", "The Roku Channel", "Freevee", "Pluto TV", "Plex", "Crackle", "Peacock", "Peacock Premium"
    ]

    private func makeRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        guard !Config.apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var comps = URLComponents(url: Config.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = ([URLQueryItem(name: "api_key", value: Config.apiKey)] + query)
        let url = comps.url!
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        return req
    }

    // Fetch popular/recent movies, then filter by US free/ads providers
    func fetchFreeWithAdsMoviesUS(page: Int = 1, limit: Int = 20) async throws -> [FreeMovie] {
        // Use discover to prefer newer/popular titles
        let discoverReq = try makeRequest(
            path: "discover/movie",
            query: [
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "with_release_type", value: "3|2|4|5"), // theatrical/digital/physical/TV
                URLQueryItem(name: "page", value: String(page))
            ]
        )
        let (data, _) = try await URLSession.shared.data(for: discoverReq)
        let discover = try JSONDecoder().decode(DiscoverResponse.self, from: data)

        var results: [FreeMovie] = []
        for movie in discover.results.prefix(limit) {
            let providerInfo = try await providersFor(movieID: movie.id)
            guard let us = providerInfo.results["US"] else { continue }

            // merge free and ads buckets and filter to preferred providers
            let candidates = (us.free ?? []) + (us.ads ?? []) + (us.flatrate ?? [])
            let match = candidates.first { preferredFreeProviders.contains($0.provider_name) }
            guard let provider = match else { continue }

            // fetch details for runtime and genres (optional)
            let details = try await detailsFor(movieID: movie.id)
            let runtime = details?.runtime ?? 0
            let genres = details?.genres?.map { FreeMovie.MovieGenre(rawValue: $0.name.lowercased()) }.compactMap { $0 } ?? []

            // Build FreeMovie. streamURL will use TMDB provider page link (external), not a direct mp4/hls.
            let title = movie.title ?? movie.name ?? ""
            let posterURL = movie.poster_path.map { "\(Config.imageBase)/w500\($0)" } ?? ""
            let backdropURL = movie.backdrop_path.map { "\(Config.imageBase)/w1280\($0)" }
            let overview = movie.overview ?? ""
            let releaseDate = movie.release_date ?? ""
            let year = Int(releaseDate.prefix(4)) ?? 0
            // Prefer modern titles only
            if year > 0 && year < 2012 { continue }
            let language = movie.original_language?.uppercased() ?? ""
            let imdbRating = (movie.vote_average ?? 0)

            let fm = FreeMovie(
                id: "tmdb-\(movie.id)",
                title: title,
                posterURL: posterURL,
                backdropURL: backdropURL,
                overview: overview,
                releaseDate: releaseDate,
                runtime: runtime,
                genre: genres,
                rating: "PG-13",
                imdbRating: imdbRating,
                streamingSource: mapProviderNameToSource(provider.provider_name),
                streamURL: us.link ?? "https://www.themoviedb.org/movie/\(movie.id)",
                trailerURL: nil,
                cast: [],
                director: "",
                year: year,
                language: language,
                country: "US",
                isAvailable: true
            )
            results.append(fm)
        }
        return results
    }

    // Fetch popular blockbusters and attach their official YouTube trailers. No provider filtering; intended for trailer playback only.
    func fetchPopularWithTrailersUS(page: Int = 1, limit: Int = 30) async throws -> [FreeMovie] {
        let discoverReq = try makeRequest(
            path: "discover/movie",
            query: [
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "with_release_type", value: "3|2|4|5"),
                URLQueryItem(name: "page", value: String(page))
            ]
        )
        let (data, _) = try await URLSession.shared.data(for: discoverReq)
        let discover = try JSONDecoder().decode(DiscoverResponse.self, from: data)

        var results: [FreeMovie] = []
        for movie in discover.results.prefix(limit) {
            // details (optional)
            let details = try await detailsFor(movieID: movie.id)
            let runtime = details?.runtime ?? 0
            let genres = details?.genres?.map { FreeMovie.MovieGenre(rawValue: $0.name.lowercased()) }.compactMap { $0 } ?? []

            let title = movie.title ?? movie.name ?? ""
            let posterURL = movie.poster_path.map { "\(Config.imageBase)/w500\($0)" } ?? ""
            let backdropURL = movie.backdrop_path.map { "\(Config.imageBase)/w1280\($0)" }
            let overview = movie.overview ?? ""
            let releaseDate = movie.release_date ?? ""
            let year = Int(releaseDate.prefix(4)) ?? 0
            // Prefer modern titles only
            if year > 0 && year < 2012 { continue }
            let language = movie.original_language?.uppercased() ?? ""
            let imdbRating = (movie.vote_average ?? 0)

            // Trailer lookup
            let youTubeTrailer = try await officialYouTubeTrailerKey(movieID: movie.id)
            let trailerURL = youTubeTrailer.map { "https://www.youtube.com/watch?v=\($0)" }

            let fm = FreeMovie(
                id: "tmdb-\(movie.id)",
                title: title,
                posterURL: posterURL,
                backdropURL: backdropURL,
                overview: overview,
                releaseDate: releaseDate,
                runtime: runtime,
                genre: genres,
                rating: "PG-13",
                imdbRating: imdbRating,
                streamingSource: .youtube,
                streamURL: trailerURL ?? "https://www.themoviedb.org/movie/\(movie.id)",
                trailerURL: trailerURL,
                cast: [],
                director: "",
                year: year,
                language: language,
                country: "US",
                isAvailable: true
            )
            results.append(fm)
        }
        return results
    }

    private func providersFor(movieID: Int) async throws -> ProvidersResponse {
        let req = try makeRequest(path: "movie/\(movieID)/watch/providers", query: [])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }

    private func detailsFor(movieID: Int) async throws -> MovieDetails? {
        let req = try makeRequest(path: "movie/\(movieID)", query: [])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try? JSONDecoder().decode(MovieDetails.self, from: data)
    }

    private func videosFor(movieID: Int) async throws -> VideosResponse {
        let req = try makeRequest(path: "movie/\(movieID)/videos", query: [])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(VideosResponse.self, from: data)
    }

    private func officialYouTubeTrailerKey(movieID: Int) async throws -> String? {
        let vids = try await videosFor(movieID: movieID).results
        // Prefer official trailer on YouTube
        if let o = vids.first(where: { ($0.official ?? false) && $0.site.lowercased() == "youtube" && $0.type.lowercased() == "trailer" }) {
            return o.key
        }
        // Fallback to any YouTube trailer
        if let y = vids.first(where: { $0.site.lowercased() == "youtube" && $0.type.lowercased() == "trailer" }) {
            return y.key
        }
        return nil
    }

    private func mapProviderNameToSource(_ name: String) -> FreeMovie.StreamingSource {
        switch name.lowercased() {
        case let s where s.contains("tubi"): return .tubi
        case let s where s.contains("roku"): return .rokuChannel
        case let s where s.contains("plex"): return .plexFree
        case let s where s.contains("crackle"): return .crackle
        case let s where s.contains("freevee") || s.contains("imdb"): return .imdbTV
        // Fallbacks for others not modeled explicitly
        default: return .youtube
        }
    }
}
