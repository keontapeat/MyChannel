import SwiftUI
import AVFoundation

// MARK: - Muted Looping Inline Video Player (with pause/resume logic)
struct MutedLoopVideoPlayer: UIViewRepresentable {
    let videoURL: String
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        // URL changed → reconfigure
        if uiView.currentURL != videoURL {
            configure(view: uiView, coordinator: context.coordinator)
        }

        // Pause/resume based on active state
        if isActive {
            if uiView.player?.rate == 0 {
                uiView.player?.play()
            }
        } else {
            uiView.player?.pause()
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        // Clean up when view is removed
        uiView.player?.pause()
        uiView.player = nil
        uiView.playerLayer?.removeFromSuperlayer()
        coordinator.loopObserver = nil
        coordinator.bgObserver = nil
        coordinator.fgObserver = nil
        coordinator.pauseObserver = nil
        coordinator.resumeObserver = nil
    }

    private func configure(view: PlayerContainerView, coordinator: Coordinator) {
        // Tear down previous player
        view.player?.pause()
        view.playerLayer?.removeFromSuperlayer()
        view.player = nil
        view.playerLayer = nil
        view.currentURL = videoURL
        coordinator.loopObserver = nil
        coordinator.bgObserver = nil
        coordinator.fgObserver = nil
        coordinator.pauseObserver = nil
        coordinator.resumeObserver = nil

        guard !videoURL.isEmpty else { return }
        
        let url = videoURL
        let active = isActive

        Task { @MainActor in
            // Reuse cached asset — no re-download on repeat appearances
            let asset = await LoopAssetCache.shared.asset(for: url)
            
            // Check if view URL changed while we were waiting
            guard view.currentURL == url else { return }
            
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 8.0

            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.automaticallyWaitsToMinimizeStalling = false

            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            view.player = player
            view.playerLayer = layer

            // Loop at end
            coordinator.loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }

            // Pause on app background
            coordinator.bgObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak player] _ in
                player?.pause()
            }

            // Resume on app foreground (only if this card is active)
            coordinator.fgObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak player] _ in
                // Will be resumed by updateUIView when isActive == true
                _ = player
            }

            // Pause/resume for fullscreen covers
            coordinator.pauseObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LivePreviewsShouldPause"),
                object: nil,
                queue: .main
            ) { [weak player] _ in
                player?.pause()
            }
            coordinator.resumeObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LivePreviewsShouldResume"),
                object: nil,
                queue: .main
            ) { [weak player] _ in
                // Will be resumed by updateUIView when isActive == true
                _ = player
            }

            if active {
                player.play()
            }
        }
    }

    class Coordinator {
        var loopObserver: NSObjectProtocol?
        var bgObserver: NSObjectProtocol?
        var fgObserver: NSObjectProtocol?
        var pauseObserver: NSObjectProtocol?
        var resumeObserver: NSObjectProtocol?

        deinit {
            [loopObserver, bgObserver, fgObserver, pauseObserver, resumeObserver].compactMap { $0 }.forEach {
                NotificationCenter.default.removeObserver($0)
            }
        }
    }
}

final class PlayerContainerView: UIView {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var currentURL: String?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
