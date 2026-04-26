//
//  FreeCatalogService.swift
//  MyChannel
//
//  Free movie/TV catalog via TMDB + free streaming providers
//  (Tubi, Freevee, Roku, Pluto, Plex). Uses `mychannel-content` Cloud Run.
//

import Foundation

struct FreeCatalogItem: Codable, Identifiable {
    let id: String
    let tmdbId: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let rating: Double
    let mediaType: String
    let providers: [FreeProvider]
    struct FreeProvider: Codable { let name: String; let logoPath: String?; let watchURL: String? }
}

struct FreeCatalogCategory: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let items: [FreeCatalogItem]
}

@MainActor
final class FreeCatalogService: ObservableObject {
    static let shared = FreeCatalogService()
    private init() {}
    @Published private(set) var trending: [FreeCatalogItem] = []
    @Published private(set) var categories: [FreeCatalogCategory] = []
    @Published private(set) var searchResults: [FreeCatalogItem] = []

    func fetchTrending(region: String = "US") async throws {
        struct Req: Encodable { let task: String; let region: String }
        struct RawP: Decodable { let name: String; let logo: String?; let url: String? }
        struct RawI: Decodable { let id: String; let tmdb: Int; let title: String; let overview: String; let poster: String?; let backdrop: String?; let date: String?; let rating: Double; let type: String; let providers: [RawP]? }
        struct Raw: Decodable { let items: [RawI]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_free_trending", region: region))
        trending = (r.items ?? []).map {
            FreeCatalogItem(id: $0.id, tmdbId: $0.tmdb, title: $0.title, overview: $0.overview, posterPath: $0.poster,
                backdropPath: $0.backdrop, releaseDate: $0.date, rating: $0.rating, mediaType: $0.type,
                providers: ($0.providers ?? []).map { FreeCatalogItem.FreeProvider(name: $0.name, logoPath: $0.logo, watchURL: $0.url) })
        }
    }

    func fetchCategories(region: String = "US") async throws {
        struct Req: Encodable { let task: String; let region: String }
        struct RawP: Decodable { let name: String; let logo: String?; let url: String? }
        struct RawI: Decodable { let id: String; let tmdb: Int; let title: String; let overview: String; let poster: String?; let backdrop: String?; let date: String?; let rating: Double; let type: String; let providers: [RawP]? }
        struct RawC: Decodable { let id: String; let name: String; let slug: String; let items: [RawI]? }
        struct Raw: Decodable { let categories: [RawC]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_free_categories", region: region), timeout: 20)
        categories = (r.categories ?? []).map {
            FreeCatalogCategory(id: $0.id, name: $0.name, slug: $0.slug,
                items: ($0.items ?? []).map { FreeCatalogItem(id: $0.id, tmdbId: $0.tmdb, title: $0.title, overview: $0.overview,
                    posterPath: $0.poster, backdropPath: $0.backdrop, releaseDate: $0.date, rating: $0.rating, mediaType: $0.type,
                    providers: ($0.providers ?? []).map { FreeCatalogItem.FreeProvider(name: $0.name, logoPath: $0.logo, watchURL: $0.url) }) })
        }
    }

    func search(query: String, region: String = "US") async throws {
        struct Req: Encodable { let task: String; let query: String; let region: String }
        struct RawP: Decodable { let name: String; let logo: String?; let url: String? }
        struct RawI: Decodable { let id: String; let tmdb: Int; let title: String; let overview: String; let poster: String?; let backdrop: String?; let date: String?; let rating: Double; let type: String; let providers: [RawP]? }
        struct Raw: Decodable { let items: [RawI]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "search_free_catalog", query: query, region: region))
        searchResults = (r.items ?? []).map {
            FreeCatalogItem(id: $0.id, tmdbId: $0.tmdb, title: $0.title, overview: $0.overview, posterPath: $0.poster,
                backdropPath: $0.backdrop, releaseDate: $0.date, rating: $0.rating, mediaType: $0.type,
                providers: ($0.providers ?? []).map { FreeCatalogItem.FreeProvider(name: $0.name, logoPath: $0.logo, watchURL: $0.url) })
        }
    }

    func searchAll(query: String, limitPerSource: Int = 30) async -> [FreeCatalogItem] {
        // For now, delegate to the search method
        do {
            try await search(query: query)
            return searchResults
        } catch {
            print("⚠️ [FreeCatalog] searchAll failed: \(error)")
            return []
        }
    }
}

extension FreeCatalogItem {
    var toFreeMovie: FreeMovie {
        let year = Int(releaseDate?.prefix(4) ?? "") ?? 0
        let sourceName = providers.first?.name.lowercased() ?? ""
        let source: FreeMovie.StreamingSource = {
            if sourceName.contains("tubi") { return .tubi }
            if sourceName.contains("roku") { return .rokuChannel }
            if sourceName.contains("plex") { return .plexFree }
            if sourceName.contains("crackle") { return .crackle }
            return .youtube
        }()
        return FreeMovie(
            id: id,
            title: title,
            posterURL: posterPath ?? "",
            backdropURL: backdropPath,
            overview: overview,
            releaseDate: releaseDate ?? "",
            runtime: 90,
            genre: [],
            rating: "PG-13",
            imdbRating: rating,
            streamingSource: source,
            streamURL: providers.first?.watchURL ?? "",
            trailerURL: nil,
            cast: [],
            director: "",
            year: year,
            language: "English",
            country: "US",
            isAvailable: true
        )
    }
}
