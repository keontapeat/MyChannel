//
//  PiPEnabledVideoPlayer.swift
//  MyChannel
//
//  🔥🔥🔥 THERMONUCLEAR PERFORMANCE: SwiftUI VideoPlayer with native iOS PiP
//  Target: ZERO-DELAY PiP setup and instant start
//

import SwiftUI
import AVKit

/// 🔥 THERMONUCLEAR: Global PiP manager with zero-delay setup
class PiPPlayerManager: NSObject, AVPictureInPictureControllerDelegate {
    static let shared = PiPPlayerManager()
    
    weak var currentPlayerViewController: AVPlayerViewController?
    var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    private var playerLayer: AVPlayerLayer?  // 🔥 PERF: Reusable layer
    private var lastPlayer: AVPlayer?  // 🔥 PERF: Track for skip redundant setup
    private var isPiPPossible = false  // 🔥 PERF: Cached state
    private var retryWorkItem: DispatchWorkItem?  // 🔥 PERF: Cancellable retry
    
    private override init() {
        super.init()
    }
    
    /// 🔥 THERMONUCLEAR: Zero-delay PiP setup
    func setupPiP(for playerViewController: AVPlayerViewController, player: AVPlayer) {
        // 🔥 PERF: Skip if same setup
        if lastPlayer === player && pipController != nil {
            currentPlayerViewController = playerViewController
            return
        }
        
        currentPlayerViewController = playerViewController
        lastPlayer = player
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        
        // 🔥 PERF: Cancel pending retries
        retryWorkItem?.cancel()
        
        // 🔥 PERF: Reuse player layer
        if playerLayer == nil {
            playerLayer = AVPlayerLayer()
        }
        playerLayer?.player = player
        playerLayer?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        // 🔥 PERF: Add layer only if needed
        if let view = playerViewController.view, playerLayer?.superlayer == nil {
            view.layer.addSublayer(playerLayer!)
        }
        
        // 🔥 PERF: Setup controller without delay
        if let controller = AVPictureInPictureController(playerLayer: playerLayer!) {
            // Clean up old observer first
            pipPossibleObservation?.invalidate()
            
            pipController = controller
            controller.delegate = self
            
            // 🔥 PERF: Immediate state sync
            isPiPPossible = controller.isPictureInPicturePossible
            
            // 🔥 PERF: KVO with cached state
            pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new, .initial]) { [weak self] controller, _ in
                DispatchQueue.main.async {
                    self?.isPiPPossible = controller.isPictureInPicturePossible
                }
            }
            
            print("✅ [PiPPlayerManager] Ready, possible: \(isPiPPossible)")
        }
    }
    
    /// 🔥 THERMONUCLEAR: Instant PiP start
    func startPiP() {
        guard let pipController = pipController else { return }
        guard !pipController.isPictureInPictureActive else { return }
        
        // 🔥 PERF: Immediate start if possible
        if isPiPPossible {
            pipController.startPictureInPicture()
            print("⚡ [PiPPlayerManager] PiP started INSTANTLY")
            return
        }
        
        // 🔥 PERF: Fast retry (100ms intervals, not 500ms)
        retryWorkItem?.cancel()
        var retryCount = 0
        let maxRetries = 10
        
        func tryStart() {
            guard retryCount < maxRetries else { return }
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      let controller = self.pipController,
                      !controller.isPictureInPictureActive else { return }
                
                if controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                    print("✅ [PiPPlayerManager] PiP started after retry \(retryCount)")
                } else {
                    retryCount += 1
                    tryStart()
                }
            }
            
            self.retryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
        
        tryStart()
    }
    
    /// 🔥 PERF: Stop with cleanup
    func stopPiP() {
        retryWorkItem?.cancel()
        pipController?.stopPictureInPicture()
    }
    
    func cleanup() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        lastPlayer = nil
        currentPlayerViewController = nil
        isPiPPossible = false
    }
    
    // MARK: - AVPictureInPictureControllerDelegate (THERMONUCLEAR)
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("✅ [PiPPlayerManager] PiP STARTED")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("✅ [PiPPlayerManager] PiP STOPPED")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("❌ [PiPPlayerManager] Failed: \(error.localizedDescription)")
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // 🔥 THERMONUCLEAR: Instant restore without delay
        NotificationCenter.default.post(
            name: NSNotification.Name("ExpandFromNativePiP"),
            object: nil
        )
        
        // 🔥 PERF: Complete immediately
        completionHandler(true)
        print("⚡ [PiPPlayerManager] UI restored INSTANTLY")
    }
}

/// 🔥 THERMONUCLEAR: VideoPlayer with PiP and zero-delay setup
struct PiPEnabledVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // 🔥 ENABLE Picture-in-Picture
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        
        // Disable auto-fullscreen
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        
        // 🔥 THERMONUCLEAR: Immediate PiP setup (no delay!)
        if let player = player {
            PiPPlayerManager.shared.setupPiP(for: controller, player: player)
        }
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
            
            // 🔥 THERMONUCLEAR: Immediate PiP re-setup (no delay!)
            if let player = player {
                PiPPlayerManager.shared.setupPiP(for: controller, player: player)
            }
        }
        
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
    }
}

