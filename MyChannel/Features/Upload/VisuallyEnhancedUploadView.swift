//
//  VisuallyEnhancedUploadView.swift
//  MyChannel
//
//  Created by AI Assistant on 1/19/25.
//

import SwiftUI

// This is a demonstration of the visual improvements that should be applied to UploadView.swift
// Copy these components and replace the corresponding ones in the main file

struct DramaticUploadButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: isEnabled ? 
                        [AppTheme.Colors.primary, AppTheme.Colors.secondary] : 
                        [AppTheme.Colors.textTertiary, AppTheme.Colors.textTertiary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Shimmer effect
                if isEnabled {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.4),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            shimmerOffset = 200
                        }
                    }
                }
                
                // Content
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: isEnabled ? AppTheme.Colors.primary.opacity(0.4) : .clear,
                radius: 15,
                x: 0,
                y: 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isEnabled ? Color.white.opacity(0.3) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.shared.impact(style: .medium)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct PulsingProgressIndicator: View {
    let progress: Double
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(AppTheme.Colors.surface, lineWidth: 12)
                .frame(width: 160, height: 160)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            // Pulsing glow effect
            Circle()
                .stroke(
                    AppTheme.Colors.primary.opacity(0.3),
                    lineWidth: 20
                )
                .frame(width: 180, height: 180)
                .scaleEffect(pulseScale)
                .opacity(2.0 - pulseScale)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulseScale
                )
                .onAppear {
                    pulseScale = 1.3
                }
            
            // Center content
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                HStack(spacing: 4) {
                    Text("Uploading")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    // Animated dots
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 4, height: 4)
                            .scaleEffect(progress > 0 ? 1.0 : 0.5)
                            .opacity(progress > 0 ? 1.0 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: progress
                            )
                    }
                }
            }
        }
    }
}

struct EnhancedProgressStep: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    
    @State private var checkmarkScale: CGFloat = 0.8
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isActive ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                    .frame(width: 24, height: 24)
                    .shadow(
                        color: isCompleted ? .green.opacity(0.4) : (isActive ? AppTheme.Colors.primary.opacity(0.4) : .clear),
                        radius: isCompleted || isActive ? 8 : 0,
                        x: 0,
                        y: 2
                    )
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                checkmarkScale = 1.2
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    checkmarkScale = 1.0
                                }
                            }
                        }
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                }
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(
                    isCompleted ? .green : 
                    (isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                )
            
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCompleted)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
    }
}

struct FloatingCreationModeBar: View {
    @Binding var selected: UploadView.CreationMode
    let onTap: (UploadView.CreationMode) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(UploadView.CreationMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selected = mode
                    }
                    onTap(mode)
                } label: {
                    ZStack {
                        if selected == mode {
                            Capsule()
                                .fill(Color.white)
                                .frame(height: 36)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.8), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(mode.title)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .foregroundColor(selected == mode ? .black : .white)
                        .scaleEffect(selected == mode ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected == mode)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.9))
                
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 25, x: 0, y: 15)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected)
        .scaleEffect(1.02)
    }
}

#Preview("Enhanced Components") {
    VStack(spacing: 30) {
        DramaticUploadButton(title: "Upload Video", isEnabled: true) {
            print("Upload tapped")
        }
        
        PulsingProgressIndicator(progress: 0.65)
        
        VStack(spacing: 12) {
            EnhancedProgressStep(title: "Analyzing video", isCompleted: true, isActive: false)
            EnhancedProgressStep(title: "Optimizing quality", isCompleted: false, isActive: true)
            EnhancedProgressStep(title: "Publishing video", isCompleted: false, isActive: false)
        }
        .padding()
        
        FloatingCreationModeBar(selected: .constant(.video)) { _ in }
    }
    .padding()
    .background(AppTheme.Colors.background)
}
