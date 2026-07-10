//
//  VideoPlayerViewModel.swift
//  MyChannel
//
//  Extracted from ModernVideoPlayerView — player state and AVPlayer lifecycle.
//

import SwiftUI
import AVKit
import Combine

// MARK: - Video Player ViewModel

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentProgress: Double = 0
    @Published var playbackRate: Float = 1.0
    @Published var subtitleOptions: [AVMediaSelectionOption] = []
    @Published var audioOptions: [AVMediaSelectionOption] = []
    @Published var selectedSubtitle: AVMediaSelectionOption? = nil
    @Published var selectedAudio: AVMediaSelectionOption? = nil
    private var subtitleGroup: AVMediaSelectionGroup?
    private var audioGroup: AVMediaSelectionGroup?
    private var lastResumePersist: TimeInterval = 0
    private var resumeKey: String = ""
    private var quartilesFired: Set<Int> = []

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentVideo: Video?

    init() {
        // Initialization
    }

    var currentTimeString: String {
        formatTime(currentTime)
    }

    var durationString: String {
        formatTime(duration)
    }

    func setupPlayer(with video: Video) {
        print("🎬 Setting up player for video: \(video.title)")
        print("🔗 Video URL: \(video.videoURL)")
        print("💰 Monetization: \(video.monetization?.isMonetized ?? false)")

        currentVideo = video
        guard let url = URL(string: video.videoURL) else {
            print("❌ Invalid video URL: \(video.videoURL)")
            return
        }
        resumeKey = video.id
        player = AVPlayer(url: url)
        addTimeObserver()
        setupNotifications()
        configureMediaSelection()
        if let t = UserDefaults.standard.object(forKey: "resume_\(resumeKey)") as? Double, t > 3 {
            player?.seek(to: CMTime(seconds: t, preferredTimescale: 1000))
        }

        player?.rate = playbackRate
    }

    func play() {
        player?.play()
        isPlaying = true
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
        guard let player = player else { return }
        let clamped = min(max(progress, 0), 1)
        let time = duration * clamped
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentProgress = clamped
        currentTime = time
    }

    func seekForward(_ seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 1000))
        player.seek(to: newTime)
    }

    func seekBackward(_ seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 1000))
        player.seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
    }

    private func addTimeObserver() {
        guard let player = player else { return }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 1000),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds

            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
                self.currentProgress = time.seconds / duration
            }

            if time.seconds - self.lastResumePersist >= 5 {
                self.lastResumePersist = time.seconds
                UserDefaults.standard.set(time.seconds, forKey: "resume_\(self.resumeKey)")

                if let video = self.currentVideo, self.duration > 0 {
                    let progress = time.seconds / self.duration
                    AppState.shared.updateHistoryProgress(contentId: video.id, progress: progress, position: time.seconds)
                }
            }

            if self.duration > 0 {
                let pct = time.seconds / self.duration
                if pct >= 0.25 && !self.quartilesFired.contains(25) {
                    self.quartilesFired.insert(25)
                    Task { await AnalyticsService.shared.trackVideoQuartile(videoId: self.resumeKey, quartile: 25) }
                }
                if pct >= 0.50 && !self.quartilesFired.contains(50) {
                    self.quartilesFired.insert(50)
                    Task { await AnalyticsService.shared.trackVideoQuartile(videoId: self.resumeKey, quartile: 50) }
                }
                if pct >= 0.75 && !self.quartilesFired.contains(75) {
                    self.quartilesFired.insert(75)
                    Task { await AnalyticsService.shared.trackVideoQuartile(videoId: self.resumeKey, quartile: 75) }
                }
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let endedItem = notification.object as? AVPlayerItem,
                   endedItem !== self.player?.currentItem { return }
                self.isPlaying = false
            }
            .store(in: &cancellables)
    }

    // MARK: Media Selection (Captions/Dubs)

    private func configureMediaSelection() {
        guard let item = player?.currentItem else { return }
        item.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let asset = self.player?.currentItem?.asset else { return }
                if let legible = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                    self.subtitleGroup = legible
                    self.subtitleOptions = legible.options
                }
                if let audible = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                    self.audioGroup = audible
                    self.audioOptions = audible.options
                }
            }
            .store(in: &cancellables)
    }

    func selectSubtitle(option: AVMediaSelectionOption?) {
        guard let group = subtitleGroup, let item = player?.currentItem else { return }
        selectedSubtitle = option
        if let option = option {
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    func selectAudio(option: AVMediaSelectionOption?) {
        guard let group = audioGroup, let item = player?.currentItem else { return }
        selectedAudio = option
        if let option = option {
            item.select(option, in: group)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player = nil
        cancellables.removeAll()
        quartilesFired.removeAll()
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }

    func togglePiP() {
        if let video = currentVideo {
            GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: player)
        }
        GlobalVideoPlayerManager.shared.startPiP()
    }
}
