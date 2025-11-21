//
//  PlayerPiPContainerView.swift
//  MyChannel
//
//  🔥 DISABLED: Native iOS Picture-in-Picture
//  We use custom YouTube-style mini-player instead (FloatingMiniPlayer.swift)
//  Native PiP is ugly and not YouTube parity - this file is kept for backwards compatibility only
//

import SwiftUI
import AVKit

// 🔥 DISABLED: This view is now a no-op to prevent native PiP
struct PlayerPiPContainerView: View {
    let player: AVPlayer
    @Binding var isPictureInPictureActive: Bool
    
    var body: some View {
        // 🔥 NATIVE PiP COMPLETELY DISABLED
        // Return EmptyView to prevent any PiP UI from appearing
        // Custom YouTube-style mini-player is used instead (FloatingMiniPlayer.swift)
        EmptyView()
            .onAppear {
                // Force PiP to always be disabled
                isPictureInPictureActive = false
                print("🚫 [PlayerPiPContainerView] Native PiP disabled - using custom mini-player")
            }
    }
}


