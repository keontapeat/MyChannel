//
//  GlobalPlayerPiPCoordinator.swift
//  MyChannel
//
//  Native Picture-in-Picture lifecycle extracted from GlobalVideoPlayerManager.
//  Uses closure bindings (same pattern as GlobalPlayerViewTracking).
//

import AVFoundation
import UIKit

@MainActor
final class GlobalPlayerPiPCoordinator {
    var hasCurrentVideo: () -> Bool = { false }
    var isPlaying: () -> Bool = { false }
    var isCleanedUp: () -> Bool = { false }
    var showingFullscreen: () -> Bool = { false }
    var setShowingFullscreen: (Bool) -> Void = { _ in }
    var player: () -> AVPlayer? = { nil }
    var onExpandFromPiPTap: () -> Void = {}

    let allowSystemPictureInPicture = true

    private let pipController = NativePiPController.shared
    private var wasPlayingBeforeBackground = false
    private var expandFromPiPObserver: NSObjectProtocol?

    var isActive: Bool { pipController.isActive }

    func startObserving() {
        expandFromPiPObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExpandFromNativePiP"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔄 [GlobalPlayer] Expand from native PiP - user tapped PiP window")
                self?.onExpandFromPiPTap()
            }
        }
    }

    func teardownObserver() {
        if let expandFromPiPObserver {
            NotificationCenter.default.removeObserver(expandFromPiPObserver)
            self.expandFromPiPObserver = nil
        }
    }

    func handleDidEnterBackground() {
        print("🎧 [GlobalPlayer] App entered background")
        guard hasCurrentVideo() else { return }

        wasPlayingBeforeBackground = isPlaying()

        if wasPlayingBeforeBackground && allowSystemPictureInPicture {
            print("▶️ [GlobalPlayer] Background with active playback — PiP will auto-start")

            if let player = player() {
                pipController.setup(with: player)
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard let self, !self.isCleanedUp() else { return }
                if !self.pipController.isActive {
                    self.pipController.startPiP()
                }
            }
        }
    }

    func handleWillEnterForeground() {
        print("🎧 [GlobalPlayer] App entering foreground")
        guard hasCurrentVideo() else { return }

        // Foreground: restore custom mini-player (not fullscreen) once system PiP stops.
        if pipController.isActive {
            pipController.stopPiP()
        }
        if showingFullscreen() {
            setShowingFullscreen(false)
        }

        if wasPlayingBeforeBackground {
            if let player = player(), player.timeControlStatus != .playing {
                player.play()
            }
        }

        wasPlayingBeforeBackground = false
    }

    func setup(with player: AVPlayer?) {
        guard let player else { return }
        pipController.setup(with: player)
    }

    func stopAll() {
        if pipController.isActive { pipController.stopPiP() }
        if PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true {
            PiPPlayerManager.shared.stopPiP()
        }
    }

    func startPiP() {
        guard allowSystemPictureInPicture else {
            print("⚠️ [GlobalPlayer] PiP disabled — allowSystemPictureInPicture is false")
            return
        }
        guard hasCurrentVideo(), !isCleanedUp() else {
            print("⚠️ [GlobalPlayer] Cannot start PiP - no video or cleaned up")
            return
        }

        if pipController.isActive {
            print("⚠️ [GlobalPlayer] PiP already active - skipping")
            return
        }

        print("🔽 [GlobalPlayer] startPiP() called")
        print("   Current state: fullscreen=\(showingFullscreen())")

        if showingFullscreen() {
            print("🎬 [GlobalPlayer] Starting PiP from fullscreen player...")
            PiPPlayerManager.shared.startPiP()
        } else {
            print("🎬 [GlobalPlayer] Starting background PiP...")
            pipController.startPiP()
        }

        setShowingFullscreen(false)

        HapticManager.shared.impact(style: .medium)
        print("✅ [GlobalPlayer] Native PiP starting...")
    }

    func scheduleAutoStartIfNotFullscreen() {
        guard allowSystemPictureInPicture else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, self.allowSystemPictureInPicture else { return }
            self.pipController.startPiP()
        }
    }

    /// Stops active PiP windows, then runs `onExpanded` after a brief settle delay.
    func prepareExpansion(onExpanded: @escaping () async -> Void) {
        let anyPiPActive = pipController.isActive
            || (PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true)

        if anyPiPActive {
            print("⏹️ [GlobalPlayer] Stopping ALL PiP before expanding")
            stopAll()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                await onExpanded()
            }
        } else {
            Task { @MainActor in
                await onExpanded()
            }
        }
    }
}
