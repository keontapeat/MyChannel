//
//  AnimatedProgressRing.swift
//  MyChannel
//
//  🔥 NUCLEAR: Animated progress ring with spring animations
//  Professional circular progress with glow effects
//

import SwiftUI

struct AnimatedProgressRing: View {
    let progress: Double  // 0.0 to 1.0
    let lineWidth: CGFloat
    let primaryColor: Color
    let label: String
    let showPercentage: Bool
    
    @State private var animatedProgress: Double = 0.0
    @State private var pulseAnimation = false
    
    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        primaryColor: Color = AppTheme.Colors.primary,
        label: String = "",
        showPercentage: Bool = true
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.label = label
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    primaryColor.opacity(0.15),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            
            // Animated progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            primaryColor,
                            primaryColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0),
                    value: animatedProgress
                )
            
            // Glow effect
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    primaryColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.7),
                    value: animatedProgress
                )
            
            // Pulse effect for near-completion (>80%)
            if progress >= 0.8 {
                Circle()
                    .stroke(primaryColor.opacity(0.3), lineWidth: 2)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.6)
            }
            
            // Center content
            if showPercentage {
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
                    
                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
            
            if progress >= 0.8 {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    pulseAnimation = true
                }
            }
        }
        .onChange(of: progress) { newProgress in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newProgress
            }
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.isEmpty ? "Progress" : label)
        .accessibilityValue("\(Int(progress * 100))% complete")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Mini Progress Ring

struct MiniProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    init(
        progress: Double,
        size: CGFloat = 48,
        lineWidth: CGFloat = 4,
        color: Color = AppTheme.Colors.primary
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }
    
    @State private var animatedProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Progress Ring with Icon

struct ProgressRingWithIcon: View {
    let progress: Double
    let icon: String
    let color: Color
    let size: CGFloat
    
    @State private var animatedProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 12)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)
            
            // Icon
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.25, weight: .semibold))
                    .foregroundColor(color)
                
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            // Large progress ring
            AnimatedProgressRing(
                progress: 0.75,
                lineWidth: 12,
                primaryColor: .blue,
                label: "Complete",
                showPercentage: true
            )
            .frame(width: 120, height: 120)
            
            // Mini progress rings
            HStack(spacing: 20) {
                VStack {
                    MiniProgressRing(progress: 0.35, color: .blue)
                    Text("35%")
                        .font(.caption)
                }
                
                VStack {
                    MiniProgressRing(progress: 0.65, color: .green)
                    Text("65%")
                        .font(.caption)
                }
                
                VStack {
                    MiniProgressRing(progress: 0.85, color: .orange)
                    Text("85%")
                        .font(.caption)
                }
            }
            
            // Progress ring with icons
            HStack(spacing: 30) {
                ProgressRingWithIcon(
                    progress: 0.45,
                    icon: "graduationcap.fill",
                    color: .purple,
                    size: 100
                )
                
                ProgressRingWithIcon(
                    progress: 0.82,
                    icon: "star.fill",
                    color: .yellow,
                    size: 100
                )
            }
        }
        .padding(40)
    }
    .background(AppTheme.Colors.background)
}


