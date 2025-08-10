//
//  FlicksDoubleTapHeartAnimation.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

// MARK: - 💖 TikTok-Style Double Tap Heart Animation
struct FlicksDoubleTapHeartAnimation: View {
    let location: CGPoint?
    let isShowing: Bool
    
    @State private var animationScale: CGFloat = 0.5
    @State private var animationOpacity: Double = 0.0
    @State private var particleAnimations: [Bool] = Array(repeating: false, count: 8)
    
    var body: some View {
        ZStack {
            if let location = location, isShowing {
                // Main pulsing heart
                ZStack {
                    // Outer glow
                    Image(systemName: "heart.fill")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundStyle(
                            RadialGradient(
                                colors: [.pink.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .scaleEffect(animationScale * 1.5)
                        .opacity(animationOpacity * 0.6)
                    
                    // Main heart
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animationScale)
                        .opacity(animationOpacity)
                        .shadow(color: .pink.opacity(0.8), radius: 20, x: 0, y: 0)
                    
                    // Inner sparkle
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(animationScale * 0.8)
                        .opacity(animationOpacity)
                }
                .position(location)
                
                // Floating heart particles
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) * 45.0 * .pi / 180.0
                    let distance: CGFloat = 60
                    
                    Image(systemName: index % 2 == 0 ? "heart.fill" : "star.fill")
                        .font(.system(size: CGFloat.random(in: 12...20), weight: .bold))
                        .foregroundColor(index % 2 == 0 ? .pink : .yellow)
                        .position(
                            x: location.x + cos(angle) * distance * (particleAnimations[index] ? 1.5 : 0.3),
                            y: location.y + sin(angle) * distance * (particleAnimations[index] ? 1.5 : 0.3)
                        )
                        .opacity(particleAnimations[index] ? 0.0 : 1.0)
                        .scaleEffect(particleAnimations[index] ? 0.1 : 1.0)
                        .animation(
                            .easeOut(duration: 1.0)
                            .delay(Double(index) * 0.1),
                            value: particleAnimations[index]
                        )
                }
            }
        }
        .onChange(of: isShowing) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                resetAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // Main heart animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationScale = 1.2
            animationOpacity = 1.0
        }
        
        // Scale down after peak
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animationScale = 1.0
            }
        }
        
        // Start particle animations
        for i in 0..<particleAnimations.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                particleAnimations[i] = true
            }
        }
        
        // Fade out after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationOpacity = 0.0
                animationScale = 0.5
            }
        }
    }
    
    private func resetAnimation() {
        animationScale = 0.5
        animationOpacity = 0.0
        particleAnimations = Array(repeating: false, count: 8)
    }
}

#Preview {
    @State var isShowing = false
    @State var location: CGPoint = CGPoint(x: 200, y: 400)
    
    return ZStack {
        Color.black.ignoresSafeArea()
        
        FlicksDoubleTapHeartAnimation(
            location: location,
            isShowing: isShowing
        )
        
        VStack {
            Spacer()
            
            Button("Trigger Heart Animation") {
                isShowing = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isShowing = false
                }
            }
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding()
        }
    }
    .onTapGesture { tapLocation in
        location = tapLocation
        isShowing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isShowing = false
        }
    }
}