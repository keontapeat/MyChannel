//
//  SplashView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SplashView: View {
    @State private var isLoading: Bool = true
    @State private var progress: Double = 0.0
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 50
    @State private var showProgress: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo section
                    VStack(spacing: 24) {
                        // App logo with animation
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            AppTheme.Colors.primary.opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .scaleEffect(logoScale * 1.2)
                                .opacity(logoOpacity * 0.6)
                            
                            // Main logo
                            RoundedRectangle(cornerRadius: 30)
                                .fill(AppTheme.Colors.gradient)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    VStack(spacing: 2) {
                                        // Play button icon
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Channel waves
                                        HStack(spacing: 3) {
                                            ForEach(0..<3) { index in
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(.white)
                                                    .frame(width: 3, height: CGFloat(4 + index * 2))
                                                    .scaleEffect(y: logoScale + Double(index) * 0.2)
                                                    .animation(
                                                        .easeInOut(duration: 0.8)
                                                        .repeatForever(autoreverses: true)
                                                        .delay(Double(index) * 0.2),
                                                        value: logoScale
                                                    )
                                            }
                                        }
                                        .offset(y: 8)
                                    }
                                )
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                                .shadow(
                                    color: AppTheme.Colors.primary.opacity(0.4),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        }
                        
                        // App title with animation
                        VStack(spacing: 8) {
                            Text("MyChannel")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(y: titleOffset)
                                .opacity(logoOpacity)
                            
                            Text("Your Creative Universe")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .offset(y: titleOffset)
                                .opacity(logoOpacity * 0.8)
                        }
                    }
                    
                    Spacer()
                    
                    // Loading section
                    VStack(spacing: 24) {
                        if showProgress {
                            // Progress indicator
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(AppTheme.Colors.divider, lineWidth: 3)
                                        .frame(width: 50, height: 50)
                                    
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            AppTheme.Colors.gradient,
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 50, height: 50)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 0.3), value: progress)
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                                
                                Text("Preparing your experience...")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                        
                        // Loading dots animation
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(logoScale + Double(index) * 0.1)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: logoScale
                                    )
                            }
                        }
                        .opacity(showProgress ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showProgress)
                    }
                    .padding(.bottom, 60)
                }
                .padding()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startSplashAnimation()
        }
    }
    
    private func startSplashAnimation() {
        // Initial logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Title slide in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
            titleOffset = 0
        }
        
        // Show progress after logo animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showProgress = true
            }
            
            // Simulate loading progress
            simulateLoading()
        }
    }
    
    private func simulateLoading() {
        let steps = 20
        let stepDuration = 0.1
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    progress = Double(i) / Double(steps)
                }
                
                if i == steps {
                    // Loading complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
}

struct AnimatedGradientBackground: View {
    @State private var animateGradient: Bool = false
    
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.background,
                AppTheme.Colors.primary.opacity(0.05),
                AppTheme.Colors.secondary.opacity(0.03),
                AppTheme.Colors.background
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Splash Container View
struct SplashContainerView: View {
    @State private var showingSplash: Bool = true
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
            } else {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .identity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.8), value: showingSplash)
        .onReceive(NotificationCenter.default.publisher(for: .splashScreenComplete)) { _ in
            showingSplash = false
        }
        .onAppear {
            // Auto dismiss splash after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if showingSplash {
                    NotificationCenter.default.post(name: .splashScreenComplete, object: nil)
                }
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let splashScreenComplete = Notification.Name("splashScreenComplete")
}

// MARK: - Interactive Splash View (Alternative)
struct InteractiveSplashView: View {
    @State private var dragOffset: CGSize = .zero
    @State private var logoRotation: Double = 0
    @Binding var isComplete: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AnimatedGradientBackground()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Interactive logo
                    ZStack {
                        // Glow effect that responds to interaction
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppTheme.Colors.primary.opacity(0.4),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100 + abs(dragOffset.width + dragOffset.height) / 4
                                )
                            )
                            .frame(width: 200, height: 200)
                            .opacity(0.6)
                        
                        // Logo
                        RoundedRectangle(cornerRadius: 30)
                            .fill(AppTheme.Colors.gradient)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .rotationEffect(.degrees(logoRotation))
                            .scaleEffect(1 + abs(dragOffset.width + dragOffset.height) / 500)
                            .offset(dragOffset)
                            .shadow(
                                color: AppTheme.Colors.primary.opacity(0.4),
                                radius: 20 + abs(dragOffset.width + dragOffset.height) / 10,
                                x: 0,
                                y: 10
                            )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                logoRotation = Double(value.translation.width / 10)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                    logoRotation = 0
                                }
                                
                                // Complete splash on interaction
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isComplete = true
                                }
                            }
                    )
                    
                    VStack(spacing: 16) {
                        Text("MyChannel")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.gradient)
                        
                        VStack(spacing: 8) {
                            Text("Your Creative Universe")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("👆 Drag the logo to start")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .opacity(dragOffset == .zero ? 1 : 0)
                                .animation(.easeInOut(duration: 0.3), value: dragOffset)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Standard Splash") {
    SplashView()
}

#Preview("Splash Container") {
    SplashContainerView()
}

#Preview("Interactive Splash") {
    InteractiveSplashView(isComplete: .constant(false))
}