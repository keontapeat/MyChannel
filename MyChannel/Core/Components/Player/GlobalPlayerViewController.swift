//
//  GlobalPlayerViewController.swift
//  MyChannel
//
//  Created by AI Assistant on 11/22/25.
//

import SwiftUI
import AVKit

/// UIKit-powered player surface with native iOS Picture-in-Picture support.
struct GlobalPlayerViewController: UIViewControllerRepresentable {
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = globalPlayer.player
        controller.showsPlaybackControls = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        // ✅ ENABLED: Native iOS PiP
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false  // Manual control
        
        // Store reference for PiP access
        context.coordinator.playerViewController = controller
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== globalPlayer.player {
            controller.player = globalPlayer.player
        }
        controller.player?.preventsDisplaySleepDuringVideoPlayback = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(globalPlayer: globalPlayer)
    }
    
    class Coordinator: NSObject {
        let globalPlayer: GlobalVideoPlayerManager
        weak var playerViewController: AVPlayerViewController?
        
        init(globalPlayer: GlobalVideoPlayerManager) {
            self.globalPlayer = globalPlayer
        }
    }
}




