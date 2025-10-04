//
//  SplashView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var showProgress: Bool = false
    @State private var progress: Double = 0.0
    
    var onComplete: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Clean white background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // YouTube-style animated logo
                Image("MyChannel")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(logoScale * pulseScale)
                    .opacity(logoOpacity)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                
                Spacer()
                
                // Simple loading indicator (YouTube style)
                if showProgress {
                    VStack(spacing: 20) {
                        // Clean progress bar
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.Colors.divider)
                                .frame(width: 200, height: 3)
                                .cornerRadius(1.5)
                            
                            Rectangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 200 * progress, height: 3)
                                .cornerRadius(1.5)
                                .animation(.easeOut(duration: 0.3), value: progress)
                        }
                        .transition(.opacity)
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Logo fade in with bounce
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7, blendDuration: 0)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Start pulse effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        
        // Show loading after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showProgress = true
            }
            
            // Animate progress
            animateProgress()
        }
    }
    
    private func animateProgress() {
        let progressSteps: [Double] = [0.3, 0.6, 0.85, 1.0]
        
        for (index, targetProgress) in progressSteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    progress = targetProgress
                }
                
                // Complete when done
                if targetProgress >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete?()
                    }
                }
            }
        }
    }
}

// MARK: - Super Simple Version (Even Cleaner)
struct MinimalSplashView: View {
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.9
    
    var onComplete: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Pure white background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Just the logo, clean AF
            Image("MyChannel")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .onAppear {
            // Simple fade in
            withAnimation(.easeOut(duration: 1.0)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            
            // Auto complete after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete?()
            }
        }
    }
}

// MARK: - Previews
#Preview("Clean Splash") {
    SplashView()
}

#Preview("Splash Container") {
    SplashContainer()
        .environmentObject(AuthenticationManager.shared)
        // Provide a default user for the preview AppState to prevent crashes in subviews expecting a user
        .environmentObject( {
            let appState = AppState()
            appState.currentUser = User.defaultUser
            return appState
        }() )
        .environmentObject(GlobalVideoPlayerManager.shared)
}

#Preview("Minimal Splash") {
    MinimalSplashView()
}