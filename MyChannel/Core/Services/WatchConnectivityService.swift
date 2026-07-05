// WatchConnectivityService.swift
// MyChannel iOS → Apple Watch bridge.
//
// Observes GlobalVideoPlayerManager and pushes now-playing state to the
// paired Apple Watch whenever playback state changes. Also handles commands
// received from the watch (play/pause/skip/seek/openVideo/watchLater).
//
// Usage: called from MyChannelApp.init() or LazyServiceManager.
//   WatchConnectivityService.shared.activate()

import Foundation
import WatchConnectivity
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    private override init() {}

    @Published private(set) var isPaired = false
    @Published private(set) var isReachable = false

    private var cancellables = Set<AnyCancellable>()
    private var debounceTask: Task<Void, Never>?

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        // Observe GlobalVideoPlayerManager and push updates to watch
        Task { @MainActor in
            let gp = GlobalVideoPlayerManager.shared
            gp.$currentVideo
                .combineLatest(gp.$isPlaying, gp.$currentTime, gp.$duration)
                .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
                .sink { [weak self] (video, isPlaying, time, duration) in
                    self?.pushNowPlaying(
                        video: video,
                        isPlaying: isPlaying,
                        currentTime: time,
                        duration: duration
                    )
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Push now-playing state to watch

    private func pushNowPlaying(
        video: Video?,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) {
        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = [
            "type": "nowPlaying",
            "videoId": video?.id ?? "",
            "title": video?.title ?? "",
            "channelName": (video as? Video)?.creator.displayName ?? "",
            "thumbnailURL": video?.thumbnailURL ?? "",
            "isPlaying": isPlaying,
            "currentSeconds": currentTime,
            "durationSeconds": duration,
            "isMuted": false
        ]

        // Try real-time message first (watch app must be frontmost)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { _ in
                // Not reachable in real-time — update application context as background sync
                try? WCSession.default.updateApplicationContext(["nowPlaying": payload])
            }
        } else {
            // Background context so watch gets it when it wakes up
            try? WCSession.default.updateApplicationContext(["nowPlaying": payload])
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isPaired = session.isPaired
            isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()   // required for Watch switching
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in isReachable = session.isReachable }
    }

    // Handle commands from the watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let cmd = message["cmd"] as? String else { return }
        Task { @MainActor in
            let gp = GlobalVideoPlayerManager.shared
            switch cmd {
            case "play":
                gp.player?.play()
                // Also update the published isPlaying state
                if let pm = gp.player { pm.play() }
            case "pause":
                gp.player?.pause()
            case "skip":
                gp.playNextVideo()
            case "previous":
                gp.playPreviousVideo()
            case "seek":
                if let fraction = message["fraction"] as? Double {
                    // seek(to:) takes 0-1 progress fraction
                    gp.seek(to: fraction)
                }
            case "openVideo":
                if let videoId = message["videoId"] as? String {
                    // Post notification so MainTabView opens the video
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToVideoId"),
                        object: videoId
                    )
                }
            case "addWatchLater":
                if let videoId = message["videoId"] as? String {
                    Task { try? await WatchLaterService.shared.add(videoId: videoId) }
                }
            case "removeWatchLater":
                if let videoId = message["videoId"] as? String {
                    Task { try? await WatchLaterService.shared.remove(videoId: videoId) }
                }
            case "mute":
                if let muted = message["muted"] as? Bool {
                    gp.player?.isMuted = muted
                }
            case "search":
                if let query = message["query"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WatchSearchQuery"),
                        object: query
                    )
                }
            default:
                break
            }
        }
    }
}

// MARK: - Minimal WatchLaterService stub — delegates to the real iOS WatchLaterService
// The iOS WatchLaterService stores to users/{uid}/watchLater/{videoId} in Firestore.

private final class WatchLaterService {
    static let shared = WatchLaterService()
    private init() {}

    func add(videoId: String) async throws {
        guard let uid = await MainActor.run(body: { AuthenticationManager.shared.currentUser?.id }) else { return }
        let db = Firestore.firestore()
        try await db.collection("users").document(uid)
            .collection("watchLater").document(videoId)
            .setData(["videoId": videoId, "addedAt": FieldValue.serverTimestamp()])
    }

    func remove(videoId: String) async throws {
        guard let uid = await MainActor.run(body: { AuthenticationManager.shared.currentUser?.id }) else { return }
        let db = Firestore.firestore()
        try await db.collection("users").document(uid)
            .collection("watchLater").document(videoId)
            .delete()
    }
}
