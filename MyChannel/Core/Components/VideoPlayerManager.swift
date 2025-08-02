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
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    deinit {
        Task { @MainActor in
            await cleanup()
        }
    }
    
    private func cleanup() async {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    func setupPlayer(with video: Video) {
        currentVideo = video
        isLoading = true
        hasError = false
        
        guard let url = URL(string: video.videoURL) else {
            handleError("Invalid video URL")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupObservers(for: playerItem)
        
        Task {
            await loadAssetProperties(for: playerItem.asset)
        }
    }
    
    private func setupObservers(for playerItem: AVPlayerItem) {
        cancellables.removeAll()
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            self.currentTime = CMTimeGetSeconds(time)
            
            if self.duration > 0 {
                self.currentProgress = self.currentTime / self.duration
            }
        }
        
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.duration = CMTimeGetSeconds(playerItem.duration)
                case .failed:
                    self?.handleError("Failed to load video")
                case .unknown:
                    self?.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        playerItem.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeRanges in
                guard let self = self,
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
                self?.isLoading = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.seek(to: 0)
            }
            .store(in: &cancellables)
    }
    
    private func loadAssetProperties(for asset: AVAsset) async {
        do {
            let duration = try await asset.load(.duration)
            await MainActor.run {
                self.duration = CMTimeGetSeconds(duration)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.handleError("Failed to load video properties")
            }
        }
    }
    
    // MARK: - Playback Controls
    func play() {
        player?.play()
        isPlaying = true
        isLoading = false
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to progress: Double) {
        let targetTime = duration * progress
        let time = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time) { [weak self] _ in
            self?.currentTime = targetTime
            self?.currentProgress = progress
        }
    }
    
    func seekForward(_ seconds: TimeInterval) {
        let newTime = min(currentTime + seconds, duration)
        let progress = duration > 0 ? newTime / duration : 0
        seek(to: progress)
    }
    
    func seekBackward(_ seconds: TimeInterval) {
        let newTime = max(currentTime - seconds, 0)
        let progress = duration > 0 ? newTime / duration : 0
        seek(to: progress)
    }
    
    func setPlaybackRate(_ rate: Float) {
        player?.rate = rate
    }
    
    func setLooping(_ shouldLoop: Bool) {
        if shouldLoop {
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.player?.seek(to: .zero)
                    self?.player?.play()
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Volume and Audio
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    func mute() {
        player?.isMuted = true
    }
    
    func unmute() {
        player?.isMuted = false
    }
    
    // MARK: - Error Handling
    private func handleError(_ message: String) {
        hasError = true
        errorMessage = message
        isLoading = false
        isPlaying = false
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