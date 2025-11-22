//
//  GlobalMiniPlayerOverlay.swift
//  MyChannel
//
//  Created by AI Assistant on 11/22/25.
//

import SwiftUI

/// Hosts the floating mini player at the window level so it appears across the entire app.
struct GlobalMiniPlayerOverlay: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    
    var body: some View {
        Group {
            if shouldRenderMiniPlayer {
                FloatingMiniPlayer()
                    .environmentObject(appState)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(100_000)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: shouldRenderMiniPlayer)
    }
    
    private var shouldRenderMiniPlayer: Bool {
        globalPlayer.currentVideo != nil &&
        globalPlayer.shouldShowMiniPlayer &&
        !globalPlayer.showingFullscreen &&
        !globalPlayer.isTransitioning &&
        !globalPlayer.isCleanedUp
    }
}


