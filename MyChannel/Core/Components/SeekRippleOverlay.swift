//
//  SeekRippleOverlay.swift
//  MyChannel
//
//  YouTube-style double-tap seek ripple with chevrons and amount label.
//

import SwiftUI

enum SeekDirection {
    case backward, forward
}

struct SeekRippleOverlay: View {
    let direction: SeekDirection
    let seconds: Int
    @Binding var isVisible: Bool
    
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.0
    @State private var chevronOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: 120, height: 120)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    if direction == .backward {
                        chevron
                        chevron
                        chevron
                    }
                    Text("\(seconds)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    if direction == .forward {
                        chevron
                        chevron
                        chevron
                    }
                }
                .offset(x: chevronOffset)
                Text("sec")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .onChange(of: isVisible) { _, value in
            if value { playAnimation() }
        }
        .onAppear { if isVisible { playAnimation() } }
    }
    
    private var chevron: some View {
        Image(systemName: direction == .forward ? "chevron.forward" : "chevron.backward")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .opacity(0.95)
    }
    
    private func playAnimation() {
        rippleScale = 0.8
        rippleOpacity = 0.0
        chevronOffset = 0
        withAnimation(.easeOut(duration: 0.12)) {
            rippleOpacity = 1.0
            rippleScale = 1.05
            chevronOffset = direction == .forward ? 6 : -6
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.12)) {
            rippleScale = 1.0
            chevronOffset = 0
        }
        withAnimation(.easeInOut(duration: 0.18).delay(0.35)) {
            rippleOpacity = 0.0
        }
    }
}

#Preview {
    ZStack {
        Color.black
        SeekRippleOverlay(direction: .forward, seconds: 20, isVisible: .constant(true))
    }
}


