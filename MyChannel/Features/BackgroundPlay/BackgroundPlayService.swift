//
//  BackgroundPlayService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI

// MARK: - Background Play Service (YouTube Premium Parity)
@MainActor
class BackgroundPlayService: ObservableObject {
    static let shared = BackgroundPlayService()
    
    @Published var isBackgroundPlayEnabled = false
    @Published var currentlyPlayingInBackground: Video?
    @Published var backgroundPlaybackState: BackgroundPlaybackState = .stopped
    @Published var backgroundPlayProgress: Double = 0.0
    
    // Audio session management
    private var audioSession: AVAudioSession
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Remote control
    private var remoteCommandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    
    enum BackgroundPlaybackState {
        case stopped, playing, paused, buffering
    }
    
    var isActive: Bool {
        backgroundPlaybackState == .playing || backgroundPlaybackState == .paused || player != nil
    }
    
    var currentPlaybackTime: TimeInterval {
        player?.currentTime().seconds ?? 0
    }
    
    private init() {
        audioSession = AVAudioSession.sharedInstance()
        remoteCommandCenter = MPRemoteCommandCenter.shared()
        nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
        setupBackgroundPlayback()
        setupRemoteControls()
        setupNotifications()
    }
    
    // MARK: - Background Playback Control
    
    /// Start background audio playback for video
    func startBackgroundPlay(for video: Video, at time: TimeInterval = 0) async throws {
        // Premium gate: background play requires MyChannel Plus+
        // 🔥 FIX 2.1(b): Skip premium check when IAPs not submitted
        if AppConfig.Features.enableSubscriptions {
            guard StoreKitService.shared.isPremium else {
                throw BackgroundPlayError.premiumRequired
            }
        }
        
        guard isBackgroundPlayEnabled else {
            throw BackgroundPlayError.backgroundPlayDisabled
        }
        
        // Configure audio session for background playback
        try await configureAudioSession()
        
        // Get audio-only stream URL
        guard let audioURL = await getAudioStreamURL(for: video) else {
            throw BackgroundPlayError.audioStreamNotAvailable
        }
        
        // Create and configure player
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Seek to specified time if needed
        if time > 0 {
            await player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        }
        
        // Setup playback monitoring
        setupPlaybackObserver()
        
        // Update now playing info
        updateNowPlayingInfo(for: video)
        
        // Start playback
        player?.play()
        
        // Update state
        currentlyPlayingInBackground = video
        backgroundPlaybackState = .playing
        
        // Track analytics
        await trackBackgroundPlayStart(video: video)
    }
    
    /// Pause background playback
    func pauseBackgroundPlay() {
        player?.pause()
        backgroundPlaybackState = .paused
        updateNowPlayingPlaybackState()
    }
    
    /// Resume background playback
    func resumeBackgroundPlay() {
        player?.play()
        backgroundPlaybackState = .playing
        updateNowPlayingPlaybackState()
    }
    
    /// Stop background playback
    func stopBackgroundPlay() {
        if let player = player {
            player.pause()
            if let timeObserver = timeObserver {
                player.removeTimeObserver(timeObserver)
            }
        }
        
        timeObserver = nil
        player = nil
        
        backgroundPlaybackState = .stopped
        currentlyPlayingInBackground = nil
        backgroundPlayProgress = 0.0
        
        // Clear now playing info
        nowPlayingInfoCenter.nowPlayingInfo = nil
        
        // Reset audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    /// Seek to specific time in background playback
    func seekBackgroundPlay(to time: TimeInterval) async {
        await player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updateNowPlayingProgress()
    }
    
    // MARK: - Settings Management
    
    /// Enable/disable background play feature
    func setBackgroundPlayEnabled(_ enabled: Bool) {
        isBackgroundPlayEnabled = enabled
        
        if !enabled && backgroundPlaybackState != .stopped {
            stopBackgroundPlay()
        }
        
        // Save to user defaults
        UserDefaults.standard.set(enabled, forKey: "backgroundPlayEnabled")
    }
    
    /// Check if background play is available (Premium feature)
    func isBackgroundPlayAvailable() -> Bool {
        // Check if user has premium subscription
        return PremiumService.shared.hasPremium
    }
    
    // MARK: - Private Setup Methods
    
    private func setupBackgroundPlayback() {
        // Default to disabled - requires explicit user opt-in (premium feature only)
        if UserDefaults.standard.object(forKey: "backgroundPlayEnabled") == nil {
            UserDefaults.standard.set(false, forKey: "backgroundPlayEnabled")
        }
        isBackgroundPlayEnabled = UserDefaults.standard.bool(forKey: "backgroundPlayEnabled")
        
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupRemoteControls() {
        // Play/Pause
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            self?.resumeBackgroundPlay()
            return .success
        }
        
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pauseBackgroundPlay()
            return .success
        }
        
        // Skip forward/backward
        remoteCommandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task {
                await self?.skipForward(by: skipEvent.interval)
            }
            return .success
        }
        
        remoteCommandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task {
                await self?.skipBackward(by: skipEvent.interval)
            }
            return .success
        }
        
        // Seek
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task {
                await self?.seekBackgroundPlay(to: positionEvent.positionTime)
            }
            return .success
        }
        
        // Configure skip intervals
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        
        // Enable commands
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
    }
    
    private func setupNotifications() {
        // Monitor audio interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Monitor route changes (headphones disconnect, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func configureAudioSession() async throws {
        try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
        try audioSession.setActive(true)
    }
    
    private func setupPlaybackObserver() {
        guard let player = player else { return }
        
        // Remove existing observer
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        
        // Add new time observer
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            // Already on main queue — @MainActor annotation on Task is redundant
            Task { await self?.updatePlaybackProgress(time) }
        }
        
        // Monitor player status
        player.publisher(for: \.status)
            .sink { [weak self] status in
                Task { await self?.handlePlayerStatusChange(status) }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handlers
    
    private func handleAppDidEnterBackground() async {
        // Continue playback in background if enabled
        if isBackgroundPlayEnabled && backgroundPlaybackState == .playing {
            // Playback should continue automatically with proper audio session configuration
        }
    }
    
    private func handleAppWillEnterForeground() async {
        // Sync state when returning to foreground
        updateNowPlayingProgress()
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pauseBackgroundPlay()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resumeBackgroundPlay()
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged, pause playback
            pauseBackgroundPlay()
        default:
            break
        }
    }
    
    private func handlePlayerStatusChange(_ status: AVPlayer.Status) async {
        switch status {
        case .readyToPlay:
            if backgroundPlaybackState == .buffering {
                backgroundPlaybackState = .playing
            }
        case .failed:
            backgroundPlaybackState = .stopped
            // Handle error
        case .unknown:
            backgroundPlaybackState = .buffering
        @unknown default:
            break
        }
    }
    
    private func updatePlaybackProgress(_ time: CMTime) async {
        guard let duration = player?.currentItem?.duration,
              duration.isValid && !duration.isIndefinite else {
            return
        }
        
        let currentTime = time.seconds
        let totalDuration = duration.seconds
        
        backgroundPlayProgress = currentTime / totalDuration
        updateNowPlayingProgress()
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo(for video: Video) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: video.title,
            MPMediaItemPropertyArtist: video.creator.username,
            MPMediaItemPropertyPlaybackDuration: video.duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        
        // Add artwork if available
        Task {
            if let artwork = await loadArtwork(from: video.thumbnailURL) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
            }
        }
        
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackState() {
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else { return }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = backgroundPlaybackState == .playing ? 1.0 : 0.0
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingProgress() {
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo,
              let player = player,
              let currentItem = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Utility Methods
    
    private func getAudioStreamURL(for video: Video) async -> URL? {
        // Get audio-only stream URL to save bandwidth
        // This would integrate with your video streaming service
        return URL(string: video.videoURL) // Fallback to video URL
    }
    
    private func loadArtwork(from urlString: String) async -> MPMediaItemArtwork? {
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
    
    private func skipForward(by interval: TimeInterval) async {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: interval, preferredTimescale: 600))
        await player.seek(to: newTime)
    }
    
    private func skipBackward(by interval: TimeInterval) async {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: interval, preferredTimescale: 600))
        await player.seek(to: newTime)
    }
    
    private func trackBackgroundPlayStart(video: Video) async {
        // Track analytics for background play usage
        try? await AdvancedAnalyticsService.shared.trackEvent(
            "background_play_started",
            parameters: [
                "video_id": video.id,
                "video_duration": video.duration
            ]
        )
    }
}

// MARK: - Extensions

extension AdvancedAnalyticsService {
    func trackEvent(_ eventName: String, parameters: [String: Any]) async throws {
        // Implementation for tracking custom events
    }
}

// MARK: - Errors

enum BackgroundPlayError: Error {
    case backgroundPlayDisabled
    case audioStreamNotAvailable
    case premiumRequired
    case audioSessionError
}

// MARK: - Premium Service Extension

extension PremiumService {
    var hasPremium: Bool {
        // Single source of truth: StoreKit entitlements
        return StoreKitService.shared.isPremium
    }
}
