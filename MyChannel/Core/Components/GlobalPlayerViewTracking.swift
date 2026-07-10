//
//  GlobalPlayerViewTracking.swift
//  MyChannel
//
//  Real-time view sessions + MyChannel University watch attribution
//  extracted from GlobalVideoPlayerManager.
//

import Foundation

@MainActor
final class GlobalPlayerViewTracking {
    typealias UniversityWatchFlushHandler = (
        _ video: Video,
        _ watchTime: TimeInterval,
        _ completion: Double,
        _ viewToken: String?
    ) -> Void

    var currentTime: () -> TimeInterval = { 0 }
    var duration: () -> TimeInterval = { 0 }
    var isPlaying: () -> Bool = { false }
    var hasCurrentVideo: () -> Bool = { false }

    private let viewTracker = RealtimeViewTracker.shared
    private let onUniversityWatchFlush: UniversityWatchFlushHandler

    private var currentViewSessionId: String?
    private var heartbeatTimer: Timer?

    // Snapshotted at session start so it survives synchronous state resets in
    // closePlayer()/nuclearReset() that run before the async end() Task.
    private var universityWatchVideo: Video?
    private var universityMaxPosition: TimeInterval = 0
    // Single-use, server-minted proof this session's view is real (see
    // issueUniversityViewToken / consumeViewToken). Requested once per session.
    private var universityViewToken: String?

    /// Heartbeat interval for RealtimeViewTracker (verified in PlayerLifecycleTests).
    static let heartbeatIntervalSeconds: TimeInterval = 10

    /// Single playback session ID — shared across global player surfaces for analytics correlation.
    var playbackSessionID: String? { currentViewSessionId }

    init(onUniversityWatchFlush: @escaping UniversityWatchFlushHandler) {
        self.onUniversityWatchFlush = onUniversityWatchFlush
    }

    /// Flush university attribution before queue skip/switch so fast next/previous
    /// does not race the async view-token mint.
    func flushUniversityWatchBeforeSwitch() {
        flushUniversityWatch()
    }

    func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Self.heartbeatIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.sendViewHeartbeat()
            }
        }
    }

    func start(for video: Video) async {
        flushUniversityWatch()

        if let sessionId = currentViewSessionId {
            await viewTracker.endViewSession(sessionId: sessionId)
        }

        let userId = AuthenticationManager.shared.currentUser?.id
        await viewTracker.startViewSession(videoId: video.id, userId: userId)

        currentViewSessionId = UUID().uuidString

        universityWatchVideo = video
        universityMaxPosition = 0
        universityViewToken = nil
        Task { [weak self, videoId = video.id] in
            let token = await UniversityWatchTrackingService.shared.requestViewToken(videoId: videoId)
            await MainActor.run {
                guard self?.universityWatchVideo?.id == videoId else { return }
                self?.universityViewToken = token
            }
        }

        print("👁️ [GlobalPlayer] Started view tracking for: \(video.title)")
    }

    func end() async {
        flushUniversityWatch()

        guard let sessionId = currentViewSessionId else { return }

        await viewTracker.endViewSession(sessionId: sessionId)
        currentViewSessionId = nil

        print("👋 [GlobalPlayer] Ended view tracking")
    }

    private func sendViewHeartbeat() async {
        guard let sessionId = currentViewSessionId,
              hasCurrentVideo() else { return }

        let time = currentTime()
        universityMaxPosition = max(universityMaxPosition, time)

        await viewTracker.updateViewHeartbeat(
            sessionId: sessionId,
            currentTime: time,
            isPlaying: isPlaying()
        )
    }

    /// Report the just-watched session to MyChannel University so learning hours,
    /// career-path progress, certificates, and streaks advance from real playback.
    /// Uses the session snapshot (not live playback state) so it stays correct even
    /// after closePlayer()/nuclearReset() have already zeroed live state.
    private func flushUniversityWatch() {
        guard let video = universityWatchVideo else { return }
        universityWatchVideo = nil
        let token = universityViewToken
        universityViewToken = nil

        let watched = max(universityMaxPosition, currentTime())
        universityMaxPosition = 0

        guard watched >= 30 else { return }

        let total = duration() > 0 ? duration() : video.duration
        let completion = total > 0 ? min(1.0, watched / total) : 0

        onUniversityWatchFlush(video, watched, completion, token)
    }
}
