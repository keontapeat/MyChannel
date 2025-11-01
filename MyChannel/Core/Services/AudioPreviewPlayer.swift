import Foundation
import AVFoundation
import MediaPlayer
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private var nowPlayingCenter = MPNowPlayingInfoCenter.default()
    
    private init() {
        configureAudioSession()
        configureRemoteCommands()
    }
    
    func play(url: URL, trackId: String, title: String? = nil, artist: String? = nil, artworkURL: URL? = nil) {
        if currentTrackId == trackId, isPlaying {
            pause()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        currentTrackId = trackId
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
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func stop() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
        currentTrackId = nil
        currentTitle = nil
        currentArtist = nil
        currentArtworkURL = nil
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
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            if let duration = player.currentItem?.duration.seconds, duration > 0 {
                self.progress = min(1.0, max(0.0, time.seconds / duration))
                self.durationSeconds = duration
                self.updateElapsed(time: time.seconds, duration: duration)
            } else {
                self.progress = 0
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            guard let self else { return }
            if !self.queue.isEmpty {
                self.playNextFromQueue()
            } else {
                self.stop()
            }
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
        let r = MPRemoteCommandCenter.shared()
        r.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        r.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        r.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            if !self.queue.isEmpty { self.playNextFromQueue(); return .success }
            return .noSuchContent
        }
        r.previousTrackCommand.isEnabled = false
    }

    private func updateNowPlaying(title: String?, artist: String?, artworkURL: URL?) {
        var info: [String: Any] = [:]
        if let t = title { info[MPMediaItemPropertyTitle] = t }
        if let a = artist { info[MPMediaItemPropertyArtist] = a }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        info[MPMediaItemPropertyPlaybackDuration] = 30 // previews are ~30s
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let artworkURL, let data = try? Data(contentsOf: artworkURL), let img = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        nowPlayingCenter.nowPlayingInfo = info
    }

    private func updateElapsed(time: Double, duration: Double) {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }

    private func prefetchNext() {
        guard let next = queue.first else { return }
        var req = URLRequest(url: next.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: req) { _,_,_ in }.resume()
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
}


