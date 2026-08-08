//
//  WatchProgressService.swift
//  MyChannel
//
//  Watch progress tracking: resume playback, completion tracking,
//  history sync. Uses Firestore for persistence.
//

import Foundation
import FirebaseFirestore
#if canImport(FirebaseCore)
import FirebaseCore
#endif

struct WatchProgress: Codable, Identifiable {
    let id: String
    let userId: String
    let videoId: String
    let positionSec: Double
    let durationSec: Double
    let completionPct: Double
    let lastWatchedAt: Date
    var isCompleted: Bool { completionPct >= 0.9 }
}

@MainActor
final class WatchProgressService: ObservableObject {
    static let shared = WatchProgressService()
    private static let localViewerDefaultsKey = "watchProgress.localViewerID"

    private init() {}

    @Published private(set) var progress: [String: WatchProgress] = [:]
    private var lastSavedValues: [String: (position: Double, duration: Double)] = [:]

    /// Uses an authenticated account when available, otherwise an installation-scoped
    /// identifier so unrelated signed-out viewers never share a literal cloud identity.
    static func viewerID(authenticatedUserID: String?) -> String {
        if let authenticatedUserID, !authenticatedUserID.isEmpty {
            return authenticatedUserID
        }
        if let existing = UserDefaults.standard.string(forKey: localViewerDefaultsKey),
           !existing.isEmpty {
            return existing
        }
        let generated = "local-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(generated, forKey: localViewerDefaultsKey)
        return generated
    }

    /// 🔥 FIX: Lazily resolve Firestore only when Firebase is configured.
    /// A stored `let db = Firestore.firestore()` traps (hard crash) when
    /// `FirebaseApp.app() == nil`, which can happen if a caller (e.g.
    /// VideoDetailView.onDisappear → saveProgress) touches this singleton
    /// before Firebase finishes configuring.
    private var db: Firestore? {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        #endif
        return Firestore.firestore()
    }

    func saveProgress(
        userId: String,
        videoId: String,
        position: Double,
        duration: Double,
        force: Bool = false
    ) async throws {
        guard position.isFinite, duration.isFinite, position >= 0, duration > 0 else { return }

        let pct = min(1.0, position / duration)
        let docId = "\(userId)_\(videoId)"
        if !force, let previous = lastSavedValues[docId],
           abs(previous.position - position) < 1,
           abs(previous.duration - duration) < 1 {
            return
        }
        lastSavedValues[docId] = (position, duration)

        let data: [String: Any] = [
            "userId": userId,
            "videoId": videoId,
            "position": position,
            "duration": duration,
            "pct": pct,
            "lastWatched": FieldValue.serverTimestamp()
        ]
        if let db = db {
            do {
                try await db.collection("watch_progress").document(docId).setData(data, merge: true)
            } catch {
                #if DEBUG
                print("⚠️ [WatchProgress] saveProgress skipped: \(error.localizedDescription)")
                #endif
            }
        }
        let watchProgress = WatchProgress(
            id: docId,
            userId: userId,
            videoId: videoId,
            positionSec: position,
            durationSec: duration,
            completionPct: pct,
            lastWatchedAt: Date()
        )
        progress[videoId] = watchProgress
    }

    func fetchProgress(userId: String, videoId: String) async throws -> WatchProgress? {
        guard let db = db else { return progress[videoId] }
        let docId = "\(userId)_\(videoId)"
        let snapshot = try await db.collection("watch_progress").document(docId).getDocument()
        guard let data = snapshot.data() else { return nil }
        let wp = WatchProgress(id: docId, userId: userId, videoId: videoId,
            positionSec: data["position"] as? Double ?? 0, durationSec: data["duration"] as? Double ?? 0,
            completionPct: data["pct"] as? Double ?? 0, lastWatchedAt: Self.lastWatched(from: data))
        progress[videoId] = wp; return wp
    }

    func fetchAllInProgress(userId: String) async throws {
        guard let db = db else { return }
        let snapshot = try await db.collection("watch_progress")
            .whereField("userId", isEqualTo: userId)
            .whereField("pct", isLessThan: 0.9)
            .order(by: "lastWatched", descending: true)
            .limit(to: 50)
            .getDocuments()
        for doc in snapshot.documents {
            let data = doc.data()
            let videoId = data["videoId"] as? String ?? ""
            let wp = WatchProgress(id: doc.documentID, userId: userId, videoId: videoId,
                positionSec: data["position"] as? Double ?? 0, durationSec: data["duration"] as? Double ?? 0,
                completionPct: data["pct"] as? Double ?? 0, lastWatchedAt: Self.lastWatched(from: data))
            progress[videoId] = wp
        }
    }

    /// Read the persisted `lastWatched` server timestamp. Falls back to now so a
    /// freshly-written doc (before the server timestamp resolves) still sorts sanely.
    private static func lastWatched(from data: [String: Any]) -> Date {
        if let ts = data["lastWatched"] as? Timestamp { return ts.dateValue() }
        if let date = data["lastWatched"] as? Date { return date }
        return Date()
    }

    func resumePosition(userId: String, videoId: String) -> Double {
        guard let saved = progress[videoId], saved.userId == userId else { return 0 }
        return saved.positionSec
    }
}
