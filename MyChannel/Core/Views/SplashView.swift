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
    @State private var titleOpacity: Double = 0.0
    @State private var progressValue: Double = 0.0
    @State private var isAnimating: Bool = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background with gradient
            AppTheme.Colors.gradient
                .ignoresSafeArea()
            
            // Animated background particles
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 20...40))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo with animation
                VStack(spacing: 24) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: logoScale)
                        .animation(.easeInOut(duration: 0.8), value: logoOpacity)
                    
                    // App title
                    Text("MyChannel")
                        .font(AppTheme.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: titleOpacity)
                    
                    // Subtitle
                    Text("Your Creative Universe")
                        .font(AppTheme.Typography.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.5), value: titleOpacity)
                }
                
                Spacer()
                
                // Loading progress
                VStack(spacing: 16) {
                    ProgressView(value: progressValue, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.white)
                        .scaleEffect(y: 2)
                        .frame(width: 200)
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.7), value: titleOpacity)
                    
                    Text("Loading your content...")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.9), value: titleOpacity)
                    
                    // Tap to continue hint
                    Text("Tap to continue")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(1.5), value: titleOpacity)
                }
                
                Spacer()
                    .frame(height: 60)
            }
            .padding(32)
        }
        .onAppear {
            startAnimation()
        }
        .onTapGesture {
            onComplete()
        }
    }
    
    private func startAnimation() {
        // Start particle animation
        isAnimating = true
        
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Title animation
        withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
            titleOpacity = 1.0
        }
        
        // Progress animation
        withAnimation(.easeInOut(duration: 1.5).delay(1.0)) {
            progressValue = 1.0
        }
        
        // Complete after shorter animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

#Preview {
    SplashView {
        print("Splash completed")
    }
}