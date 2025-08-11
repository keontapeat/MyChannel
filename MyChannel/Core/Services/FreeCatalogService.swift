import Foundation

/// Aggregates multiple legal free sources (Internet Archive, Pexels, Pixabay, NASA)
final class FreeCatalogService {
    static let shared = FreeCatalogService()
    private init() {}

    struct Keys {
        static var pexels: String { ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? "" }
        static var pixabay: String { ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? "" }
    }

    enum Source: CaseIterable {
        case internetArchive, pexels, pixabay, nasa
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
                    }
                }
            }
            var combined: [FreeMovie] = []
            for await chunk in group { combined.append(contentsOf: chunk) }
            // Deduplicate by streamURL
            var seen = Set<String>()
            let unique = combined.filter { seen.insert($0.streamURL).inserted }
            return unique
        }
    }
}


