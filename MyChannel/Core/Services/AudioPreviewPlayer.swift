import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

struct PreviewQueueItem {
    let trackId: String
    let url: URL
    let title: String?
    let artist: String?
    let artworkURL: URL?
}

@MainActor
final class AudioPreviewPlayer: ObservableObject {
    static let shared = AudioPreviewPlayer()
    
    @Published var currentTrackId: String? = nil
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0.0
    @Published var queue: [PreviewQueueItem] = []
    @Published var currentTitle: String? = nil
    @Published var currentArtist: String? = nil
    @Published var currentArtworkURL: URL? = nil
    @Published var durationSeconds: Double = 30
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?
    private var playbackSessionId: UUID?
    private var reportsQualifiedPlay = false
    private var hasSubmittedQualifiedPlay = false
    private var listenedSeconds: Double = 0
    private var lastObservedTime: Double?
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []
    private var nowPlayingCenter = MPNowPlayingInfoCenter.default()
    
    private init() {
        configureAudioSession()
        configureRemoteCommands()
    }
    
    func play(
        url: URL,
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        artworkURL: URL? = nil,
        reportsQualifiedPlay: Bool = false
    ) {
        if currentTrackId == trackId, isPlaying {
            pause()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        currentTrackId = trackId
        playbackSessionId = UUID()
        self.reportsQualifiedPlay = reportsQualifiedPlay
        hasSubmittedQualifiedPlay = false
        listenedSeconds = 0
        lastObservedTime = 0
        addObservers()
        player?.play()
        isPlaying = true
        currentTitle = title
        currentArtist = artist
        currentArtworkURL = artworkURL
        updateNowPlaying(title: title, artist: artist, artworkURL: artworkURL)
        prefetchNext()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackRate()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackRate()
    }
    
    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        artworkTask?.cancel()
        artworkTask = nil
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
        currentTrackId = nil
        currentTitle = nil
        currentArtist = nil
        currentArtworkURL = nil
        playbackSessionId = nil
        reportsQualifiedPlay = false
        hasSubmittedQualifiedPlay = false
        listenedSeconds = 0
        lastObservedTime = nil
        nowPlayingCenter.nowPlayingInfo = nil
    }
    
    func clearQueue() {
        queue.removeAll()
    }
    
    func queueAndPlay(_ items: [PreviewQueueItem]) {
        queue = items
        playNextFromQueue()
    }
    
    func enqueue(_ items: [PreviewQueueItem]) {
        queue.append(contentsOf: items)
    }
    
    private func playNextFromQueue() {
        guard !queue.isEmpty else { stop(); return }
        let next = queue.removeFirst()
        play(url: next.url, trackId: next.trackId, title: next.title, artist: next.artist, artworkURL: next.artworkURL)
    }
    
    private func addObservers() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let currentTime = time.seconds
            self.recordPlayback(currentTime: currentTime)
            if let duration = player.currentItem?.duration.seconds, duration > 0 {
                self.progress = min(1.0, max(0.0, currentTime / duration))
                self.durationSeconds = duration
                self.updateElapsed(time: currentTime, duration: duration)
            } else {
                self.progress = 0
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let finalTime = player.currentItem?.duration.seconds ?? self.durationSeconds
            self.recordPlayback(currentTime: finalTime, isFinalSample: true)
            if !self.queue.isEmpty {
                self.playNextFromQueue()
            } else {
                self.stop()
            }
        }
    }

    private func recordPlayback(currentTime: Double, isFinalSample: Bool = false) {
        defer { lastObservedTime = currentTime }
        guard reportsQualifiedPlay,
              isPlaying,
              isFinalSample || (player?.rate ?? 0) > 0,
              let previousTime = lastObservedTime else { return }
        let forwardDelta = currentTime - previousTime
        guard forwardDelta > 0, forwardDelta <= 1.5 else { return }
        listenedSeconds += forwardDelta
        guard listenedSeconds >= 30,
              !hasSubmittedQualifiedPlay,
              let trackId = currentTrackId,
              let sessionId = playbackSessionId else { return }
        hasSubmittedQualifiedPlay = true
        let qualifiedSeconds = max(30, Int(listenedSeconds.rounded(.down)))
        Task {
            try? await MusicAPIClient.shared.submitQualifiedPlay(
                trackId: trackId,
                sessionId: sessionId,
                qualifiedSeconds: qualifiedSeconds
            )
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Intentionally ignore; previews still work without session
        }
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        let playTarget = commands.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        let pauseTarget = commands.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        let nextTarget = commands.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            if !self.queue.isEmpty {
                self.playNextFromQueue()
                return .success
            }
            return .noSuchContent
        }
        remoteCommandTargets = [
            (commands.playCommand, playTarget),
            (commands.pauseCommand, pauseTarget),
            (commands.nextTrackCommand, nextTarget)
        ]
        commands.previousTrackCommand.isEnabled = false
    }

    private func updateNowPlaying(title: String?, artist: String?, artworkURL: URL?) {
        var info: [String: Any] = [:]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if let artist { info[MPMediaItemPropertyArtist] = artist }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        info[MPMediaItemPropertyPlaybackDuration] = 30
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info

        artworkTask?.cancel()
        guard let artworkURL else { return }
        artworkTask = Task { [weak self] in
            let image = await Task.detached(priority: .utility) { () -> UIImage? in
                do {
                    let (data, response) = try await URLSession.shared.data(from: artworkURL)
                    guard data.count <= 10 * 1024 * 1024,
                          (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                    return UIImage(data: data)
                } catch {
                    return nil
                }
            }.value
            guard !Task.isCancelled,
                  let image,
                  let self,
                  self.currentArtworkURL == artworkURL else { return }
            var updatedInfo = self.nowPlayingCenter.nowPlayingInfo ?? [:]
            updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
            self.nowPlayingCenter.nowPlayingInfo = updatedInfo
        }
    }

    private func updateElapsed(time: Double, duration: Double) {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackRate() {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }

    private func prefetchNext() {
        guard let next = queue.first else { return }
        var req = URLRequest(url: next.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        URLSession.configured.dataTask(with: req) { _,_,_ in }.resume()
    }
    
    // MARK: - Transport
    func seek(toFraction fraction: Double) {
        guard let player, let duration = player.currentItem?.duration.seconds, duration > 0 else { return }
        let clamped = max(0.0, min(1.0, fraction))
        let seconds = duration * clamped
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
        if isPlaying { player.play() }
    }
    
    func next() {
        if !queue.isEmpty { playNextFromQueue() }
    }

    deinit {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        artworkTask?.cancel()
        for target in remoteCommandTargets {
            target.command.removeTarget(target.token)
        }
    }
}


