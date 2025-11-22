//
//  AIToolsPanel.swift
//  MyChannel
//
//  🤖 AI TOOLS PANEL
//  AI-powered enhancement tools
//

import SwiftUI

struct AIToolsPanel: View {
    @ObservedObject var viewModel: UltimateStoryViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("AI Tools")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            
            // AI Tools
            ScrollView {
                VStack(spacing: 16) {
                    // Auto Enhance
                    AIToolCard(
                        icon: "cpu",
                        title: "Auto Enhance",
                        description: "AI-powered color correction & optimization",
                        gradient: [.purple, .pink]
                    ) {
                        Task {
                            await viewModel.enhanceWithAI()
                        }
                    }
                    
                    // Beauty Filter
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20))
                                .foregroundColor(.pink)
                            
                            Text("Beauty Filter")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Slider(value: $viewModel.beautyFilterIntensity, in: 0...1)
                            .tint(.pink)
                        
                        HStack {
                            Text("Off")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("Max")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Auto Color Correct
                    Toggle(isOn: $viewModel.autoColorCorrect) {
                        HStack(spacing: 12) {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Color Correct")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Automatically adjust colors")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .tint(.blue)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Scene Detection
                    AIToolCard(
                        icon: "eye",
                        title: "Scene Detection",
                        description: "AI detects scene & suggests filters",
                        gradient: [.blue, .cyan]
                    ) {
                        Task {
                            if let scene = await viewModel.detectScene() {
                                print("Scene detected: \(scene)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
        )
    }
}

struct AIToolCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
        }
        .buttonStyle(AIToolsScaleButtonStyle())
    }
}

// MARK: - AITools-Specific Button Style

struct AIToolsScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AIToolsPanel(
            viewModel: UltimateStoryViewModel(),
            onDismiss: {}
        )
    }
}

