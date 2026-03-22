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
    
    private let appleRSSBaseURL = "https://rss.applemarketingtools.com/api/v2"
    private let spotlightSeeds: [String] = [
        "Sabrina Carpenter Espresso",
        "Sabrina Carpenter Please Please Please",
        "Post Malone Morgan Wallen I Had Some Help",
        "Kendrick Lamar Not Like Us",
        "Taylor Swift Fortnight",
        "Tommy Richman Million Dollar Baby",
        "Chappell Roan Good Luck Babe",
        "Benson Boone Beautiful Things",
        "Billie Eilish Birds of a Feather",
        "Hozier Too Sweet",
        "Teddy Swims Lose Control",
        "Zach Bryan Pink Skies"
    ]
    private let artistSeeds: [String] = [
        "Taylor Swift",
        "Beyoncé",
        "Bad Bunny",
        "Olivia Rodrigo",
        "Drake",
        "Billie Eilish",
        "Peso Pluma",
        "Morgan Wallen",
        "Karol G",
        "SZA"
    ]
    private let albumSeeds: [String] = [
        "Be Foreal MIA Ghost",
        "MIA Ghost",
        "MIA Ghost EP",
        "MIA Ghost mixtape",
        "6413 Lil Donny",
        "The Tortured Poets Department",
        "Cowboy Carter",
        "HIT ME HARD AND SOFT",
        "SOS",
        "Stick Season",
        "GUTS",
        "ENDLESS SUMMER VACATION",
        "For All The Dogs",
        "Vultures",
        "Eternal Sunshine"
    ]
    
    private var spotlightCache: [CatalogSong] = []
    private var artistCache: [CatalogArtist] = []
    private var albumCache: [CatalogAlbum] = []
    
    // MARK: - Public API
    func searchSongs(term: String, limit: Int = 50, country: String = "US") async throws -> [CatalogSong] {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://itunes.apple.com/search?term=\(q)&entity=song&country=\(country)&limit=\(limit)"
        return try await fetchSongs(from: urlString)
    }
    
    func topSongs(limit: Int = 50, country: String = "US") async throws -> [CatalogSong] {
        if let chart = try? await fetchAppleMusicChart(limit: limit, country: country), !chart.isEmpty {
            return chart
        }
        return try await searchSongs(term: "top hits", limit: limit, country: country)
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
        var artists = decoded.results.compactMap { r -> CatalogArtist? in
            guard let id = r.artistId ?? r.collectionId else { return nil }
            let art = upgradedArtwork(from: r.artworkUrl100)
            // Treat empty or whitespace-only URLs as nil so backfill kicks in
            let validArt = (art != nil && !art!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? art : nil
            return CatalogArtist(id: id, name: r.artistName ?? "", linkUrl: r.artistLinkUrl, artworkUrl: validArt)
        }
        // iTunes musicArtist entity often returns nil artwork — backfill from top track
        artists = await backfillArtistArtwork(artists, country: country)
        return artists
    }
    
    /// For artists missing artwork, fetch their top song to grab album art as a proxy
    private func backfillArtistArtwork(_ artists: [CatalogArtist], country: String) async -> [CatalogArtist] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for artist in artists where artist.artworkUrl == nil || artist.artworkUrl!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                group.addTask {
                    // Try up to 2 times for reliability
                    for attempt in 0..<2 {
                        if attempt > 0 { try? await Task.sleep(nanoseconds: 300_000_000) }
                        if let artwork = try? await self.fetchTopTrackArtwork(for: artist.id, country: country) {
                            return (artist.id, artwork)
                        }
                    }
                    return (artist.id, nil)
                }
            }
            var artworkMap: [Int: String] = [:]
            for await (id, artwork) in group {
                if let artwork { artworkMap[id] = artwork }
            }
            return artists.map { a in
                let needsBackfill = a.artworkUrl == nil || a.artworkUrl!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if needsBackfill, let fallback = artworkMap[a.id] {
                    return CatalogArtist(id: a.id, name: a.name, linkUrl: a.linkUrl, artworkUrl: fallback)
                }
                return a
            }
        }
    }
    
    private func fetchTopTrackArtwork(for artistId: Int, country: String) async throws -> String? {
        let urlString = "https://itunes.apple.com/lookup?id=\(artistId)&entity=song&country=\(country)&limit=1"
        guard let url = URL(string: urlString) else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return nil }
        let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        // First result is usually the artist entity itself, second is the song
        let songResult = decoded.results.first(where: { $0.trackId != nil })
        return upgradedArtwork(from: songResult?.artworkUrl100)
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
    
    func curatedSpotlightSongs() async -> [CatalogSong] {
        if !spotlightCache.isEmpty { return spotlightCache }
        var collected: [CatalogSong] = []
        for seed in spotlightSeeds {
            if let song = try? await searchSongs(term: seed, limit: 1).first {
                collected.append(song)
            }
        }
        spotlightCache = dedupeSongs(collected)
        return spotlightCache
    }
    
    func curatedArtists() async -> [CatalogArtist] {
        if !artistCache.isEmpty { return artistCache }
        var collected: [CatalogArtist] = []
        for seed in artistSeeds {
            if let artist = try? await searchArtists(term: seed, limit: 1).first {
                collected.append(artist)
            }
        }
        artistCache = dedupeArtists(collected)
        return artistCache
    }
    
    /// Fetch fresh artwork for a single artist by Apple Music ID (lookup API)
    func freshArtworkURL(forArtistId artistId: Int, country: String = "US") async -> String? {
        // Try with more songs for better chance of artwork
        let urlString = "https://itunes.apple.com/lookup?id=\(artistId)&entity=song&country=\(country)&limit=3"
        guard let url = URL(string: urlString) else { return nil }
        // Retry once on failure
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode,
                  let decoded = try? JSONDecoder().decode(iTunesSearchResponse.self, from: data),
                  !decoded.results.isEmpty else { continue }
            // Try song artwork first (more reliable than artist entity artwork)
            let songResult = decoded.results.first(where: { $0.trackId != nil && $0.artworkUrl100 != nil })
            if let art = upgradedArtwork(from: songResult?.artworkUrl100), !art.isEmpty { return art }
            // Fallback to artist entity artwork
            let artistResult = decoded.results.first(where: { $0.artistId != nil && $0.trackId == nil })
            if let art = upgradedArtwork(from: artistResult?.artworkUrl100), !art.isEmpty { return art }
        }
        return nil
    }
    
    func curatedAlbums() async -> [CatalogAlbum] {
        if !albumCache.isEmpty { return albumCache }
        var collected: [CatalogAlbum] = []
        for seed in albumSeeds {
            if let album = try? await searchAlbums(term: seed, limit: 1).first {
                collected.append(album)
            }
        }
        albumCache = dedupeAlbums(collected)
        return albumCache
    }
    
    // MARK: - Internal
    private func fetchSongs(from urlString: String) async throws -> [CatalogSong] {
        guard let url = URL(string: urlString) else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return [] }
        let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return decoded.results.compactMap { r in
            // Must have a trackId — artist/collection entities don't, and would produce
            // broken rows with no previewUrl (causes tracks 1-2 not playing on artist pages)
            guard let trackId = r.trackId else { return nil }
            return CatalogSong(
                id: trackId,
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
    
    private func fetchAppleMusicChart(limit: Int, country: String) async throws -> [CatalogSong] {
        let normalizedLimit = min(max(limit, 10), 100)
        let urlString = "\(appleRSSBaseURL)/\(country.lowercased())/music/most-played/\(normalizedLimit)/songs.json"
        guard let url = URL(string: urlString) else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return [] }
        let decoded = try JSONDecoder().decode(AppleMusicRSSResponse.self, from: data)
        return decoded.feed.results.prefix(limit).map { item in
            CatalogSong(
                id: Int(item.id) ?? item.id.hashValue,
                title: item.name,
                artist: item.artistName,
                artworkUrl: upgradedArtwork(from: item.artworkUrl100),
                previewUrl: item.previewUrl,
                trackViewUrl: item.url,
                collectionName: item.albumName,
                primaryGenreName: item.genreName
            )
        }
    }
    
    private func dedupeSongs(_ songs: [CatalogSong]) -> [CatalogSong] {
        var seen: Set<Int> = []
        var result: [CatalogSong] = []
        for song in songs {
            if seen.insert(song.id).inserted {
                result.append(song)
            }
        }
        return result
    }
    
    private func dedupeArtists(_ artists: [CatalogArtist]) -> [CatalogArtist] {
        var seen: Set<Int> = []
        var result: [CatalogArtist] = []
        for artist in artists {
            if seen.insert(artist.id).inserted {
                result.append(artist)
            }
        }
        return result
    }
    
    private func dedupeAlbums(_ albums: [CatalogAlbum]) -> [CatalogAlbum] {
        var seen: Set<Int> = []
        var result: [CatalogAlbum] = []
        for album in albums {
            if seen.insert(album.id).inserted {
                result.append(album)
            }
        }
        return result
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

// MARK: - Apple Music RSS
private struct AppleMusicRSSResponse: Codable {
    let feed: AppleMusicRSSFeed
}

private struct AppleMusicRSSFeed: Codable {
    let results: [AppleMusicRSSResult]
}

private struct AppleMusicRSSResult: Codable {
    let id: String
    let name: String
    let artistName: String
    let url: String
    let albumName: String?
    let artworkUrl100: String
    let genres: [AppleMusicGenre]?
    let previews: [AppleMusicPreview]?
    
    var previewUrl: String? { previews?.first?.url }
    var genreName: String? { genres?.first?.name }
}

private struct AppleMusicGenre: Codable {
    let name: String
}

private struct AppleMusicPreview: Codable {
    let url: String
}


