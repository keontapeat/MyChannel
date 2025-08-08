//
//  View+Notifications.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Notification Names Extension
extension Notification.Name {
    static let scrollToTopProfile = Notification.Name("scrollToTopProfile")
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
    static let videoPlayerStateChanged = Notification.Name("videoPlayerStateChanged")
    static let miniPlayerDismissed = Notification.Name("miniPlayerDismissed")
    static let refreshHomeFeed = Notification.Name("refreshHomeFeed")
}

extension View {
    func modernToast<Content: View>(
        isPresented: Binding<Bool>,
        duration: TimeInterval = 3.0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    VStack {
                        content()
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
        )
    }
    
    func modernAlert<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    
                    content()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
        )
    }
    
    func modernConfetti(trigger: Bool) -> some View {
        self.overlay(
            ConfettiView(trigger: trigger)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Confetti Animation View
struct ConfettiView: View {
    let trigger: Bool
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onChange(of: trigger) { _, newValue in
            if newValue {
                generateConfetti()
            }
        }
    }
    
    private func generateConfetti() {
        particles = []
        
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                id: UUID(),
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -50
                ),
                color: [
                    AppTheme.Colors.primary,
                    AppTheme.Colors.secondary,
                    AppTheme.Colors.accent,
                    .yellow,
                    .green,
                    .blue
                ].randomElement() ?? AppTheme.Colors.primary,
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.6...1.0)
            )
            particles.append(particle)
        }
        
        // Animate particles falling
        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].position.y += CGFloat.random(in: 300...600)
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
        
        // Clear particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            particles = []
        }
    }
}

struct ConfettiParticle {
    let id: UUID
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
}

#Preview {
    VStack {
        Text("Modern Notifications")
            .font(AppTheme.Typography.title1)
            .modernToast(isPresented: .constant(true)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Action completed successfully!")
                        .font(AppTheme.Typography.subheadline)
                }
            }
    }
    .padding()
}