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
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
            } else {
                // Onboarding gate then main app content
                if !didCompleteOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    if authManager.isAuthenticated {
                        MainTabView()
                            .transition(.opacity)
                    } else {
                        AuthenticationView()
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .transaction { $0.animation = nil }
        .ignoresSafeArea(.keyboard) // keep root stable when keyboard appears
    }
}

#Preview("Splash Container") {
    SplashContainer()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}