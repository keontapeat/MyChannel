import Foundation

/// Aggregates multiple legal free sources (Internet Archive, Pexels, Pixabay, NASA, TMDB)
final class FreeCatalogService {
    static let shared = FreeCatalogService()
    private init() {}

    struct Keys {
        static var pexels: String { ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? "" }
        static var pixabay: String { ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? "" }
        static var tmdb: String { ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? "" }
    }

    enum Source: CaseIterable {
        case internetArchive, pexels, pixabay, nasa, tmdb
    }

    func searchAll(query: String, limitPerSource: Int = 12) async -> [FreeMovie] {
        await withTaskGroup(of: [FreeMovie].self) { group in
            for src in Source.allCases {
                group.addTask {
                    switch src {
                    case .internetArchive:
                        do { return try await ArchiveOrgService.shared.fetchPopular(page: 1, rows: limitPerSource) } catch { return [] }
                    case .pexels:
                        do { return try await PexelsService.shared.search(query: query, perPage: limitPerSource, apiKey: Keys.pexels) } catch { return [] }
                    case .pixabay:
                        do { return try await PixabayService.shared.search(query: query, perPage: limitPerSource, apiKey: Keys.pixabay) } catch { return [] }
                    case .nasa:
                        do { return try await NASAImagesService.shared.search(query: query, limit: limitPerSource) } catch { return [] }
                    case .tmdb:
                        // Use TMDB only if API key is available (via Info.plist or env)
                        guard !AppSecrets.tmdbAPIKey.isEmpty else { return [] }
                        // Fetch more from TMDB to surface modern titles
                        let tmdbLimit = max(limitPerSource * 2, 20)
                        do { return try await TMDBService.shared.fetchFreeWithAdsMoviesUS(page: 1, limit: tmdbLimit) } catch { return [] }
                    }
                }
            }
            var combined: [FreeMovie] = []
            for await chunk in group { combined.append(contentsOf: chunk) }
            // Prefer TMDB (modern) and newer titles before deduping
            combined.sort { a, b in
                let aIsTMDB = a.id.hasPrefix("tmdb-")
                let bIsTMDB = b.id.hasPrefix("tmdb-")
                if aIsTMDB != bIsTMDB { return aIsTMDB && !bIsTMDB }
                if a.year != b.year { return a.year > b.year }
                return a.imdbRating > b.imdbRating
            }
            // Deduplicate by streamURL (preserves the preferred order)
            var seen = Set<String>()
            let unique = combined.filter { seen.insert($0.streamURL).inserted }
            return unique
        }
    }
}
