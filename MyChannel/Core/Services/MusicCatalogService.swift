//
//  MusicCatalogService.swift
//  MyChannel
//
//  Lightweight Apple iTunes Search API client to fetch songs/artists without tokens.
//  Provides search and simple category feeds, plus preview URLs and artwork.
//

import Foundation

struct CatalogSong: Identifiable, Codable {
    let id: Int
    let title: String
    let artist: String
    let artworkUrl: String?
    let previewUrl: String?
    let trackViewUrl: String?
    let collectionName: String?
    let primaryGenreName: String?
}

struct CatalogArtist: Identifiable, Codable {
    let id: Int
    let name: String
    let linkUrl: String?
    let artworkUrl: String?
}

struct CatalogAlbum: Identifiable, Codable {
    let id: Int
    let title: String
    let artist: String
    let artworkUrl: String?
    let viewUrl: String?
}

@MainActor
final class MusicCatalogService: ObservableObject {
    static let shared = MusicCatalogService()
    private init() {}
    
    // MARK: - Public API
    func searchSongs(term: String, limit: Int = 50, country: String = "US") async throws -> [CatalogSong] {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://itunes.apple.com/search?term=\(q)&entity=song&country=\(country)&limit=\(limit)"
        return try await fetchSongs(from: urlString)
    }
    
    func topSongs(limit: Int = 50, country: String = "US") async throws -> [CatalogSong] {
        // Basic feed via search with empty term sorted by popularity is not supported directly; use a common query
        // Use a broad genre term to get popular items quickly
        return try await searchSongs(term: "top songs", limit: limit, country: country)
    }
    
    func genreSongs(_ genreKeyword: String, limit: Int = 50, country: String = "US") async throws -> [CatalogSong] {
        return try await searchSongs(term: genreKeyword, limit: limit, country: country)
    }
    
    func searchArtists(term: String, limit: Int = 50, country: String = "US") async throws -> [CatalogArtist] {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://itunes.apple.com/search?term=\(q)&entity=musicArtist&country=\(country)&limit=\(limit)"
        guard let url = URL(string: urlString) else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return [] }
        let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return decoded.results.compactMap { r in
            guard let id = r.artistId ?? r.collectionId else { return nil }
            return CatalogArtist(id: id, name: r.artistName ?? "", linkUrl: r.artistLinkUrl, artworkUrl: r.artworkUrl100)
        }
    }
    
    func searchAlbums(term: String, limit: Int = 50, country: String = "US") async throws -> [CatalogAlbum] {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://itunes.apple.com/search?term=\(q)&entity=album&country=\(country)&limit=\(limit)"
        guard let url = URL(string: urlString) else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return [] }
        let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return decoded.results.compactMap { r in
            guard let id = r.collectionId else { return nil }
            return CatalogAlbum(id: id, title: r.collectionName ?? r.trackName ?? "", artist: r.artistName ?? "", artworkUrl: r.artworkUrl100, viewUrl: r.collectionViewUrl)
        }
    }
    
    func topTracksForArtist(artistId: Int, limit: Int = 25, country: String = "US") async throws -> [CatalogSong] {
        // Use lookup by artistId and filter to song entities
        let urlString = "https://itunes.apple.com/lookup?id=\(artistId)&entity=song&country=\(country)&limit=\(limit)"
        return try await fetchSongs(from: urlString)
    }
    
    func topTracksForAlbum(collectionId: Int, country: String = "US") async throws -> [CatalogSong] {
        // Use lookup by collectionId and entity=song to get album tracks
        let urlString = "https://itunes.apple.com/lookup?id=\(collectionId)&entity=song&country=\(country)"
        return try await fetchSongs(from: urlString)
    }
    
    // MARK: - Internal
    private func fetchSongs(from urlString: String) async throws -> [CatalogSong] {
        guard let url = URL(string: urlString) else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return [] }
        let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return decoded.results.map { r in
            CatalogSong(
                id: r.trackId ?? r.collectionId ?? Int.random(in: 1...Int.max),
                title: r.trackName ?? r.collectionName ?? r.artistName ?? "",
                artist: r.artistName ?? "",
                artworkUrl: upgradedArtwork(from: r.artworkUrl100),
                previewUrl: r.previewUrl,
                trackViewUrl: r.trackViewUrl,
                collectionName: r.collectionName,
                primaryGenreName: r.primaryGenreName
            )
        }
    }
    
    // Upgrade Apple artwork URL to 600x600 when possible
    private func upgradedArtwork(from url: String?) -> String? {
        guard let url else { return nil }
        return url.replacingOccurrences(of: "100x100bb", with: "600x600bb")
    }
}

// MARK: - iTunes Search Models
private struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [iTunesTrack]
}

private struct iTunesTrack: Codable {
    let trackId: Int?
    let collectionId: Int?
    let artistName: String?
    let artistId: Int?
    let collectionName: String?
    let trackName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackViewUrl: String?
    let collectionViewUrl: String?
    let primaryGenreName: String?
    let artistLinkUrl: String?
}


