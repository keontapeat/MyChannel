import SwiftUI
import AVKit
import Combine

extension VideoDetailView {
    // MARK: - Helper Methods

    func handleDurationChange(_ newDuration: Double) {
        guard newDuration > 0 else { return }
        if playerManager.selectedQuality == .auto {
            playerManager.autoSelectQuality()
        }
        let savedPosition = WatchProgressService.shared.resumePosition(videoId: video.id)
        guard savedPosition > 0 else { return }
        let fraction = savedPosition / newDuration
        if fraction > 0.02 && fraction < 0.95 {
            print("▶️ [YouTube] Resuming from \(Int(savedPosition))s / \(Int(newDuration))s")
            playerManager.seek(to: fraction)
        }
    }

    func handleCurrentTimeChange() {
        let newTime = playerManager.currentTime
        if playerManager.duration > 0 {
            let roundedTime = Int(newTime)
            if roundedTime % 5 == 0 && roundedTime > 0 {
                let uid = AppState.shared.currentUser?.id ?? "anonymous"
                let vid = video.id
                let dur = playerManager.duration
                Task { try? await WatchProgressService.shared.saveProgress(userId: uid, videoId: vid, position: newTime, duration: dur) }
            }
            watchProgress = newTime / playerManager.duration
            if !hasWatchedThreshold && watchProgress >= 0.25 {
                hasWatchedThreshold = true
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 1) }
            } else if watchProgress >= 0.5 {
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 2) }
            } else if watchProgress >= 0.75 {
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 3) }
            }
        }
        if speedCurvesService.autoSkipSilence {
            if let seg = speedCurvesService.silenceSegments.first(where: { newTime >= $0.startSec && newTime <= $0.endSec }) {
                let skipTo = seg.endSec / playerManager.duration
                playerManager.seek(to: min(1.0, skipTo))
                withAnimation { showSilenceSkipIndicator = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { showSilenceSkipIndicator = false }
                }
            }
        }
        if let chapters = video.chapters, !chapters.isEmpty {
            let sorted = chapters.sorted { $0.start < $1.start }
            if let current = sorted.last(where: { $0.start <= newTime }) {
                currentChapterTitle = current.title
            }
        }
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
        if !midrolls.isEmpty, !showingAd, playerManager.duration > 0 {
            let uid = AppState.shared.currentUser?.id ?? "anonymous"
            for (idx, m) in midrolls.enumerated() {
                if servedMidrollIndices.contains(idx) { continue }
                if newTime >= m.time, newTime <= m.time + 0.5, AdsFrequencyCapService.shared.canShow(userId: uid, adUnit: "mid_roll") {
                    servedMidrollIndices.insert(idx)
                    prerollURL = m.url
                    showingAd = true
                    pendingContentResume = true
                    playerManager.pause()
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
            duration: playerManager.duration
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
        // Hand off the existing manager to the global one and present a true fullscreen overlay
        Task {
            await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
        }
        showingFullscreenOverlay = true
    }

    @MainActor
    func minimizeToMiniPlayer() async {
        print("🔄 [VideoDetailView] Minimizing to native PiP")
        let wasPlaying = playerManager.isPlaying
        
        // Hand the player off to GlobalVideoPlayerManager so PiP controller has a reference
        await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        globalPlayer.showingFullscreen = false
        
        // Keep playback going and start native PiP
        if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
            player.play()
            globalPlayer.isPlaying = true
        }
        
        // Start native iOS PiP floating window, then dismiss
        PiPPlayerManager.shared.startPiP(
            onStarted: { [weak globalPlayer] in
                globalPlayer?.showingFullscreen = false
            },
            onFailed: nil
        )
        
        // Dismiss the VideoDetailView
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
        
        if let player = globalPlayer.player {
            if player.rate == 0 {
                print("▶️ [VideoDetailView] Resuming playback via global player (\(reason))")
                player.play()
                globalPlayer.isPlaying = true
            }
        } else if let manager = globalPlayer.exposedPlayerManager, let player = manager.player {
            print("✅ [VideoDetailView] Using exposed player manager to resume playback (\(reason))")
            if player.rate == 0 {
                player.play()
            }
            globalPlayer.isPlaying = true
        } else {
            print("🚨 [VideoDetailView] Unable to resume playback (\(reason)) - no player available")
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

    // MARK: - Chapters Helpers
    func nearestChapter(for time: TimeInterval, in chapters: [Video.Chapter]) -> Video.Chapter? {
        // Find the last chapter whose start time is <= current time
        // Keep logic simple to help the compiler
        let sorted = chapters.sorted { $0.start < $1.start }
        var candidate: Video.Chapter?
        for chapter in sorted {
            if chapter.start <= time {
                candidate = chapter
            } else {
                break
            }
        }
        return candidate
    }

    // MARK: - Endscreen & Queue
    func beginEndscreen() {
        upNextVideo = recommendedVideos.first(where: { $0.id != video.id })
        if let next = upNextVideo {
            // Prewarm Up Next video for instant start
            VideoPlayerManager.prewarm(urlString: next.videoURL)
        }
        guard upNextVideo != nil else { return }
        showUpNext = true
        upNextCountdown = 5
        upNextTimer?.invalidate()
        upNextTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if upNextCountdown > 0 {
                upNextCountdown -= 1
            } else {
                upNextTimer?.invalidate(); upNextTimer = nil
                if autoplayEnabled, let n = upNextVideo {
                    playNext(n)
                }
            }
        }

        // 🔥 REMOVED: Rating popup - too annoying for users
        // Users can rate the app manually from Settings if they want
    }

    func playNext(_ next: Video) {
        showUpNext = false
        upNextTimer?.invalidate(); upNextTimer = nil
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
        upNextTimer?.invalidate(); upNextTimer = nil
    }

    func shareURLWithTimestamp() -> String {
        let seconds = Int(playerManager.currentTime.rounded())
        return "\(video.link)?t=\(seconds)"
    }
}
