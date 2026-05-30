//
//  SplashView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SplashView: View {
    @State private var phase: SplashPhase = .initial
    @State private var particles: [SplashParticle] = []
    
    var onComplete: (() -> Void)?
    
    enum SplashPhase {
        case initial
        case popIn
        case explode
        case settle
        case fadeOut
    }
    
    struct SplashParticle: Identifiable {
        let id = UUID()
        var xOffset: CGFloat
        var yOffset: CGFloat
        var scale: CGFloat
        var opacity: Double
        var color: Color
    }
    
    var body: some View {
        ZStack {
            // Premium Blur Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Background morphing blob (Lottie-style background element)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [AppTheme.Colors.primary.opacity(0.3), Color.blue.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: phase == .explode ? 600 : 0, height: phase == .explode ? 600 : 0)
                .opacity(phase == .explode ? 1.0 : (phase == .settle ? 0.3 : 0.0))
                .blur(radius: 40)
                .animation(.spring(response: 1.2, dampingFraction: 0.6), value: phase)
            
            // Exploding Particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .offset(x: particle.xOffset, y: particle.yOffset)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main Logo
                Image("MyChannel")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotation3DEffect(
                        .degrees(phase == .popIn ? 360 : 0),
                        axis: (x: 0.0, y: 1.0, z: 0.0),
                        perspective: 0.5
                    )
                
                Spacer()
            }
        }
        .onAppear {
            startAdvancedAnimation()
        }
    }
    
    private var logoScale: CGFloat {
        switch phase {
        case .initial: return 0.0
        case .popIn: return 1.4
        case .explode: return 0.8
        case .settle: return 1.0
        case .fadeOut: return 10.0 // Zoom through effect
        }
    }
    
    private var logoOpacity: Double {
        switch phase {
        case .initial: return 0.0
        case .popIn, .explode, .settle: return 1.0
        case .fadeOut: return 0.0
        }
    }
    
    private func startAdvancedAnimation() {
        // Generate particles
        for _ in 0..<20 {
            particles.append(SplashParticle(
                xOffset: 0,
                yOffset: 0,
                scale: 0.1,
                opacity: 0.0,
                color: [.red, .white, .black, .gray].randomElement() ?? .red
            ))
        }
        
        Task { @MainActor in
            // 1. Pop In
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                phase = .popIn
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            // 2. Explode Particles & Background
            HapticManager.shared.impact(style: .heavy)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) {
                phase = .explode
                for i in 0..<particles.count {
                    let angle = Double.random(in: 0...(2 * .pi))
                    let distance = CGFloat.random(in: 100...250)
                    particles[i].xOffset = cos(angle) * distance
                    particles[i].yOffset = sin(angle) * distance
                    particles[i].scale = CGFloat.random(in: 0.5...2.0)
                    particles[i].opacity = 1.0
                }
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            // 3. Settle
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                phase = .settle
                for i in 0..<particles.count {
                    particles[i].scale = 0.0
                    particles[i].opacity = 0.0
                }
            }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            // 4. Fade Out / Zoom Through
            withAnimation(.easeIn(duration: 0.4)) {
                phase = .fadeOut
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            onComplete?()
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
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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