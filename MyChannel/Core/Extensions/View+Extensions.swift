//
//  View+Extensions.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

extension View {
    /// Applies a subtle press animation
    func pressAnimation() -> some View {
        self
            .scaleEffect(1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: UUID())
    }
}

// MARK: - Profile Scroll Offset Preference Key
struct ProfileScrollOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Safe View Wrapper
struct SafeViewWrapper<Content: View, Fallback: View>: View {
    let content: () -> Content
    let fallback: () -> Fallback
    
    @State private var hasError = false
    
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.content = content
        self.fallback = fallback
    }
    
    var body: some View {
        Group {
            if hasError {
                fallback()
                    .onAppear {
                        print("⚠️ SafeViewWrapper: Fallback view displayed")
                    }
            } else {
                content()
                    .onAppear {
                        hasError = false
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ViewError"))) { _ in
            hasError = true
        }
    }
}

// MARK: - Profile Retry Button Style
struct ProfileRetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.primary)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Notification Name Extensions - REMOVE DUPLICATE
extension Notification.Name {
    static let updateProfileData = Notification.Name("updateProfileData")
    static let profileSettingsChanged = Notification.Name("profileSettingsChanged")
}