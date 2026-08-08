import SwiftUI
import AVKit
import Combine
import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

struct VideoPlaybackSession: Equatable {
    struct Ads: Equatable {
        let isEnabled: Bool
        let isPersonalized: Bool
    }

    struct Capabilities: Equatable {
        let supportsHLS: Bool
        let supportsCaptions: Bool
        let supportsOfflineDownload: Bool
        let supportsPictureInPicture: Bool
        let supportsCasting: Bool
    }

    let id: String
    let videoId: String
    let manifestURL: URL
    let expiresAt: Date?
    let ads: Ads
    let capabilities: Capabilities
}

enum VideoPlaybackSessionError: LocalizedError {
    case authenticationRequired
    case serviceUnavailable
    case timedOut
    case denied(String?)
    case invalidResponse
    case expired

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Sign in to watch this video"
        case .serviceUnavailable:
            return "Playback service is unavailable"
        case .timedOut:
            return "Playback timed out. Please try again."
        case .denied(let reason):
            switch reason {
            case "age_verification_required": return "Age verification is required"
            case "app_check_required": return "Device verification is required"
            case "region_denied": return "This video is not available in your region"
            case "entitlement_required": return "A channel membership is required"
            case "processing_not_ready": return "This video is still processing"
            case "moderation_not_approved": return "This video is under review"
            case "visibility_denied": return "This video is unavailable"
            default: return "Video unavailable"
            }
        case .invalidResponse:
            return "Playback authorization was invalid"
        case .expired:
            return "Playback authorization expired"
        }
    }
}

enum SafePlaybackURL {
    private static let mediaHosts = [
        "firebasestorage.googleapis.com", "storage.googleapis.com",
        "commondatastorage.googleapis.com", "devstreaming-cdn.apple.com",
        "akamaized.net", "cloudfront.net", "mychannel.live"
    ]
    private static let imageHosts = mediaHosts + [
        "ytimg.com", "imgur.com", "cloudinary.com", "googleusercontent.com",
        "pluto.tv", "image.tmdb.org", "m.media-amazon.com"
    ]
    private static let externalHosts = [
        "mychannel.live", "youtube.com", "youtu.be", "instagram.com",
        "tiktok.com", "twitch.tv", "twitter.com", "x.com"
    ]

    static func manifest(_ value: String) -> URL? {
        guard let url = approved(value, hosts: mediaHosts),
              url.path.lowercased().hasSuffix(".m3u8") else { return nil }
        return url
    }

    static func image(_ value: String) -> URL? {
        approved(value, hosts: imageHosts)
    }

    static func external(_ value: String) -> URL? {
        approved(value, hosts: externalHosts)
    }

    private static func approved(_ value: String, hosts: [String]) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              url.user == nil,
              url.password == nil,
              hosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            return nil
        }
        return url
    }
}

actor VideoPlaybackSessionService {
    static let shared = VideoPlaybackSessionService()

    private struct Response: Decodable {
        struct Ads: Decodable { let enabled: Bool; let personalized: Bool }
        struct Capabilities: Decodable {
            let hls: Bool
            let captions: Bool
            let offlineDownload: Bool
            let pictureInPicture: Bool
            let casting: Bool
        }

        let version: String
        let sessionId: String
        let videoId: String
        let canPlay: Bool
        let denialReason: String?
        let playbackManifestUrl: String?
        let expiresAt: String?
        let ads: Ads
        let capabilities: Capabilities
    }

    func authorize(videoId: String) async throws -> VideoPlaybackSession {
        guard videoId.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil,
              let baseURL = AppConfig.API.contentAPIBaseURL else {
            throw VideoPlaybackSessionError.serviceUnavailable
        }
        guard let token = try await AuthenticationManager.sharedToken(), !token.isEmpty else {
            throw VideoPlaybackSessionError.authenticationRequired
        }

        let endpoint = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("videos")
            .appendingPathComponent(videoId)
            .appendingPathComponent("playback-session")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appCheckToken = await appCheckToken() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200...499).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["policy"] is [String: Any] else {
            throw VideoPlaybackSessionError.invalidResponse
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.version == "1.0",
              response.videoId == videoId,
              response.sessionId.range(
                of: "^[A-Za-z0-9_-]{1,128}$",
                options: .regularExpression
              ) != nil else {
            throw VideoPlaybackSessionError.invalidResponse
        }
        guard response.canPlay else {
            throw VideoPlaybackSessionError.denied(response.denialReason)
        }
        guard response.capabilities.hls,
              let manifestValue = response.playbackManifestUrl,
              let manifestURL = SafePlaybackURL.manifest(manifestValue) else {
            throw VideoPlaybackSessionError.invalidResponse
        }

        let expiresAt = response.expiresAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        if let expiresAt, expiresAt <= Date() {
            throw VideoPlaybackSessionError.expired
        }
        return VideoPlaybackSession(
            id: response.sessionId,
            videoId: videoId,
            manifestURL: manifestURL,
            expiresAt: expiresAt,
            ads: VideoPlaybackSession.Ads(
                isEnabled: response.ads.enabled,
                isPersonalized: response.ads.personalized
            ),
            capabilities: VideoPlaybackSession.Capabilities(
                supportsHLS: response.capabilities.hls,
                supportsCaptions: response.capabilities.captions,
                supportsOfflineDownload: response.capabilities.offlineDownload,
                supportsPictureInPicture: response.capabilities.pictureInPicture,
                supportsCasting: response.capabilities.casting
            )
        )
    }

    private func appCheckToken() async -> String? {
        #if canImport(FirebaseAppCheck)
        guard FirebaseManager.shared.isConfigured else { return nil }
        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    AppCheck.appCheck().token(forcingRefresh: false) { token, _ in
                        continuation.resume(returning: token?.token)
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
        #else
        return nil
        #endif
    }
}

extension VideoDetailView {
    // MARK: - Helper Methods

    var activePlayerManager: VideoPlayerManager {
        if isUsingGlobalPlayer,
           globalPlayer.currentVideo?.id == video.id,
           let retainedManager = globalPlayer.exposedPlayerManager {
            return retainedManager
        }
        return playerManager
    }

    var effectivePlaybackSession: VideoPlaybackSession? {
        if globalPlayer.currentVideo?.id == video.id,
           let retainedSession = globalPlayer.authorizedPlaybackSession {
            return retainedSession
        }
        return playbackSession
    }

    var effectivePlayableVideo: Video? {
        if globalPlayer.currentVideo?.id == video.id,
           let retainedVideo = globalPlayer.authorizedPlayableVideo {
            return retainedVideo
        }
        return authorizedVideo
    }

    var activePlaybackTime: TimeInterval {
        let seconds = activePlayerManager.player?.currentTime().seconds
            ?? activePlayerManager.currentTime
        return seconds.isFinite ? max(0, seconds) : 0
    }

    var activePlaybackDuration: TimeInterval {
        let itemSeconds = activePlayerManager.player?.currentItem?.duration.seconds
        let seconds = itemSeconds?.isFinite == true
            ? itemSeconds ?? 0
            : activePlayerManager.duration
        return seconds.isFinite ? max(0, seconds) : 0
    }

    @MainActor
    func authorizeAndStartPlayback() async {
        authorizationGeneration &+= 1
        let generation = authorizationGeneration
        playbackAuthorization = .checking
        playbackSession = nil
        authorizedVideo = nil
        hasStartedContentPlayback = false
        lastProgressSaveSecond = -1
        showingYouTubeAd = false
        currentVideoAd = nil
        adLoadTimeoutTask?.cancel()
        adLoadTimeoutTask = nil

        // Members-only: block before we burn a playback session / start audio.
        if AppConfig.Features.enableMembershipPerks, video.isMembersOnly == true {
            checkingMembership = true
            defer { checkingMembership = false }
            if let uid = AppState.shared.currentUser?.id {
                await checkMembershipAccess(channelId: video.creatorId, userId: uid)
            } else {
                membershipGateActive = true
            }
            guard !userExplicitlyClosed, generation == authorizationGeneration else { return }
            if membershipGateActive {
                // Keep .checking so the membership overlay (not a dead blocked screen) is primary.
                playbackAuthorization = .checking
                return
            }
        }

        do {
            let session: VideoPlaybackSession = try await withThrowingTaskGroup(of: VideoPlaybackSession.self) { group in
                group.addTask {
                    try await VideoPlaybackSessionService.shared.authorize(videoId: video.id)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 12_000_000_000)
                    throw VideoPlaybackSessionError.timedOut
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            guard !userExplicitlyClosed, generation == authorizationGeneration else { return }
            guard session.videoId == video.id else {
                throw VideoPlaybackSessionError.invalidResponse
            }
            var playableVideo = video
            playableVideo.videoURL = session.manifestURL.absoluteString
            playbackSession = session
            authorizedVideo = playableVideo
            playbackAuthorization = .allowed
            schedulePlaybackRenewal(for: session)

            guard session.ads.isEnabled else {
                startContentPlayback()
                return
            }

            let allowsPersonalization = UserDefaults.standard.bool(
                forKey: "preferences.personalizedAdsEnabled"
            )
            adManager.onAdComplete = {
                Task { @MainActor in
                    guard !userExplicitlyClosed else { return }
                    showingYouTubeAd = false
                    currentVideoAd = nil
                    adLoadTimeoutTask?.cancel()
                    startContentPlayback()
                }
            }
            adManager.onAdSkipped = {
                Task { @MainActor in
                    guard !userExplicitlyClosed else { return }
                    showingYouTubeAd = false
                    currentVideoAd = nil
                    adLoadTimeoutTask?.cancel()
                    startContentPlayback()
                }
            }
            adManager.requestPreRollAd(
                for: video,
                personalized: session.ads.isPersonalized && allowsPersonalization
            ) { ad in
                Task { @MainActor in
                    guard !userExplicitlyClosed else { return }
                    guard let ad else {
                        startContentPlayback()
                        return
                    }
                    currentVideoAd = ad
                    showingYouTubeAd = true
                    adManager.playAd(ad)
                    // If the ad never becomes ready, fall through to content.
                    adLoadTimeoutTask?.cancel()
                    adLoadTimeoutTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 8_000_000_000)
                        guard !Task.isCancelled, !userExplicitlyClosed else { return }
                        guard showingYouTubeAd, !adManager.isAdVideoReady else { return }
                        showingYouTubeAd = false
                        currentVideoAd = nil
                        startContentPlayback()
                    }
                }
            }

            Task {
                if let vmap = await AdsService.shared.fetchVMAP(videoId: video.id) {
                    await MainActor.run {
                        guard !userExplicitlyClosed else { return }
                        midrolls = vmap.midrolls ?? []
                        servedMidrollIndices = []
                    }
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard !userExplicitlyClosed, generation == authorizationGeneration else { return }
            playerManager.pause()
            playbackAuthorization = .blocked(
                (error as? LocalizedError)?.errorDescription ?? "Video unavailable"
            )
        }
    }

    @MainActor
    func schedulePlaybackRenewal(for session: VideoPlaybackSession) {
        playbackRenewalTask?.cancel()
        guard let expiresAt = session.expiresAt else { return }
        let delay = max(1, expiresAt.timeIntervalSinceNow - 60)

        playbackRenewalTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let renewed = try await VideoPlaybackSessionService.shared.authorize(
                    videoId: video.id
                )
                guard renewed.videoId == video.id else {
                    throw VideoPlaybackSessionError.invalidResponse
                }

                let previousURL = playbackSession?.manifestURL
                playbackSession = renewed
                var playableVideo = video
                playableVideo.videoURL = renewed.manifestURL.absoluteString
                authorizedVideo = playableVideo
                playbackAuthorization = .allowed

                if renewed.manifestURL != previousURL {
                    pendingAuthorizationResumeTime = activePlaybackTime
                    hasStartedContentPlayback = false
                    playerManager.pause()
                    startContentPlayback()
                }
                schedulePlaybackRenewal(for: renewed)
            } catch is CancellationError {
                return
            } catch {
                playerManager.pause()
                playbackAuthorization = .blocked(
                    (error as? LocalizedError)?.errorDescription ?? "Video unavailable"
                )
            }
        }
    }

    @MainActor
    func startContentPlayback() {
        guard !userExplicitlyClosed else { return }
        guard !membershipGateActive else {
            activePlayerManager.pause()
            return
        }
        guard !hasStartedContentPlayback,
              case .allowed = playbackAuthorization,
              let session = playbackSession,
              let playableVideo = authorizedVideo else { return }
        if let expiresAt = session.expiresAt, expiresAt <= Date() {
            playbackAuthorization = .blocked("Playback authorization expired")
            return
        }

        hasStartedContentPlayback = true
        playerManager.setupPlayer(with: playableVideo)
        playerManager.applyFastStartTuning()
        if AppState.shared.preferredVideoQuality != .auto {
            playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
            videoQuality = AppState.shared.preferredVideoQuality
        }
        playerManager.requestAutoPlay()
        globalPlayer.registerLocalPlayer(
            video: video,
            playableVideo: playableVideo,
            session: session,
            manager: playerManager
        )
        isUsingGlobalPlayer = true
        playbackRenewalTask?.cancel()
        playbackRenewalTask = nil
    }

    func handlePlaybackStateChanged(_ isPlaying: Bool) {
        controlsCoordinator.updatePlayingState(isPlaying)
        guard isPlaying else { return }
        Task {
            let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
            await MainActor.run { currentViewCount = latestCount }
        }
    }

    func handleDurationChange(_ newDuration: Double) {
        guard newDuration > 0 else { return }
        let manager = activePlayerManager
        if let resumeTime = pendingAuthorizationResumeTime {
            pendingAuthorizationResumeTime = nil
            let fraction = resumeTime / newDuration
            if fraction > 0 && fraction < 0.99 {
                manager.seek(to: fraction)
                return
            }
        }
        if manager.selectedQuality == .auto {
            manager.autoSelectQuality()
        }
        // 🔗 Deep link (?t=) takes priority over resume position.
        if let deepLinkSeconds = DeepLinkService.shared.consumeSeek(for: video.id) {
            let fraction = deepLinkSeconds / newDuration
            if fraction > 0 && fraction < 0.99 {
                #if DEBUG
                print("[DeepLink] Starting at \(Int(deepLinkSeconds)) seconds")
                #endif
                manager.seek(to: fraction)
                return
            }
        }
        let userId = AppState.shared.currentUser?.id ?? ""
        let savedPosition = WatchProgressService.shared.resumePosition(userId: userId, videoId: video.id)
        guard savedPosition > 0 else { return }
        let fraction = savedPosition / newDuration
        if fraction > 0.02 && fraction < 0.95 {
            manager.seek(to: fraction)
        }
    }

    // MARK: - Membership Access Gate

    func checkMembershipAccess(channelId: String, userId: String) async {
        await MainActor.run { checkingMembership = true }
        #if canImport(FirebaseFirestore)
        let docId = "\(channelId)_\(userId)"
        let snap = try? await Firestore.firestore()
            .collection("channel-memberships")
            .document(docId)
            .getDocument()
        let isActive = snap?.data()?["status"] as? String == "active"
        await MainActor.run {
            membershipGateActive = !isActive
            if membershipGateActive { activePlayerManager.pause() }
            checkingMembership = false
        }
        #else
        await MainActor.run {
            membershipGateActive = false
            checkingMembership = false
        }
        #endif
    }

    func handleCurrentTimeChange() {
        let newTime = activePlaybackTime
        let duration = activePlaybackDuration
        if duration > 0 {
            let roundedTime = Int(newTime)
            if roundedTime > 0,
               roundedTime % 5 == 0,
               roundedTime != lastProgressSaveSecond,
               let userId = AppState.shared.currentUser?.id {
                lastProgressSaveSecond = roundedTime
                Task {
                    try? await WatchProgressService.shared.saveProgress(
                        userId: userId,
                        videoId: video.id,
                        position: newTime,
                        duration: duration
                    )
                }
            }
            watchProgress = newTime / duration
            // 🔥 PERF: Report each quartile milestone exactly once. Previously the
            // 50%/75% branches spawned a fresh Task on every time-observer tick for
            // the rest of the video (hundreds of redundant main-actor hops) and the
            // 75% branch was unreachable behind the 50% `else if`.
            if !hasWatchedThreshold && watchProgress >= 0.25 {
                hasWatchedThreshold = true
            }
            for (threshold, quartile) in [(0.25, 1), (0.5, 2), (0.75, 3), (0.98, 4)] {
                if watchProgress >= threshold && !trackedQuartiles.contains(quartile) {
                    trackedQuartiles.insert(quartile)
                    Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: quartile) }
                }
            }
        }
        let manager = activePlayerManager
        if speedCurvesService.autoSkipSilence {
            if let seg = speedCurvesService.silenceSegments.first(where: { newTime >= $0.startSec && newTime <= $0.endSec }),
               manager.duration > 0 {
                let skipTo = seg.endSec / manager.duration
                manager.seek(to: min(1.0, skipTo))
                withAnimation(reduceMotion ? nil : .easeInOut) { showSilenceSkipIndicator = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation(reduceMotion ? nil : .easeInOut) { showSilenceSkipIndicator = false }
                }
            }
        }
        // 🔥 PERF: Use the pre-sorted chapters cached on appear (no per-tick sort).
        if !sortedChapters.isEmpty,
           let current = sortedChapters.last(where: { $0.start <= newTime }) {
            let title = current.title
            if currentChapterTitle != title {
                currentChapterTitle = title
            }
        }
        // Check for active polls at current playback time
        if AppConfig.Features.enableVideoPollsQuizzes && displayedPoll == nil {
            pollService.checkActive(currentTime: newTime)
            if let sp = pollService.activePoll, !pollService.hasVoted.contains(sp.id) {
                displayedPoll = VideoPoll(
                    id: sp.id,
                    videoId: sp.videoId,
                    question: sp.question,
                    options: sp.options.enumerated().map { idx, opt in
                        VideoPollOption(id: opt.id, text: opt.text, voteCount: opt.voteCount, order: idx)
                    },
                    timestamp: sp.timestampSec,
                    displayDuration: sp.durationSec
                )
            }
        }
        // Update Info Card overlay timing
        infoCardManager.updatePlaybackTime(newTime)
        if let cards = video.videoCards {
            for card in cards {
                if abs(newTime - card.timestamp) < 0.5 && currentVideoCard?.id != card.id {
                    currentVideoCard = card
                    showingVideoCards = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 8_000_000_000)
                        if currentVideoCard?.id == card.id {
                            showingVideoCards = false
                            currentVideoCard = nil
                        }
                    }
                }
            }
        }
        if !midrolls.isEmpty, !showingAd, manager.duration > 0 {
            let uid = AppState.shared.currentUser?.id ?? "anonymous"
            for (idx, m) in midrolls.enumerated() {
                if servedMidrollIndices.contains(idx) { continue }
                if newTime >= m.time, newTime <= m.time + 0.5, AdsFrequencyCapService.shared.canShow(userId: uid, adUnit: "mid_roll") {
                    servedMidrollIndices.insert(idx)
                    prerollURL = m.url
                    showingAd = true
                    pendingContentResume = true
                    manager.pause()
                    AdsFrequencyCapService.shared.recordExposure(userId: uid, adUnit: "mid_roll", placement: "video_midroll", duration: 0, skippable: true, completed: false)
                    break
                }
            }
        }
    }

    // MARK: - Coordinator Delegates (legacy helpers now route to controlsCoordinator)
    
    func resetControlsHideTimer() {
        controlsCoordinator.resetHideTimer()
    }

    func pauseControlsAutoHideForTransientOverlay() {
        controlsCoordinator.pauseAutoHideForTransientOverlay()
    }

    func resumeControlsAutoHideIfNeeded() {
        controlsCoordinator.resumeAutoHideIfNeeded()
    }

    func updateHoveredChapterViaCoordinator(at locationX: CGFloat, trackWidth: CGFloat, chapters: [Video.Chapter]) {
        _ = controlsCoordinator.updateHoveredChapter(
            at: locationX,
            trackWidth: trackWidth,
            chapters: chapters,
            duration: activePlayerManager.duration
        )
    }

    func emitSteppedFeedbackIfNeeded(for normalizedValue: CGFloat, lastStep: inout Int) {
        let clamped = max(0, min(1, normalizedValue))
        let step = Int((clamped * 10).rounded())
        guard step != lastStep else { return }
        lastStep = step
        HapticManager.shared.impact(style: .light)
    }

    // MARK: - Gesture Actions
    func presentFullscreenPlayer() {
        guard let session = effectivePlaybackSession,
              let playableVideo = effectivePlayableVideo else { return }
        Task {
            await globalPlayer.adoptExternalPlayerManager(
                activePlayerManager,
                video: video,
                showFullscreen: true,
                session: session,
                playableVideo: playableVideo
            )
        }
        showingFullscreenOverlay = true
    }

    @MainActor
    func minimizeToMiniPlayer() async {
        // Never hand off gated / unauthorized content into the mini player.
        if membershipGateActive || userExplicitlyClosed {
            closeVideoDetail()
            return
        }
        guard let session = effectivePlaybackSession,
              let playableVideo = effectivePlayableVideo else {
            // Authorization never finished — nothing to hand off to mini player.
            closeVideoDetail()
            return
        }
        let manager = activePlayerManager
        let wasPlaying = manager.isPlaying

        await globalPlayer.adoptExternalPlayerManager(
            manager,
            video: video,
            showFullscreen: false,
            session: session,
            playableVideo: playableVideo
        )
        globalPlayer.showingFullscreen = false

        if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
            player.play()
            globalPlayer.isPlaying = true
        }
        dismiss()
    }

    /// Hard-exit the detail player (X / auth overlay). Does not attempt mini-player handoff.
    @MainActor
    func closeVideoDetail() {
        userExplicitlyClosed = true
        authorizationGeneration &+= 1
        authorizationTask?.cancel()
        authorizationTask = nil
        adLoadTimeoutTask?.cancel()
        adLoadTimeoutTask = nil
        playbackRenewalTask?.cancel()
        playbackRenewalTask = nil
        showingYouTubeAd = false
        currentVideoAd = nil
        playerManager.pause()
        globalPlayer.closePlayer()
        dismiss()
    }

    @MainActor
    func enforceMiniPlayerStateIfNeeded(wasPlaying: Bool, reason: String) {
        guard !globalPlayer.showingFullscreen else { return }
        resumeMiniPlayerPlaybackIfNeeded(wasPlaying: wasPlaying, reason: reason)
    }
    
    @MainActor
    func resumeMiniPlayerPlaybackIfNeeded(wasPlaying: Bool, reason: String) {
        guard wasPlaying else { return }
        _ = reason

        if let player = globalPlayer.player {
            if player.rate == 0 {
                player.play()
                globalPlayer.isPlaying = true
            }
        } else if let manager = globalPlayer.exposedPlayerManager, let player = manager.player {
            if player.rate == 0 {
                player.play()
            }
            globalPlayer.isPlaying = true
        }
    }

    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Endscreen & Queue
    func beginEndscreen() {
        upNextVideo = recommendedVideos.first(where: { $0.id != video.id })
        // Raw recommendation URLs are metadata only. The next detail view obtains
        // a fresh playback session before creating or prewarming an AVPlayerItem.
        guard upNextVideo != nil else { return }
        showUpNext = true
        upNextCountdown = 5
        // Cancellable structured-concurrency countdown (replaces a Timer closure
        // that captured struct @State — a fragile pattern in SwiftUI views).
        upNextCountdownTask?.cancel()
        upNextCountdownTask = Task { @MainActor in
            while upNextCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                upNextCountdown -= 1
            }
            if autoplayEnabled, let n = upNextVideo {
                playNext(n)
            }
        }

        // 🔥 REMOVED: Rating popup - too annoying for users
        // Users can rate the app manually from Settings if they want
    }

    func playNext(_ next: Video) {
        showUpNext = false
        upNextCountdownTask?.cancel(); upNextCountdownTask = nil
        trackRecommendationClick(next)
        videoToPresent = next
    }

    func handleChannelTap(_ channelName: String) {
        Task {
            let resolved = await UserLookupService.shared.resolveUser(usernameOrDisplayName: channelName, fallback: video.creator)
            await MainActor.run {
                selectedCreatorProfile = resolved ?? video.creator
                showingCreatorProfile = true
            }
        }
    }

    func handleHashtagTap(_ hashtag: String) {
        selectedHashtag = hashtag
    }

    func trackRecommendationImpression(_ next: Video) {
        Task {
            let index = recommendedVideos.firstIndex(of: next) ?? 0
            await recommendationService.trackImpression(
                videoId: next.id,
                sourceVideoId: video.id,
                position: index,
                userId: appState.currentUser?.id
            )
        }
    }

    func trackRecommendationClick(_ next: Video) {
        Task {
            let index = recommendedVideos.firstIndex(of: next) ?? 0
            await recommendationService.trackClick(
                videoId: next.id,
                sourceVideoId: video.id,
                position: index,
                userId: appState.currentUser?.id
            )
        }
    }

    func cancelEndscreen() {
        showUpNext = false
        upNextCountdownTask?.cancel(); upNextCountdownTask = nil
    }

    func shareURLWithTimestamp() -> String {
        let seconds = Int(activePlaybackTime.rounded())
        return "\(video.link)?t=\(seconds)"
    }
}
