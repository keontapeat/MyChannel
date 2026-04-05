//
//  WatchLaterFirestoreService.swift
//  MyChannel
//
//  Firestore-backed Watch Later service replacing MockWatchLaterService
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class WatchLaterFirestoreService: WatchLaterServiceProtocol, ObservableObject {
    static let shared = WatchLaterFirestoreService()
    private init() {}

    @Published var watchLaterItems: [WatchLaterItem] = []
    @Published var isLoading = false

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    // MARK: - Real-time listener

    func listen(userId: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        isLoading = true
        listener = db.collection("watch_later").document(userId).collection("items")
            .order(by: "addedAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ [WatchLaterFirestore] Listener error: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                guard let docs = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                self.watchLaterItems = docs.compactMap { doc in
                    let d = doc.data()
                    return WatchLaterItem(
                        id: doc.documentID,
                        userId: d["userId"] as? String ?? userId,
                        videoId: d["videoId"] as? String ?? "",
                        addedAt: (d["addedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        watchProgress: d["watchProgress"] as? Double ?? 0.0,
                        isWatched: d["isWatched"] as? Bool ?? false
                    )
                }
                self.isLoading = false
                print("✅ [WatchLaterFirestore] Loaded \(self.watchLaterItems.count) items")
            }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }

    // MARK: - WatchLaterServiceProtocol

    func addToWatchLater(videoId: String, userId: String) async throws -> WatchLaterItem {
        #if canImport(FirebaseFirestore)
        // Check for duplicates
        let existing = try await db.collection("watch_later").document(userId).collection("items")
            .whereField("videoId", isEqualTo: videoId)
            .limit(to: 1)
            .getDocuments()
        if !existing.documents.isEmpty {
            throw NSError(domain: "WatchLaterError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Already in Watch Later"])
        }

        let ref = db.collection("watch_later").document(userId).collection("items").document()
        let item = WatchLaterItem(id: ref.documentID, userId: userId, videoId: videoId)
        try await ref.setData([
            "userId": userId,
            "videoId": videoId,
            "addedAt": FieldValue.serverTimestamp(),
            "watchProgress": 0.0,
            "isWatched": false
        ])
        print("✅ [WatchLaterFirestore] Added video \(videoId)")
        return item
        #else
        return WatchLaterItem(userId: userId, videoId: videoId)
        #endif
    }

    func removeFromWatchLater(videoId: String, userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let snap = try await db.collection("watch_later").document(userId).collection("items")
            .whereField("videoId", isEqualTo: videoId)
            .getDocuments()
        let batch = db.batch()
        for doc in snap.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        print("✅ [WatchLaterFirestore] Removed video \(videoId)")
        #endif
    }

    func isInWatchLater(videoId: String, userId: String) async throws -> Bool {
        #if canImport(FirebaseFirestore)
        let snap = try await db.collection("watch_later").document(userId).collection("items")
            .whereField("videoId", isEqualTo: videoId)
            .limit(to: 1)
            .getDocuments()
        return !snap.documents.isEmpty
        #else
        return false
        #endif
    }

    func getWatchLaterItems(for userId: String) async throws -> [WatchLaterItem] {
        #if canImport(FirebaseFirestore)
        let snap = try await db.collection("watch_later").document(userId).collection("items")
            .order(by: "addedAt", descending: true)
            .getDocuments()
        return snap.documents.compactMap { doc in
            let d = doc.data()
            return WatchLaterItem(
                id: doc.documentID,
                userId: d["userId"] as? String ?? userId,
                videoId: d["videoId"] as? String ?? "",
                addedAt: (d["addedAt"] as? Timestamp)?.dateValue() ?? Date(),
                watchProgress: d["watchProgress"] as? Double ?? 0.0,
                isWatched: d["isWatched"] as? Bool ?? false
            )
        }
        #else
        return []
        #endif
    }

    func updateWatchProgress(itemId: String, progress: Double) async throws -> WatchLaterItem {
        guard let userId = AppState.shared.currentUser?.id else {
            throw NSError(domain: "WatchLaterError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        #if canImport(FirebaseFirestore)
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let isWatched = clampedProgress >= 0.95
        let ref = db.collection("watch_later").document(userId).collection("items").document(itemId)
        try await ref.updateData([
            "watchProgress": clampedProgress,
            "isWatched": isWatched
        ])
        let doc = try await ref.getDocument()
        let d = doc.data() ?? [:]
        return WatchLaterItem(
            id: doc.documentID,
            userId: d["userId"] as? String ?? userId,
            videoId: d["videoId"] as? String ?? "",
            addedAt: (d["addedAt"] as? Timestamp)?.dateValue() ?? Date(),
            watchProgress: clampedProgress,
            isWatched: isWatched
        )
        #else
        return WatchLaterItem(userId: userId, videoId: "")
        #endif
    }

    func markAsWatched(itemId: String) async throws -> WatchLaterItem {
        return try await updateWatchProgress(itemId: itemId, progress: 1.0)
    }

    func clearWatchedItems(for userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let snap = try await db.collection("watch_later").document(userId).collection("items")
            .whereField("isWatched", isEqualTo: true)
            .getDocuments()
        let batch = db.batch()
        for doc in snap.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        print("✅ [WatchLaterFirestore] Cleared \(snap.documents.count) watched items")
        #endif
    }

    func getWatchLaterStats(for userId: String) async throws -> WatchLaterStats {
        let items = watchLaterItems.isEmpty ? (try await getWatchLaterItems(for: userId)) : watchLaterItems
        let watched = items.filter { $0.isWatched }
        let unwatched = items.filter { !$0.isWatched }
        let avgProgress = items.isEmpty ? 0.0 : items.reduce(0.0) { $0 + $1.watchProgress } / Double(items.count)

        return WatchLaterStats(
            totalItems: items.count,
            unwatchedItems: unwatched.count,
            watchedItems: watched.count,
            averageWatchProgress: avgProgress,
            totalWatchTime: Double(items.count) * 600
        )
    }
}
