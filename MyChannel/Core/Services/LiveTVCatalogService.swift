//
//  LiveTVCatalogService.swift
//  MyChannel
//
//  🔥 Firebase-backed Live TV catalog.
//  Channels (artwork + stream URLs + metadata) are stored in Firestore so the
//  lineup can be curated and FIXED server-side without shipping a new build.
//  Local sample data is used as an instant, offline-safe fallback.
//
//  Firestore layout:
//    liveTVChannels/{channelId}
//      name, logoURL, streamURL, category, description,
//      isLive, viewerCount, quality, language, country,
//      epgURL?, previewFallbackURL?, sortIndex?, featured?, updatedAt
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class LiveTVCatalogService {
    static let shared = LiveTVCatalogService()
    private init() {}

    static let collectionName = "liveTVChannels"

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    /// Fetch the channel catalog from Firestore.
    /// Returns nil when Firebase is unavailable or the collection is empty,
    /// so callers can fall back to bundled sample data.
    func fetchRemoteChannels() async -> [LiveTVChannel]? {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection(Self.collectionName).getDocuments()
            guard !snapshot.documents.isEmpty else {
                print("ℹ️ [LiveTVCatalog] Firestore collection empty — using local catalog")
                return nil
            }

            // Keep each channel's sortIndex alongside it so we can honor the
            // curated server-side ordering (falling back to viewer count).
            let decoded: [(sortIndex: Int, channel: LiveTVChannel)] = snapshot.documents.compactMap { doc in
                guard let channel = Self.channel(from: doc.data(), id: doc.documentID) else { return nil }
                let sortIndex = doc.data()["sortIndex"] as? Int ?? Int.max
                return (sortIndex, channel)
            }
            guard !decoded.isEmpty else { return nil }

            // Respect optional sortIndex first, then viewer count as a tie-breaker.
            let sorted = decoded.sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.channel.viewerCount > rhs.channel.viewerCount
            }.map { $0.channel }
            print("✅ [LiveTVCatalog] Loaded \(sorted.count) channels from Firestore")
            return sorted
        } catch {
            print("⚠️ [LiveTVCatalog] Firestore fetch failed: \(error.localizedDescription)")
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(FirebaseFirestore)
    /// Decode a Firestore document into a LiveTVChannel.
    private static func channel(from data: [String: Any], id: String) -> LiveTVChannel? {
        guard
            let name = data["name"] as? String,
            let logoURL = data["logoURL"] as? String,
            let streamURL = data["streamURL"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = LiveTVChannel.ChannelCategory(rawValue: categoryRaw)
        else {
            return nil
        }

        // Defense in depth: skip channels whose logo can't render, even though
        // Firestore rules validate logoURL on write. Prevents broken thumbnails.
        let lowerLogo = logoURL.lowercased()
        if lowerLogo.contains("wikipedia.org") || lowerLogo.contains("wikimedia.org") || lowerLogo.hasSuffix(".svg") {
            print("⚠️ [LiveTVCatalog] Skipping channel \"\(name)\" — non-approved logoURL: \(logoURL)")
            return nil
        }

        return LiveTVChannel(
            id: id,
            name: name,
            logoURL: logoURL,
            streamURL: streamURL,
            category: category,
            description: data["description"] as? String ?? name,
            isLive: data["isLive"] as? Bool ?? true,
            viewerCount: data["viewerCount"] as? Int ?? 0,
            quality: data["quality"] as? String ?? "1080p",
            language: data["language"] as? String ?? "English",
            country: data["country"] as? String ?? "US",
            epgURL: data["epgURL"] as? String,
            previewFallbackURL: data["previewFallbackURL"] as? String
        )
    }

    /// Upload the bundled sample catalog to Firestore. Used by an admin/seed action.
    /// Safe to re-run: writes are idempotent (keyed by channel id).
    func seedFromSampleData() async throws {
        let channels = LiveTVChannel.sampleChannels
        let batchSize = 400
        var index = 0

        while index < channels.count {
            let slice = Array(channels[index..<min(index + batchSize, channels.count)])
            let batch = db.batch()
            for (offset, channel) in slice.enumerated() {
                let ref = db.collection(Self.collectionName).document(channel.id)
                batch.setData(Self.payload(for: channel, sortIndex: index + offset), forDocument: ref, merge: true)
            }
            try await batch.commit()
            index += batchSize
        }
        print("✅ [LiveTVCatalog] Seeded \(channels.count) channels to Firestore")
    }

    private static func payload(for channel: LiveTVChannel, sortIndex: Int) -> [String: Any] {
        var data: [String: Any] = [
            "name": channel.name,
            "logoURL": channel.logoURL,
            "streamURL": channel.streamURL,
            "category": channel.category.rawValue,
            "description": channel.description,
            "isLive": channel.isLive,
            "viewerCount": channel.viewerCount,
            "quality": channel.quality,
            "language": channel.language,
            "country": channel.country,
            "sortIndex": sortIndex,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let epg = channel.epgURL { data["epgURL"] = epg }
        if let fallback = channel.previewFallbackURL { data["previewFallbackURL"] = fallback }
        return data
    }
    #endif
}
