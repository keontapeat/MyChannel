//
//  MyChannelLogo.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct MyChannelLogo: View {
    let size: CGFloat
    let showText: Bool
    let animated: Bool
    
    @State private var animationScale: CGFloat = 1.0
    @State private var waveAnimation: Bool = false
    
    init(size: CGFloat = 120, showText: Bool = true, animated: Bool = false) {
        self.size = size
        self.showText = showText
        self.animated = animated
    }
    
    var body: some View {
        VStack(spacing: showText ? 12 : 0) {
            // Use the existing logo from Assets
            Image("MyChannel")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .scaleEffect(animationScale)
                .animation(
                    animated ? .spring(response: 0.8, dampingFraction: 0.6) : .none,
                    value: animationScale
                )
            
            // Optional text
            if showText {
                Text("MyChannel")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(animationScale)
            }
        }
        .onAppear {
            if animated {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // Logo scale animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            animationScale = 1.0
        }
        
        // Continuous subtle pulse
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                animationScale = animationScale == 1.0 ? 1.05 : 1.0
            }
        }
    }
}

#Preview("Static Logo") {
    VStack(spacing: 40) {
        MyChannelLogo(size: 60, showText: false, animated: false)
        MyChannelLogo(size: 120, showText: true, animated: false)
        MyChannelLogo(size: 180, showText: true, animated: false)
    }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Animated Logo") {
    MyChannelLogo(size: 120, showText: true, animated: true)
        .padding()
        .background(AppTheme.Colors.background)
}