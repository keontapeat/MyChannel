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

    @State private var isVisible: Bool = false

    init(size: CGFloat = 120, showText: Bool = true, animated: Bool = false) {
        self.size = size
        self.showText = showText
        self.animated = animated
    }

    var body: some View {
        VStack(spacing: showText ? 12 : 0) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.Colors.primary,
                                AppTheme.Colors.secondary
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: size/2
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.35),
                        radius: animated ? 8 : 6,
                        x: 0,
                        y: 2
                    )

                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(.white)
                        .frame(width: size * 0.5, height: size * 0.35)
                        .overlay(
                            Triangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: size * 0.2, height: size * 0.2)
                        )

                    HStack(spacing: size * 0.15) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(.white.opacity(0.6))
                                .frame(width: size * 0.06, height: size * 0.06)
                        }
                    }
                    .offset(y: size * 0.25)
                }
            }
            .opacity(animated ? (isVisible ? 1.0 : 0.92) : 1.0)

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
                    .opacity(animated ? (isVisible ? 1.0 : 0.9) : 1.0)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.5)) {
                    isVisible = true
                }
            }
        }
    }
}

// MARK: - Triangle Shape for Play Icon
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
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

#Preview("Animated Logo (no bounce)") {
    MyChannelLogo(size: 120, showText: true, animated: true)
        .padding()
        .background(AppTheme.Colors.background)
}