// WatchStore.swift
// Central state + WatchConnectivity bridge for the watchOS app.
//
// Communicates with the iPhone companion via WCSession:
//   • Sends play/pause/skip/seek commands to the phone
//   • Receives now-playing metadata, queue, and feed updates
//   • Stores watch-side cache of latest videos and history

import SwiftUI
import WatchConnectivity
#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

// MARK: - Lightweight models (no shared module dependency)

struct WatchVideo: Identifiable, Equatable {
    let id: String
    let title: String
    let channelName: String
    let thumbnailURL: String
    let durationSeconds: Int
    var isLive: Bool = false
}

struct WatchNowPlaying: Equatable {
    var videoId: String = ""
    var title: String = ""
    var channelName: String = ""
    var thumbnailURL: String = ""
    var isPlaying: Bool = false
    var currentSeconds: Double = 0
    var durationSeconds: Double = 0
    var isMuted: Bool = false

    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, currentSeconds / durationSeconds)
    }

    var isEmpty: Bool { videoId.isEmpty }
}

struct WatchNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let thumbnailURL: String
    let videoId: String
    let createdAt: Date
    var isRead: Bool = false
}

// MARK: - WatchStore

@MainActor
final class WatchStore: NSObject, ObservableObject {

    // Now Playing (reflected from phone)
    @Published var nowPlaying = WatchNowPlaying()

    // Feed data (fetched from Firestore directly on watch)
    @Published var subscriptionFeed: [WatchVideo] = []
    @Published var watchHistory: [WatchVideo] = []
    @Published var watchLater: [WatchVideo] = []
    @Published var trendingVideos: [WatchVideo] = []
    @Published var notifications: [WatchNotification] = []

    @Published var isLoadingFeed = false
    @Published var unreadNotifications = 0
    @Published var isPhoneReachable = false

    private var session: WCSession?

    override init() {
        super.init()
        setupWatchConnectivity()
        Task { await loadFeedFromFirestore() }
    }

    // MARK: - WatchConnectivity setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        session = s
    }

    // MARK: - Playback commands → iPhone

    func sendCommand(_ cmd: String, payload: [String: Any] = [:]) {
        var msg: [String: Any] = ["cmd": cmd]
        msg.merge(payload) { _, new in new }
        session?.sendMessage(msg, replyHandler: nil) { _ in
            // Phone not reachable — store as outstanding command
        }
    }

    func play()  { sendCommand("play") }
    func pause() { sendCommand("pause") }
    func skip()  { sendCommand("skip") }
    func previous() { sendCommand("previous") }

    func seek(to fraction: Double) {
        sendCommand("seek", payload: ["fraction": fraction])
    }

    func openVideo(_ videoId: String) {
        sendCommand("openVideo", payload: ["videoId": videoId])
    }

    func addToWatchLater(_ videoId: String) {
        sendCommand("addWatchLater", payload: ["videoId": videoId])
    }

    func removeFromWatchLater(_ videoId: String) {
        sendCommand("removeWatchLater", payload: ["videoId": videoId])
    }

    func toggleMute() {
        nowPlaying.isMuted.toggle()
        sendCommand("mute", payload: ["muted": nowPlaying.isMuted])
    }

    // MARK: - Firestore feed (watch fetches independently for offline resilience)

    func loadFeedFromFirestore() async {
        isLoadingFeed = true
        defer { isLoadingFeed = false }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            // Trending
            let snap = try await db.collection("videos")
                .whereField("isPublic", isEqualTo: true)
                .order(by: "viewCount", descending: true)
                .limit(to: 20)
                .getDocuments()
            trendingVideos = snap.documents.compactMap { toWatchVideo($0) }

            // Watch history (if signed in)
            if let uid = Auth.auth().currentUser?.uid {
                let histSnap = try await db.collection("users").document(uid)
                    .collection("watchHistory")
                    .order(by: "watchedAt", descending: true)
                    .limit(to: 20)
                    .getDocuments()

                let histIds = histSnap.documents.compactMap { $0.data()["videoId"] as? String }
                if !histIds.isEmpty {
                    let vids = try await fetchVideos(ids: Array(histIds.prefix(10)), db: db)
                    watchHistory = vids
                }

                // Watch later
                let wlSnap = try await db.collection("users").document(uid)
                    .collection("watchLater")
                    .order(by: "addedAt", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                let wlIds = wlSnap.documents.compactMap { $0.data()["videoId"] as? String }
                if !wlIds.isEmpty {
                    watchLater = try await fetchVideos(ids: Array(wlIds.prefix(10)), db: db)
                }

                // Notifications
                let notifSnap = try await db.collection("notifications")
                    .whereField("userId", isEqualTo: uid)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 20)
                    .getDocuments()

                notifications = notifSnap.documents.compactMap { doc -> WatchNotification? in
                    let d = doc.data()
                    guard let title = d["title"] as? String else { return nil }
                    return WatchNotification(
                        id: doc.documentID,
                        title: title,
                        body: d["body"] as? String ?? "",
                        thumbnailURL: d["thumbnailURL"] as? String ?? "",
                        videoId: d["videoId"] as? String ?? "",
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: d["isRead"] as? Bool ?? false
                    )
                }
                unreadNotifications = notifications.filter { !$0.isRead }.count
            }
        } catch {
            print("⌚️ [WatchStore] Firestore error: \(error.localizedDescription)")
        }
        #else
        trendingVideos = WatchVideo.samples
        #endif
    }

    private func fetchVideos(ids: [String], db: FirebaseFirestore.Firestore) async throws -> [WatchVideo] {
        try await withThrowingTaskGroup(of: WatchVideo?.self) { group in
            for id in ids {
                group.addTask {
                    guard let snap = try? await db.collection("videos").document(id).getDocument(),
                          snap.exists else { return nil }
                    return self.toWatchVideo(snap)
                }
            }
            var result: [WatchVideo] = []
            for try await v in group { if let v { result.append(v) } }
            return result
        }
    }

    private func toWatchVideo(_ doc: DocumentSnapshot) -> WatchVideo? {
        let d = doc.data() ?? [:]
        guard let title = d["title"] as? String else { return nil }
        return WatchVideo(
            id: doc.documentID,
            title: title,
            channelName: d["channelName"] as? String ?? "Creator",
            thumbnailURL: (d["thumbnailURL"] as? String) ?? "",
            durationSeconds: Int((d["duration"] as? Double) ?? 0),
            isLive: d["isLive"] as? Bool ?? false
        )
    }

    // MARK: - Sample data fallback

    func markNotificationRead(_ id: String) {
        notifications = notifications.map {
            $0.id == id ? WatchNotification(id: $0.id, title: $0.title, body: $0.body,
                thumbnailURL: $0.thumbnailURL, videoId: $0.videoId,
                createdAt: $0.createdAt, isRead: true) : $0
        }
        unreadNotifications = notifications.filter { !$0.isRead }.count
    }
}

// MARK: - WCSessionDelegate

extension WatchStore: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        isPhoneReachable = session.isReachable
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isPhoneReachable = session.isReachable
    }

    // Receive now-playing state updates pushed from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "nowPlaying":
            nowPlaying = WatchNowPlaying(
                videoId: message["videoId"] as? String ?? "",
                title: message["title"] as? String ?? "",
                channelName: message["channelName"] as? String ?? "",
                thumbnailURL: message["thumbnailURL"] as? String ?? "",
                isPlaying: message["isPlaying"] as? Bool ?? false,
                currentSeconds: message["currentSeconds"] as? Double ?? 0,
                durationSeconds: message["durationSeconds"] as? Double ?? 0,
                isMuted: message["isMuted"] as? Bool ?? false
            )
        case "feedUpdate":
            Task { await loadFeedFromFirestore() }
        default:
            break
        }
    }

    // Application context (background sync)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let nowPlayingData = applicationContext["nowPlaying"] as? [String: Any] {
            nowPlaying = WatchNowPlaying(
                videoId: nowPlayingData["videoId"] as? String ?? "",
                title: nowPlayingData["title"] as? String ?? "",
                channelName: nowPlayingData["channelName"] as? String ?? "",
                thumbnailURL: nowPlayingData["thumbnailURL"] as? String ?? "",
                isPlaying: nowPlayingData["isPlaying"] as? Bool ?? false,
                currentSeconds: nowPlayingData["currentSeconds"] as? Double ?? 0,
                durationSeconds: nowPlayingData["durationSeconds"] as? Double ?? 0
            )
        }
    }
}

// MARK: - Sample data

extension WatchVideo {
    static let samples: [WatchVideo] = [
        WatchVideo(id: "1", title: "How to Build an App in 2025", channelName: "Tech Weekly", thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg", durationSeconds: 847),
        WatchVideo(id: "2", title: "The Future of AI", channelName: "AI Insights", thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg", durationSeconds: 1203),
        WatchVideo(id: "3", title: "Live: Global Championship", channelName: "Sports Now", thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg", durationSeconds: 0, isLive: true),
    ]
}
