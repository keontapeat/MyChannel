//
//  NativePiPController.swift
//  MyChannel
//
//  YouTube Parity: Native iOS PiP for background playback
//  Activates ONLY when user leaves the app (goes to home screen/another app)
//

import AVKit
import SwiftUI

@MainActor
class NativePiPController: NSObject, ObservableObject {
    static let shared = NativePiPController()
    
    @Published var isPiPActive = false
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    
    private override init() {
        super.init()
        print("🎬 [NativePiP] Initialized")
    }
    
    /// Setup PiP controller with a player
    func setup(with player: AVPlayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("⚠️ [NativePiP] PiP not supported on this device")
            return
        }
        
        // Create AVPlayerLayer (required for PiP)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Create PiP controller
        if let controller = try? AVPictureInPictureController(playerLayer: playerLayer) {
            controller.delegate = self
            controller.canStartPictureInPictureAutomaticallyFromInline = false  // Manual control
            pipController = controller
            print("✅ [NativePiP] Controller setup complete, possible: \(controller.isPictureInPicturePossible)")
            
            // Observe when PiP becomes possible
            pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, change in
                Task { @MainActor in
                    print("🔔 [NativePiP] isPictureInPicturePossible changed to: \(controller.isPictureInPicturePossible)")
                }
            }
        } else {
            print("❌ [NativePiP] Failed to create PiP controller")
        }
    }
    
    /// Start PiP (when app backgrounds)
    func startPiP() {
        guard let pipController = pipController else {
            print("⚠️ [NativePiP] Cannot start PiP - controller is nil")
            return
        }
        
        print("🔍 [NativePiP] PiP Status:")
        print("   - Controller exists: ✅")
        print("   - isPictureInPictureActive: \(pipController.isPictureInPictureActive)")
        print("   - isPictureInPicturePossible: \(pipController.isPictureInPicturePossible)")
        
        guard !pipController.isPictureInPictureActive else {
            print("⚠️ [NativePiP] PiP already active")
            return
        }
        
        guard pipController.isPictureInPicturePossible else {
            print("⚠️ [NativePiP] PiP not possible yet - waiting for player to be ready")
            // Try again after a short delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if pipController.isPictureInPicturePossible {
                    print("✅ [NativePiP] PiP now possible, retrying...")
                    pipController.startPictureInPicture()
                } else {
                    print("❌ [NativePiP] PiP still not possible after waiting")
                }
            }
            return
        }
        
        print("▶️ [NativePiP] Starting PiP...")
        pipController.startPictureInPicture()
    }
    
    /// Stop PiP (when app foregrounds)
    func stopPiP() {
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else {
            print("⚠️ [NativePiP] PiP not active")
            return
        }
        
        print("⏹️ [NativePiP] Stopping PiP...")
        pipController.stopPictureInPicture()
    }
    
    /// Check if PiP is currently active
    var isActive: Bool {
        pipController?.isPictureInPictureActive ?? false
    }
    
    /// Cleanup
    func cleanup() {
        stopPiP()
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
        print("🧹 [NativePiP] Cleaned up")
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension NativePiPController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("🎬 [NativePiP] Will start PiP")
            isPiPActive = true
        }
    }
    
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("✅ [NativePiP] Did start PiP")
            isPiPActive = true
        }
    }
    
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("🎬 [NativePiP] Will stop PiP")
        }
    }
    
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("✅ [NativePiP] Did stop PiP")
            isPiPActive = false
        }
    }
    
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor in
            print("❌ [NativePiP] Failed to start: \(error.localizedDescription)")
            isPiPActive = false
        }
    }
    
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            print("🔄 [NativePiP] Restore UI requested (user tapped PiP window)")
            
            // 🔥 FIX: Stop PiP first before expanding
            isPiPActive = false
            
            // Notify GlobalVideoPlayerManager to expand to fullscreen
            NotificationCenter.default.post(
                name: NSNotification.Name("ExpandFromNativePiP"),
                object: nil
            )
            
            // Wait briefly for UI to prepare
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            completionHandler(true)
            
            print("✅ [NativePiP] UI restored - PiP dismissed, fullscreen should show")
        }
    }
}

