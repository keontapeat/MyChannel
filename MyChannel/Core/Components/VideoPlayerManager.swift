//
//  VideoPlayerManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentProgress: Double = 0.0
    @Published var bufferedProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var selectedQuality: VideoQuality = .auto
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentVideo: Video?
    private var isCleanedUp = false
    private var lastSavedSecond: Int = -1
    private var midrollServed: Bool = false
    private var imageGenerator: AVAssetImageGenerator?
    private var hasTrackedView = false  // 🔥 FIX: Track view ONCE per video

    // MARK: - Lightweight LRU Cache for AVPlayerItem and Session Resume
    private static var itemCache: [String: AVPlayerItem] = [:]
    private static var itemOrder: [String] = []
    private static let maxCacheItems: Int = 10
    private static var sessionResume: [String: TimeInterval] = [:]

    @MainActor
    static func prewarm(urlString: String) {
        guard itemCache[urlString] == nil, let url = URL(string: urlString) else { return }
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1
        cache(item: item, for: urlString)
    }

    @MainActor
    private static func cache(item: AVPlayerItem, for key: String) {
        itemCache[key] = item
        itemOrder.removeAll(where: { $0 == key })
        itemOrder.insert(key, at: 0)
        if itemOrder.count > maxCacheItems, let last = itemOrder.last {
            itemCache[last] = nil
            itemOrder.removeLast()
        }
    }

    @MainActor
    static func cachedItem(for key: String) -> AVPlayerItem? { itemCache[key] }

    @MainActor
    static func rememberResume(videoId: String, time: TimeInterval) {
        sessionResume[videoId] = time
    }

    @MainActor
    static func resumeTime(videoId: String) -> TimeInterval? { sessionResume[videoId] }
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    deinit {
        print("🗑️ VideoPlayerManager deinit called")
        cleanupSync()
    }
    
    private nonisolated func cleanupSync() {
        print("🧹 Cleaning up VideoPlayerManager (sync)")
        
        // We can't access @MainActor properties from deinit safely
        // So we'll schedule cleanup if needed, but since we're in deinit,
        // the object is being deallocated anyway
        Task { @MainActor in
            print("🧹 Final MainActor cleanup attempted (may not execute)")
        }
    }
    
    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        
        print("🧹 Cleaning up VideoPlayerManager")
        
        // Safely remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Pause and clear player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player?.cancelPendingPrerolls()
        player = nil
        
        // Clear cancellables to break retain cycles
        cancellables.removeAll()
        
        // Reset state
        isPlaying = false
        isLoading = false
        currentProgress = 0.0
        bufferedProgress = 0.0
        currentTime = 0
        duration = 0
        currentVideo = nil
        hasError = false
        errorMessage = nil
    }
    
    // MARK: - Safe Setup
    func setupPlayer(with video: Video) {
        Task {
            await setupPlayerWithDRM(video: video)
        }
    }
    
    private func setupPlayerWithDRM(video: Video) async {
        await MainActor.run {
            // Clean up any existing player first
            cleanup()
            isCleanedUp = false // Reset cleanup flag
            hasTrackedView = false  // 🔥 FIX: Reset view tracking for new video
            
            currentVideo = video
            isLoading = true
            hasError = false
        }
        
        print("🎬 [VideoPlayerManager] Setting up player for: \(video.title)")
        print("🔗 [VideoPlayerManager] Video URL: \(video.videoURL)")
        print("📊 [VideoPlayerManager] Video ID: \(video.id)")
        print("👤 [VideoPlayerManager] Creator: \(video.creator.displayName)")
        print("📹 [VideoPlayerManager] Content Source: \(video.contentSource?.rawValue ?? "userUploaded")")
        
        // 🔥 FIX: Use simple AVPlayer for non-DRM content (uploaded videos)
        guard let url = URL(string: video.videoURL) else {
            let errorMsg = "Invalid video URL: \(video.videoURL)"
            print("❌ [VideoPlayerManager] \(errorMsg)")
            await MainActor.run { handleError(errorMsg) }
            return
        }
        
        // 🔥 FIX: Verify URL is accessible before creating player
        print("🔍 [VideoPlayerManager] Verifying video URL accessibility...")
        let urlString = url.absoluteString
        
        // Check if it's a Firebase Storage URL
        if urlString.contains("firebasestorage.googleapis.com") || urlString.contains("firebase") {
            print("✅ [VideoPlayerManager] Firebase Storage URL detected")
        } else if urlString.hasPrefix("file://") {
            print("✅ [VideoPlayerManager] Local file URL detected")
        } else if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            print("✅ [VideoPlayerManager] Remote HTTP/HTTPS URL detected")
        } else {
            print("⚠️ [VideoPlayerManager] Unknown URL format: \(urlString)")
        }
        
        // Check if this needs DRM (only for YouTube/external content)
        let needsDRM = video.contentSource == .youtube
        
        if needsDRM {
            // Get DRM asset configuration for protected content
            guard let drmAsset = await DRMService.shared.createDRMAsset(for: video) else {
                await MainActor.run { handleError("Failed to create DRM asset") }
                return
            }
            
            // Create player with DRM support
            let player = AVPlayer()
            await MainActor.run { self.player = player }
            
            let success = await DRMService.shared.configurePlayerForDRM(
                player: player,
                asset: drmAsset,
                userId: AppState.shared.currentUser?.id
            )
            
            await MainActor.run {
                if !success {
                    handleError("DRM configuration failed")
                    return
                }
                setupPlayerCommon(player: player)
            }
        } else {
            // 🔥 SIMPLE PLAYER: For uploaded videos, use simple AVPlayer
            print("✅ Using simple AVPlayer for uploaded video")
            let player = AVPlayer(url: url)
            await MainActor.run {
                self.player = player
                setupPlayerCommon(player: player)
            }
        }
    }
    
    private func setupPlayerCommon(player: AVPlayer) {
        // Configure player settings
        player.automaticallyWaitsToMinimizeStalling = true
        player.currentItem?.preferredForwardBufferDuration = 1
        player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        if let playerItem = player.currentItem {
            setupObservers(for: playerItem)
            if let asset = playerItem.asset as? AVURLAsset {
                imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator?.appliesPreferredTrackTransform = true
            }
        }
        
        // Configure audio session
        configureAudioSession()
        
        Task {
            if let playerItem = player.currentItem {
                await loadAssetProperties(for: playerItem.asset)
            }
        }
    }
    
    private func setupObservers(for playerItem: AVPlayerItem) {
        // Clear existing cancellables first
        cancellables.removeAll()
        
        // Set up time observer with weak self to prevent retain cycle
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isCleanedUp else { return }
            
            self.currentTime = CMTimeGetSeconds(time)
            
            if self.duration > 0 {
                self.currentProgress = self.currentTime / self.duration
            }
            let currentSecond = Int(self.currentTime)
            if currentSecond != self.lastSavedSecond, currentSecond % 2 == 0 {
                self.lastSavedSecond = currentSecond
                self.persistResumePosition()
                self.updateNowPlayingInfo()
                // Mid-roll rule: insert once after 90 seconds and at least 8 minutes content
                if !midrollServed, self.currentTime > 90, self.duration > 480 {
                    midrollServed = true
                    NotificationCenter.default.post(name: NSNotification.Name("RequestMidrollAd"), object: nil)
                }
            }
        }
        
        // Use weak self in all publishers to prevent retain cycles
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self, !self.isCleanedUp else { return }
                
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.duration = CMTimeGetSeconds(playerItem.duration)
                    print("✅ [VideoPlayerManager] Video ready to play: \(self.currentVideo?.title ?? "unknown")")
                case .failed:
                    let error = playerItem.error?.localizedDescription ?? "Unknown error"
                    print("❌ [VideoPlayerManager] Video failed to load: \(error)")
                    self.handleError("Failed to load video: \(error)")
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // 🔥 REMOVED: Duplicate view tracking - now handled in play() method
        
        playerItem.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeRanges in
                guard let self = self, !self.isCleanedUp,
                      let timeRange = timeRanges.first?.timeRangeValue else { return }
                
                let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                if self.duration > 0 {
                    self.bufferedProgress = bufferedTime / self.duration
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isCleanedUp else { return }
                self.isLoading = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
                    if type == .began {
                        self.pause()
                    } else if type == .ended, let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.play()
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isCleanedUp else { return }
                self.isPlaying = false
                self.seek(to: 0)
            }
            .store(in: &cancellables)
    }
    
    private func loadAssetProperties(for asset: AVAsset) async {
        guard !isCleanedUp else { return }
        
        do {
            let duration = try await asset.load(.duration)
            await MainActor.run { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.duration = CMTimeGetSeconds(duration)
                self.isLoading = false
                if let resume = self.loadResumePosition(), resume > 2, resume < self.duration - 2 {
                    let progress = resume / self.duration
                    self.seek(to: progress)
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.handleError("Failed to load video properties")
            }
        }
    }
    
    // MARK: - Safe Playback Controls
    func play() {
        guard let player = player, !isCleanedUp else { 
            print("⚠️ [VideoPlayerManager] Cannot play - player is nil or cleaned up")
            return 
        }
        
        print("▶️ [VideoPlayerManager] Playing video: \(currentVideo?.title ?? "unknown")")
        print("🔗 [VideoPlayerManager] Video URL: \(currentVideo?.videoURL ?? "no URL")")
        print("🆔 [VideoPlayerManager] Video ID: \(currentVideo?.id ?? "no ID")")
        
        player.play()
        isPlaying = true
        isLoading = false
        updateNowPlayingInfo()
        
        // 🔥 FIX: Track view ONLY ONCE when video STARTS playing (not on every play/pause)
        if !hasTrackedView, let video = currentVideo {
            hasTrackedView = true  // Mark as tracked to prevent double-counting
            let videoId = video.id
            print("👁️🔥 [VideoPlayerManager] TRACKING VIEW for video: \(videoId)")
            
            Task {
                let userId = AuthenticationManager.shared.currentUser?.id
                
                // Track with RealtimeViewTracker (handles Firestore increment)
                await RealtimeViewTracker.shared.startViewSession(videoId: videoId, userId: userId)
                print("✅ [VideoPlayerManager] View session started")
                
                // Also call FirestoreService for backwards compatibility
                await VideoFirestoreService.shared.incrementViewCount(videoId: videoId)
                print("✅ [VideoPlayerManager] View count incremented in Firestore")
                
                // Update UI with latest count
                let latestCount = await RealtimeViewTracker.shared.getViewCount(for: videoId)
                print("📊 [VideoPlayerManager] Latest view count: \(latestCount)")
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VideoViewCountUpdated"),
                        object: nil,
                        userInfo: ["videoId": videoId, "viewCount": latestCount]
                    )
                    print("📢 [VideoPlayerManager] View count notification posted: \(latestCount)")
                }
            }
        } else if hasTrackedView {
            print("⏯️ [VideoPlayerManager] View already tracked, skipping (play/pause event)")
        } else {
            print("⚠️ [VideoPlayerManager] No current video to track view")
        }
        
        Task { await AnalyticsService.shared.trackVideoPlay(videoId: currentVideo?.id ?? "unknown", position: currentTime) }
    }
    
    func pause() {
        guard let player = player, !isCleanedUp else { return }
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
        Task { await AnalyticsService.shared.trackVideoPause(videoId: currentVideo?.id ?? "unknown", position: currentTime) }
    }
    
    func togglePlayPause() {
        guard player != nil, !isCleanedUp else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to progress: Double) {
        guard let player = player, duration > 0, !isCleanedUp else { return }
        
        let previousTime = currentTime
        let targetTime = duration * progress
        let time = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(to: time) { [weak self] completed in
            guard let self = self, !self.isCleanedUp else { return }
            if completed {
                DispatchQueue.main.async {
                    self.currentTime = targetTime
                    self.currentProgress = progress
                    self.persistResumePosition()
                }
                Task { await AnalyticsService.shared.trackVideoSeek(videoId: self.currentVideo?.id ?? "unknown", from: previousTime, to: targetTime) }
            }
        }
    }
    
    func seekForward(_ seconds: TimeInterval) {
        guard !isCleanedUp else { return }
        let newTime = min(currentTime + seconds, duration)
        let progress = duration > 0 ? newTime / duration : 0
        seek(to: progress)
    }
    
    func seekBackward(_ seconds: TimeInterval) {
        guard !isCleanedUp else { return }
        let newTime = max(currentTime - seconds, 0)
        let progress = duration > 0 ? newTime / duration : 0
        seek(to: progress)
    }
    
    func setPlaybackRate(_ rate: Float) {
        guard !isCleanedUp else { return }
        player?.rate = rate
        updateNowPlayingInfo()
    }

    // MARK: - Shorts Startup Tuning
    func applyShortsStartupTuning() {
        guard !isCleanedUp, let item = player?.currentItem else { return }
        // Start immediately with a very small startup buffer
        player?.automaticallyWaitsToMinimizeStalling = false
        item.preferredForwardBufferDuration = 0.2
        // Cap initial bitrate to speed up first frame for portrait/shorts
        if selectedQuality == .auto {
            item.preferredPeakBitRate = 1_800_000 // ~1.8 Mbps
        }
        // Relax constraints after a few seconds to allow quality ramp-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, !self.isCleanedUp, let current = self.player?.currentItem else { return }
            self.player?.automaticallyWaitsToMinimizeStalling = true
            if self.selectedQuality == .auto {
                current.preferredPeakBitRate = 0 // back to adaptive
            }
        }
    }

    // General fast-start tuning for standard videos (featured/trending)
    func applyFastStartTuning(initialBitrate: Double = 4_000_000, initialBufferSeconds: Double = 0.5, relaxAfterSeconds: Double = 4.0) {
        guard !isCleanedUp, let item = player?.currentItem else { return }
        player?.automaticallyWaitsToMinimizeStalling = false
        item.preferredForwardBufferDuration = initialBufferSeconds
        if selectedQuality == .auto {
            item.preferredPeakBitRate = initialBitrate
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaxAfterSeconds) { [weak self] in
            guard let self = self, !self.isCleanedUp, let current = self.player?.currentItem else { return }
            self.player?.automaticallyWaitsToMinimizeStalling = true
            if self.selectedQuality == .auto {
                current.preferredPeakBitRate = 0
            }
        }
    }

    // MARK: - Quality Selection (HLS-aware)
    func setPreferredQuality(_ quality: VideoQuality) {
        selectedQuality = quality
        guard let item = player?.currentItem else { return }
        if quality == .auto {
            // 0 resets to automatic adaptive bitrate
            item.preferredPeakBitRate = 0
            #if os(iOS)
            item.preferredMaximumResolution = .zero
            #endif
        } else {
            item.preferredPeakBitRate = Double(quality.bitrate)
            #if os(iOS)
            item.preferredMaximumResolution = quality.resolution
            #endif
        }
    }
    
    // 🔥 YOUTUBE PARITY: Auto quality selection based on network conditions
    func autoSelectQuality() {
        let networkOptimizer = NetworkOptimizer.shared
        
        // Get current network quality
        let connectionQuality = networkOptimizer.connectionQuality
        
        // Auto-select quality based on network
        let recommendedQuality: VideoQuality
        switch connectionQuality {
        case .excellent:
            recommendedQuality = .quality1080p
        case .good:
            recommendedQuality = .quality720p
        case .poor:
            recommendedQuality = .quality360p
        }
        
        // Only auto-select if user hasn't manually selected a quality
        if selectedQuality == .auto {
            setPreferredQuality(recommendedQuality)
            print("📊 [VideoPlayer] Auto-selected quality: \(recommendedQuality.rawValue) based on network: \(connectionQuality)")
        }
    }

    // MARK: - Playback Stats
    struct PlaybackStats {
        let width: Int
        let height: Int
        let bitrateKbps: Int
        let droppedFrames: Int
        let fps: Double
        let currentTime: Double
        let duration: Double
    }

    func currentPlaybackStats() -> PlaybackStats? {
        guard let item = player?.currentItem else { return nil }
        let size = item.presentationSize
        let w = Int(max(0, size.width))
        let h = Int(max(0, size.height))
        let event = item.accessLog()?.events.last
        let bitrateKbps = Int(((event?.observedBitrate ?? 0) / 1000.0).rounded())
        let dropped = Int(event?.numberOfDroppedVideoFrames ?? 0)
        let fpsFloat: Float = item.asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 0
        let fps = Double(fpsFloat)
        return PlaybackStats(
            width: w,
            height: h,
            bitrateKbps: bitrateKbps,
            droppedFrames: dropped,
            fps: fps,
            currentTime: currentTime,
            duration: duration
        )
    }
    
    func setLooping(_ shouldLoop: Bool) {
        guard !isCleanedUp else { return }
        
        if shouldLoop {
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self, !self.isCleanedUp else { return }
                    self.player?.seek(to: .zero)
                    self.player?.play()
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Volume and Audio
    func setVolume(_ volume: Float) {
        guard !isCleanedUp else { return }
        player?.volume = volume
    }
    
    func mute() {
        guard !isCleanedUp else { return }
        player?.isMuted = true
    }
    
    func unmute() {
        guard !isCleanedUp else { return }
        player?.isMuted = false
    }
    
    // MARK: - Error Handling
    private func handleError(_ message: String) {
        guard !isCleanedUp else { return }
        hasError = true
        errorMessage = message
        isLoading = false
        isPlaying = false
    }
    
    // MARK: - Manual Cleanup
    func performCleanup() {
        cleanup()
    }
    
    // MARK: - Audio Session / Now Playing
    private func configureAudioSession() {
        guard !AppConfig.isPreview else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }

    private func updateNowPlayingInfo() {
        guard let currentVideo = currentVideo else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentVideo.title,
            MPMediaItemPropertyArtist: currentVideo.creator.displayName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
    }

    // MARK: - Resume Position Persistence
    private func persistResumePosition() {
        guard let currentVideo = currentVideo else { return }
        let key = "resume_\(currentVideo.id)"
        UserDefaults.standard.set(currentTime, forKey: key)
    }

    private func loadResumePosition() -> TimeInterval? {
        guard let currentVideo = currentVideo else { return nil }
        let key = "resume_\(currentVideo.id)"
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : nil
    }

    private func clearResumePosition() {
        guard let currentVideo = currentVideo else { return }
        UserDefaults.standard.removeObject(forKey: "resume_\(currentVideo.id)")
    }

    // MARK: - Subtitles / Audio Tracks
    func availableSubtitleOptions() -> [AVMediaSelectionOption] {
        guard let group = player?.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return [] }
        return group.options
    }

    func selectSubtitle(option: AVMediaSelectionOption?) {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if let option = option {
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    func availableAudioOptions() -> [AVMediaSelectionOption] {
        guard let group = player?.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return [] }
        return group.options
    }

    func selectAudio(option: AVMediaSelectionOption?) {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        if let option = option {
            item.select(option, in: group)
        }
    }

    // MARK: - Thumbnails
    func thumbnail(at time: TimeInterval) -> UIImage? {
        guard let generator = imageGenerator else { return nil }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        do {
            let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    // MARK: - Helper Methods
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    VStack {
        Text("Video Player Manager")
            .font(.largeTitle)
            .padding()
        
        Text("Handles video playback with advanced controls")
            .foregroundColor(.secondary)
    }
}