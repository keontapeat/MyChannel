//
//  NowPlayingService.swift
//  MyChannel
//
//  Phase 22: Now Playing info center + remote command center for PiP, lock screen, Dynamic Island.
//

import Foundation
import MediaPlayer
import AVFoundation

@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()
    private init() { setupRemoteCommands() }

    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onSeek: ((TimeInterval) -> Void)?
    private var onSkipForward: (() -> Void)?
    private var onSkipBackward: (() -> Void)?

    // MARK: - Update Now Playing

    func update(
        title: String,
        creator: String,
        thumbnailURL: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: creator,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        // Async load artwork
        if let urlStr = thumbnailURL, let url = URL(string: urlStr) {
            Task.detached {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                    await MainActor.run {
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Register callbacks

    func registerCallbacks(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void,
        onSkipForward: @escaping () -> Void = {},
        onSkipBackward: @escaping () -> Void = {}
    ) {
        self.onPlay = onPlay
        self.onPause = onPause
        self.onSeek = onSeek
        self.onSkipForward = onSkipForward
        self.onSkipBackward = onSkipBackward
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onSeek?(posEvent.positionTime)
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.onSkipForward?()
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.onSkipBackward?()
            return .success
        }
    }

    // MARK: - Audio Session (for background playback)

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ [NowPlaying] Audio session error: \(error)")
        }
    }
}
