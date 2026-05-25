//
//  MyChannelOriginalsService.swift
//  MyChannel
//
//  Phase 96: MyChannel Studios — Originals.
//  First-window exclusive series + films bundled in Plus+ Pro.
//  Content metadata lives in Firestore `originals/{id}` and
//  is gated by `SubscriptionTiersService.currentTier == .pro`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum OriginalContentKind: String, Codable, CaseIterable {
    case series, film, documentary, special, podcast
}

struct Original: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let synopsis: String
    let kind: OriginalContentKind
    let genres: [String]
    let rating: String                // "G" / "PG" / "PG-13" / "TV-14" / "R"
    let language: String              // BCP-47
    let releasedAt: Date
    let trailerVideoId: String?
    let posterURL: URL?
    let backdropURL: URL?
    let episodes: [OriginalEpisode]   // empty for films
    let totalDurationMinutes: Int
    let productionPartner: String?    // studio name if co-produced
    let isExclusive: Bool             // true = Plus+ Pro only
}

struct OriginalEpisode: Codable, Identifiable, Equatable {
    let id: String
    let originalId: String
    let season: Int
    let episode: Int
    let title: String
    let synopsis: String?
    let videoId: String               // maps to `videos/{videoId}` for playback
    let durationMinutes: Int
    let airDate: Date
    let thumbnailURL: URL?
}

@MainActor
final class MyChannelOriginalsService: ObservableObject {
    static let shared = MyChannelOriginalsService()
    private init() {}

    @Published private(set) var featured: [Original] = []
    @Published private(set) var allOriginals: [Original] = []

    // MARK: - Catalog

    func loadFeatured(limit: Int = 6) async throws {
        guard AppConfig.Features.enableMyChannelOriginals else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("originals")
            .whereField("featured", isEqualTo: true)
            .order(by: "releasedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        featured = snap.documents.compactMap { Self.decode($0) }
        #endif
    }

    func loadAll(kind: OriginalContentKind? = nil) async throws -> [Original] {
        guard AppConfig.Features.enableMyChannelOriginals else { return [] }
        #if canImport(FirebaseFirestore)
        var query: Query = Firestore.firestore().collection("originals")
            .order(by: "releasedAt", descending: true)
        if let kind { query = query.whereField("kind", isEqualTo: kind.rawValue) }
        let snap = try await query.getDocuments()
        let list = snap.documents.compactMap { Self.decode($0) }
        allOriginals = list
        return list
        #else
        return []
        #endif
    }

    // MARK: - Playback gate

    /// Returns true if the current user may play this title.
    /// Free users can always watch trailers; full content requires Pro tier.
    func canPlay(_ original: Original, isTrailer: Bool = false) -> Bool {
        guard AppConfig.Features.enableMyChannelOriginals else { return false }
        if isTrailer { return true }
        if !original.isExclusive { return true }
        guard let tier = SubscriptionTiersService.shared.currentTier else { return false }
        return tier == .pro || tier == .family
    }

    // MARK: - Decoding helper

    private static func decode(_ doc: QueryDocumentSnapshot) -> Original? {
        let d = doc.data()
        guard
            let title = d["title"] as? String,
            let synopsis = d["synopsis"] as? String,
            let kindRaw = d["kind"] as? String,
            let kind = OriginalContentKind(rawValue: kindRaw)
        else { return nil }

        let episodes: [OriginalEpisode] = (d["episodes"] as? [[String: Any]] ?? []).compactMap { e in
            guard
                let eid = e["id"] as? String,
                let ep = e["episode"] as? Int,
                let etitle = e["title"] as? String,
                let videoId = e["videoId"] as? String,
                let durationMins = e["durationMinutes"] as? Int,
                let airTs = e["airDate"] as? Timestamp
            else { return nil }
            return OriginalEpisode(
                id: eid,
                originalId: doc.documentID,
                season: e["season"] as? Int ?? 1,
                episode: ep,
                title: etitle,
                synopsis: e["synopsis"] as? String,
                videoId: videoId,
                durationMinutes: durationMins,
                airDate: airTs.dateValue(),
                thumbnailURL: (e["thumbnailURL"] as? String).flatMap(URL.init)
            )
        }

        return Original(
            id: doc.documentID,
            title: title,
            synopsis: synopsis,
            kind: kind,
            genres: d["genres"] as? [String] ?? [],
            rating: d["rating"] as? String ?? "PG",
            language: d["language"] as? String ?? "en-US",
            releasedAt: (d["releasedAt"] as? Timestamp)?.dateValue() ?? Date(),
            trailerVideoId: d["trailerVideoId"] as? String,
            posterURL: (d["posterURL"] as? String).flatMap(URL.init),
            backdropURL: (d["backdropURL"] as? String).flatMap(URL.init),
            episodes: episodes,
            totalDurationMinutes: d["totalDurationMinutes"] as? Int ?? 0,
            productionPartner: d["productionPartner"] as? String,
            isExclusive: d["isExclusive"] as? Bool ?? true
        )
    }
}
