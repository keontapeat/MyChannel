//
//  MovieLibraryService.swift
//  MyChannel
//
//  Netflix/Hulu-parity backing store for the Movies section.
//
//  Responsibilities:
//  • "My List" (saved movies) — dual layer: UserDefaults (instant, offline)
//    mirrored to Firestore at users/{uid}/movieList/{movieId} (cross-device sync).
//  • "Continue Watching" — derived from the shared WatchProgressService
//    (Firestore watch_progress/{uid}_{videoId}) using the stable movie video id.
//
//  Design notes (house style):
//  • @MainActor ObservableObject singleton, matching OwnerFriendsStore /
//    UserCollectionsFirestoreService.
//  • Local cache is the source of truth for the UI so it works signed-out and
//    offline; Firestore is a sync mirror that hydrates on sign-in and via a
//    real-time snapshot listener.
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class MovieLibraryService: ObservableObject {
    static let shared = MovieLibraryService()

    /// Movie ids the user saved to "My List", newest first.
    @Published private(set) var myListIDs: [String] = []

    /// Movie continue-watching entries, newest first. Pulled from WatchProgressService.
    @Published private(set) var continueWatching: [MovieResumeEntry] = []

    private let myListKey = "mychannel.movieList.v1"
    private var listener: Any?
    private var boundUserId: String?

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    private init() {
        loadLocal()
    }

    // MARK: - My List (read)

    func isInMyList(_ movieID: String) -> Bool {
        myListIDs.contains(movieID)
    }

    /// Resolve saved ids back to full FreeMovie objects from a provided catalog.
    func myListMovies(from catalog: [FreeMovie]) -> [FreeMovie] {
        let index = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return myListIDs.compactMap { index[$0] }
    }

    // MARK: - My List (write)

    /// Toggle a movie in/out of My List. Returns the new membership state.
    @discardableResult
    func toggleMyList(_ movie: FreeMovie, userId: String?) -> Bool {
        let willAdd = !myListIDs.contains(movie.id)
        if willAdd {
            myListIDs.insert(movie.id, at: 0)
        } else {
            myListIDs.removeAll { $0 == movie.id }
        }
        saveLocal()
        if let userId = userId {
            syncMyListItem(movieID: movie.id, add: willAdd, userId: userId)
        }
        return willAdd
    }

    func removeFromMyList(_ movieID: String, userId: String?) {
        guard myListIDs.contains(movieID) else { return }
        myListIDs.removeAll { $0 == movieID }
        saveLocal()
        if let userId = userId {
            syncMyListItem(movieID: movieID, add: false, userId: userId)
        }
    }

    // MARK: - Continue Watching

    /// Rebuild the continue-watching list from WatchProgressService for the
    /// given catalog. Only movies with 5%–95% progress qualify (Netflix-style).
    func refreshContinueWatching(from catalog: [FreeMovie]) {
        let progressByVideo = WatchProgressService.shared.progress
        let index = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var entries: [MovieResumeEntry] = []
        for (_, wp) in progressByVideo {
            guard let movieID = MoviePlaybackResolver.movieID(fromVideoID: wp.videoId),
                  let movie = index[movieID] else { continue }
            guard wp.completionPct > 0.05 && wp.completionPct < 0.95 else { continue }
            entries.append(
                MovieResumeEntry(
                    movie: movie,
                    progress: wp.completionPct,
                    positionSec: wp.positionSec,
                    durationSec: wp.durationSec,
                    lastWatchedAt: wp.lastWatchedAt
                )
            )
        }
        continueWatching = entries.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    /// Load in-progress movies from Firestore (via WatchProgressService) then
    /// rebuild the local continue-watching list.
    func hydrateContinueWatching(userId: String, catalog: [FreeMovie]) async {
        #if canImport(FirebaseFirestore)
        try? await WatchProgressService.shared.fetchAllInProgress(userId: userId)
        #endif
        refreshContinueWatching(from: catalog)
    }

    // MARK: - Firestore sync

    /// Hydrate My List from Firestore and attach a live listener. Call on sign-in
    /// or when the Movies screen appears with an authenticated user.
    func bind(userId: String) {
        #if canImport(FirebaseFirestore)
        guard boundUserId != userId else { return }
        unbind()
        boundUserId = userId

        let col = db.collection("users").document(userId).collection("movieList")
        listener = col.order(by: "addedAt", descending: true).addSnapshotListener { [weak self] snap, _ in
            guard let self, let snap = snap else { return }
            let remoteIDs = snap.documents.map { $0.documentID }
            Task { @MainActor in
                self.mergeRemoteMyList(remoteIDs)
            }
        }
        #endif
    }

    func unbind() {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
        listener = nil
        boundUserId = nil
    }

    /// Union local + remote so an offline add isn't lost when the listener fires,
    /// then push any local-only ids up to Firestore.
    private func mergeRemoteMyList(_ remoteIDs: [String]) {
        let localOnly = myListIDs.filter { !remoteIDs.contains($0) }
        var merged = remoteIDs
        // Keep local-only (likely just-added, offline) entries at the front.
        merged.insert(contentsOf: localOnly, at: 0)

        var seen = Set<String>()
        myListIDs = merged.filter { seen.insert($0).inserted }
        saveLocal()

        if let userId = boundUserId {
            for id in localOnly {
                syncMyListItem(movieID: id, add: true, userId: userId)
            }
        }
    }

    private func syncMyListItem(movieID: String, add: Bool, userId: String) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(userId).collection("movieList").document(movieID)
        Task {
            do {
                if add {
                    try await ref.setData([
                        "movieId": movieID,
                        "addedAt": FieldValue.serverTimestamp()
                    ], merge: true)
                } else {
                    try await ref.delete()
                }
            } catch {
                #if DEBUG
                print("⚠️ [MovieLibrary] myList sync failed for \(movieID): \(error.localizedDescription)")
                #endif
            }
        }
        #endif
    }

    // MARK: - Local persistence

    private func loadLocal() {
        if let saved = UserDefaults.standard.stringArray(forKey: myListKey) {
            myListIDs = saved
        }
    }

    private func saveLocal() {
        UserDefaults.standard.set(myListIDs, forKey: myListKey)
    }
}

// MARK: - Continue Watching entry

struct MovieResumeEntry: Identifiable, Equatable {
    let movie: FreeMovie
    let progress: Double          // 0...1
    let positionSec: Double
    let durationSec: Double
    let lastWatchedAt: Date

    var id: String { movie.id }

    var remainingText: String {
        let remaining = max(0, durationSec - positionSec)
        let minutes = Int(remaining) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m left"
        }
        return "\(max(1, minutes))m left"
    }

    static func == (lhs: MovieResumeEntry, rhs: MovieResumeEntry) -> Bool {
        lhs.movie.id == rhs.movie.id && lhs.progress == rhs.progress
    }
}
