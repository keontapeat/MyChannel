import Foundation
import MediaPlayer
import AVFoundation

/// Phase 76: Lock Screen Media Controls
/// Integrates MPRemoteCommandCenter and MPNowPlayingInfoCenter to control video playback from the lock screen.
@MainActor
final class RemoteCommandEngine {
    static let shared = RemoteCommandEngine()
    
    private weak var player: AVPlayer?
    private var timeObserver: Any?
    
    private init() {
        setupRemoteCommands()
    }
    
    func attach(to player: AVPlayer, title: String, artist: String, artworkURL: URL?) {
        self.player = player
        updateNowPlayingInfo(title: title, artist: artist, duration: player.currentItem?.duration.seconds ?? 0)
        
        // Update playback time continuously
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.updateNowPlayingPlaybackTime(time: time.seconds)
        }
        
        // Fetch artwork async if available
        if let url = artworkURL {
            Task.detached {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    await self.updateNowPlayingArtwork(image)
                }
            }
        }
    }
    
    func detach() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.player?.play()
            return .success
        }
        
        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.player?.pause()
            return .success
        }
        
        // Skip Forward 15s
        commandCenter.skipForwardCommand.preferredIntervals = [15.0]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let player = self?.player, let current = player.currentItem else { return .commandFailed }
            let newTime = min(current.currentTime().seconds + 15.0, current.duration.seconds)
            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
            return .success
        }
        
        // Skip Backward 15s
        commandCenter.skipBackwardCommand.preferredIntervals = [15.0]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let player = self?.player else { return .commandFailed }
            let newTime = max(player.currentTime().seconds - 15.0, 0)
            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
            return .success
        }
    }
    
    private func updateNowPlayingInfo(title: String, artist: String, duration: Double) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackTime(time: Double) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
              let player = player else { return }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingArtwork(_ image: UIImage) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
            return image
        }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
