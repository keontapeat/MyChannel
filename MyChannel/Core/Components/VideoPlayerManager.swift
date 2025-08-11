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
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentVideo: Video?
    private var isCleanedUp = false
    private var lastSavedSecond: Int = -1
    private var imageGenerator: AVAssetImageGenerator?
    
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
        // Clean up any existing player first
        cleanup()
        isCleanedUp = false // Reset cleanup flag
        
        currentVideo = video
        isLoading = true
        hasError = false
        
        guard let url = URL(string: video.videoURL) else {
            handleError("Invalid video URL")
            return
        }
        
        // Prefer HLS if provided, otherwise use direct MP4 URL
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        // Prime asset duration upfront to reduce first-load blank delay
        Task.detached { [weak self] in
            do {
                _ = try await asset.load(.duration)
            } catch { /* ignore */ }
        }
        let playerItem = AVPlayerItem(asset: asset)
        // Create player early to allow immediate rendering
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.appliesPreferredTrackTransform = true
        
        setupObservers(for: playerItem)
        configureAudioSession()
        
        Task {
            await loadAssetProperties(for: playerItem.asset)
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
                case .failed:
                    self.handleError("Failed to load video")
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
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
        guard let player = player, !isCleanedUp else { return }
        
        player.play()
        isPlaying = true
        isLoading = false
        updateNowPlayingInfo()
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
