//
//  PiPEnabledVideoPlayer.swift
//  MyChannel
//
//  SwiftUI VideoPlayer with native iOS PiP ENABLED
//

import SwiftUI
import AVKit

/// Global reference to the current PiP-enabled player view controller
/// This allows GlobalVideoPlayerManager to trigger PiP
class PiPPlayerManager: NSObject, AVPictureInPictureControllerDelegate {
    static let shared = PiPPlayerManager()
    weak var currentPlayerViewController: AVPlayerViewController?
    var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    
    private override init() {
        super.init()
    }
    
    func setupPiP(for playerViewController: AVPlayerViewController, player: AVPlayer) {
        currentPlayerViewController = playerViewController
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("⚠️ [PiPPlayerManager] PiP not supported")
            return
        }
        
        // Create a player layer for PiP
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1) // Minimal size, not visible
        
        // Add to a view to keep it alive
        if let view = playerViewController.view {
            view.layer.addSublayer(playerLayer)
        }
        
        // Create PiP controller
        if let controller = try? AVPictureInPictureController(playerLayer: playerLayer) {
            pipController = controller
            controller.delegate = self  // 🔥 FIX: Set delegate for restore handling
            
            // Observe when PiP becomes possible
            pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new, .initial]) { [weak self] controller, _ in
                print("🔔 [PiPPlayerManager] isPictureInPicturePossible: \(controller.isPictureInPicturePossible)")
            }
            
            print("✅ [PiPPlayerManager] PiP controller created with delegate")
        } else {
            print("❌ [PiPPlayerManager] Failed to create PiP controller")
        }
    }
    
    func startPiP() {
        guard let pipController = pipController else {
            print("⚠️ [PiPPlayerManager] No PiP controller")
            return
        }
        
        print("🔍 [PiPPlayerManager] PiP Status:")
        print("   - isPictureInPictureActive: \(pipController.isPictureInPictureActive)")
        print("   - isPictureInPicturePossible: \(pipController.isPictureInPicturePossible)")
        
        if pipController.isPictureInPicturePossible {
            print("▶️ [PiPPlayerManager] Starting PiP...")
            pipController.startPictureInPicture()
        } else {
            print("⚠️ [PiPPlayerManager] PiP not possible - trying again in 0.5s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if let pipController = self?.pipController, pipController.isPictureInPicturePossible {
                    print("✅ [PiPPlayerManager] PiP now possible, starting...")
                    pipController.startPictureInPicture()
                } else {
                    print("❌ [PiPPlayerManager] PiP still not possible")
                }
            }
        }
    }
    
    func cleanup() {
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
        currentPlayerViewController = nil
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("🎬 [PiPPlayerManager] PiP did START")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("🛑 [PiPPlayerManager] PiP did STOP")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("❌ [PiPPlayerManager] PiP failed to start: \(error.localizedDescription)")
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        print("🔄 [PiPPlayerManager] Restore UI requested - user tapped PiP window!")
        
        // 🔥 YOUTUBE PARITY: Notify GlobalVideoPlayerManager to expand to fullscreen
        NotificationCenter.default.post(
            name: NSNotification.Name("ExpandFromNativePiP"),
            object: nil
        )
        
        // Wait briefly for UI to prepare, then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completionHandler(true)
            print("✅ [PiPPlayerManager] UI restored - VideoDetailView should appear")
        }
    }
}

/// VideoPlayer with Picture-in-Picture ENABLED
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
        
        // Setup PiP manager
        if let player = player {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                PiPPlayerManager.shared.setupPiP(for: controller, player: player)
            }
        }
        
        print("✅ [PiPEnabledVideoPlayer] Created with PiP enabled")
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
            print("🔄 [PiPEnabledVideoPlayer] Player updated")
            
            // Re-setup PiP for new player
            if let player = player {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    PiPPlayerManager.shared.setupPiP(for: controller, player: player)
                }
            }
        }
        
        // Ensure PiP stays enabled
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
    }
}

