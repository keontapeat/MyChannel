//
//  GlobalPlayerKVOObservers.swift
//  MyChannel
//
//  AVPlayer KVO observers extracted from GlobalVideoPlayerManager.setupObservers().
//  Keeps play-state + ready-state wiring testable and isolated from PiP/queue logic.
//

import AVFoundation

@MainActor
final class GlobalPlayerKVOObservers {
    var isCleanedUp: () -> Bool = { false }
    var onPlayerReadyChanged: (Bool) -> Void = { _ in }
    var onPlayingChanged: (Bool) -> Void = { _ in }

    private var timeControlObserver: NSKeyValueObservation?
    private var playerStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?

    /// Test hook — count of live KVO tokens (must be 0 after `invalidate()`).
    var activeObserverCount: Int {
        [timeControlObserver, playerStatusObserver, playerItemStatusObserver]
            .compactMap { $0 }
            .count
    }

    func attach(to player: AVPlayer?) {
        invalidate()

        guard let player else {
            onPlayerReadyChanged(false)
            return
        }

        playerStatusObserver = player.observe(\.status, options: [.new, .initial]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self, !self.isCleanedUp() else { return }
                let isReady = player.status == .readyToPlay
                self.onPlayerReadyChanged(isReady)
                print("🎬 [GlobalPlayer] Player status: \(player.status.rawValue), ready: \(isReady)")
            }
        }

        if let playerItem = player.currentItem {
            playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                Task { @MainActor in
                    guard let self, !self.isCleanedUp() else { return }
                    let isReady = item.status == .readyToPlay && player.status == .readyToPlay
                    self.onPlayerReadyChanged(isReady)

                    if item.status == .failed {
                        print("❌ [GlobalPlayer] PlayerItem failed: \(item.error?.localizedDescription ?? "Unknown")")
                        self.onPlayerReadyChanged(false)
                    }

                    print("🎬 [GlobalPlayer] PlayerItem status: \(item.status.rawValue), ready: \(isReady)")
                }
            }
        } else {
            onPlayerReadyChanged(false)
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self, !self.isCleanedUp() else { return }
                let newIsPlaying = player.timeControlStatus == .playing
                self.onPlayingChanged(newIsPlaying)
                print("🎬 [GlobalPlayer] Play state synced via KVO: \(newIsPlaying ? "PLAYING" : "PAUSED")")
            }
        }
    }

    func invalidate() {
        timeControlObserver?.invalidate()
        timeControlObserver = nil
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
    }
}
