//
//  NoPiPVideoPlayer.swift
//  MyChannel
//
//  SwiftUI VideoPlayer replacement with PiP DISABLED
//

import SwiftUI
import AVKit

/// Drop-in replacement for SwiftUI's VideoPlayer with Picture-in-Picture DISABLED
/// Use this instead of VideoPlayer to prevent native iOS PiP from appearing
struct NoPiPVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // 🔥 CRITICAL: Disable Picture-in-Picture
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        
        // Disable fullscreen (optional - remove if you want fullscreen)
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        
        // Ensure PiP stays disabled even after updates
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
    }
}

// MARK: - Usage Example
/*
 Replace:
 VideoPlayer(player: player)
 
 With:
 NoPiPVideoPlayer(player: player)
 
 That's it! PiP is now disabled for that player.
 */


