//
//  ParallaxMyChannelLogo.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ParallaxMyChannelLogo: View {
    let logoSize: CGFloat
    let scrollOffset: CGFloat
    let showText: Bool
    let animated: Bool
    
    @State private var logoOffset: CGFloat = 0
    @State private var logoScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 1.0
    
    init(size: CGFloat = 36, scrollOffset: CGFloat = 0, showText: Bool = false, animated: Bool = true) {
        self.logoSize = size
        self.scrollOffset = scrollOffset
        self.showText = showText
        self.animated = animated
    }
    
    var body: some View {
        MyChannelLogo(size: logoSize, showText: showText, animated: animated)
            .offset(y: logoOffset)
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .onChange(of: scrollOffset) { oldValue, newValue in
                updateParallaxEffect(newValue)
            }
    }
    
    private func updateParallaxEffect(_ offset: CGFloat) {
        let threshold: CGFloat = 100
        let progress = min(abs(offset) / threshold, 1.0)
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            logoOffset = offset * 0.3
            logoScale = 1.0 + (progress * 0.15)
            logoOpacity = max(0.7, 1.0 - (progress * 0.3))
        }
    }
}

#Preview("Parallax Logo") {
    VStack(spacing: 40) {
        Text("MyChannel Parallax Logo")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        // Parallax examples
        VStack(spacing: 20) {
            Text("Parallax Effects")
                .font(.headline)
            
            ParallaxMyChannelLogo(
                size: 40,
                scrollOffset: 0,
                showText: true,
                animated: true
            )
            
            ParallaxMyChannelLogo(
                size: 50,
                scrollOffset: -20,
                showText: false,
                animated: true
            )
        }
    }
    .padding()
    .background(AppTheme.Colors.background)
}