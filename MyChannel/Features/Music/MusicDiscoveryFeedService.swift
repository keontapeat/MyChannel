//
//  MusicDiscoveryFeedService.swift
//  MyChannel
//
//  Firestore listener for artist-uploaded tracks.
//  Populates newDrops (recent uploads) and trendingUploads (top by streamCount).
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Uploaded Track Model

struct UploadedTrack: Identifiable {
    let id: String
    let title: String
    let artistId: String
    let artistName: String
    let genre: String
    let artworkURL: String?
    let playbackURL: URL
    let streamCount: Int
    let likeCount: Int
    let uploadedAt: Date
    let isExplicit: Bool

    var isNew: Bool {
        Date().timeIntervalSince(uploadedAt) < 7 * 24 * 3600
    }
}

// MARK: - Service

@MainActor
final class MusicDiscoveryFeedService: ObservableObject {
    static let shared = MusicDiscoveryFeedService()
    private init() {
        Task { await fetchAll() }
    }

    @Published var newDrops: [UploadedTrack] = []
    @Published var trendingUploads: [UploadedTrack] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    #if canImport(FirebaseFirestore)
    private var newDropsListener: ListenerRegistration?
    private var trendingListener: ListenerRegistration?
    #endif

    func fetchAll() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.listenNewDrops() }
            group.addTask { await self.listenTrending() }
        }
        isLoading = false
    }

    private func listenNewDrops() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        newDropsListener?.remove()
        newDropsListener = db.collection("music_tracks")
            .whereField("isPublished", isEqualTo: true)
            .whereField("status", isEqualTo: "published")
            .order(by: "uploadedAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.errorMessage = "Could not load new music: \(error.localizedDescription)"
                        return
                    }
                    self.newDrops = snapshot?.documents.compactMap { Self.track(from: $0) } ?? []
                }
            }
        #endif
    }

    private func listenTrending() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        trendingListener?.remove()
        trendingListener = db.collection("music_tracks")
            .whereField("isPublished", isEqualTo: true)
            .whereField("status", isEqualTo: "published")
            .order(by: "streamCount", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.errorMessage = "Could not load trending music: \(error.localizedDescription)"
                        return
                    }
                    self.trendingUploads = snapshot?.documents.compactMap { Self.track(from: $0) } ?? []
                }
            }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private static func track(from doc: QueryDocumentSnapshot) -> UploadedTrack? {
        let d = doc.data()
        let renditions = d["renditions"] as? [String: Any]
        let playbackURL = MusicAPIClient.publicPlaybackURL(from: [
            renditions?["hls"] as? String,
            d["hlsURL"] as? String,
            d["streamURL"] as? String,
            renditions?["mp3"] as? String,
            d["mp3URL"] as? String
        ])
        guard
            let title = d["title"] as? String,
            let artistId = d["artistId"] as? String,
            let artistName = d["artistName"] as? String,
            let playbackURL
        else { return nil }

        let ts = (d["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
        return UploadedTrack(
            id: doc.documentID,
            title: title,
            artistId: artistId,
            artistName: artistName,
            genre: d["genre"] as? String ?? "Music",
            artworkURL: d["artworkURL"] as? String,
            playbackURL: playbackURL,
            streamCount: d["streamCount"] as? Int ?? 0,
            likeCount: d["likeCount"] as? Int ?? 0,
            uploadedAt: ts,
            isExplicit: d["isExplicit"] as? Bool ?? false
        )
    }
    #endif
}
