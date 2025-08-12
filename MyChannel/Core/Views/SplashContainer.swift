//
//  SplashContainer.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

// MARK: - Splash Container (Main Entry Point)
struct SplashContainer: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
            } else {
                // Main app content
                if authManager.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    AuthenticationView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
    }
}

#Preview("Splash Container") {
    SplashContainer()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}
