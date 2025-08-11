//
//  VideoPlayerManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import Combine

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
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        setupObservers(for: playerItem)
        
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
    }
    
    func pause() {
        guard let player = player, !isCleanedUp else { return }
        player.pause()
        isPlaying = false
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
        
        let targetTime = duration * progress
        let time = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(to: time) { [weak self] completed in
            guard let self = self, !self.isCleanedUp else { return }
            if completed {
                DispatchQueue.main.async {
                    self.currentTime = targetTime
                    self.currentProgress = progress
                }
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
