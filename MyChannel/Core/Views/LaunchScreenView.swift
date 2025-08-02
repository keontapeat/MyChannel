//
//  LaunchScreenView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 50
    @State private var showContent: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.primary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and branding
                VStack(spacing: 32) {
                    // App logo with animation using existing asset
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
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(logoScale * 1.2)
                            .opacity(logoOpacity * 0.6)
                        
                        // Main logo from assets
                        MyChannelLogo(size: 120, showText: false, animated: false)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .shadow(
                                color: AppTheme.Colors.primary.opacity(0.4),
                                radius: 25,
                                x: 0,
                                y: 15
                            )
                    }
                    
                    // App name and tagline
                    VStack(spacing: 16) {
                        Text("MyChannel")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(y: textOffset)
                            .opacity(logoOpacity)
                        
                        Text("Your Creative Universe")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .offset(y: textOffset)
                            .opacity(logoOpacity * 0.9)
                    }
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        .scaleEffect(1.2)
                        .opacity(logoOpacity)
                    
                    Text("Loading your creative universe...")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .opacity(logoOpacity * 0.8)
                }
                .padding(.bottom, 60)
                
                // Copyright
                Text("© 2024 MyChannel")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary.opacity(0.6))
                    .opacity(logoOpacity * 0.7)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            startLaunchAnimation()
        }
    }
    
    private func startLaunchAnimation() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Text slide in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
            textOffset = 0
        }
        
        // Show content after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showContent = true
        }
    }
}

#Preview {
    LaunchScreenView()
}