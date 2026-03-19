//
//  ProfileQuickActionsChips.swift
//  MyChannel
//
//  Extracted from ProfileView.swift for better maintainability
//

import SwiftUI

// MARK: - Quick Actions Chips (Switch account / Google Account / Incognito)

struct ProfileQuickActionsChips: View {
    let isIncognito: Bool
    let switchAccountAction: () -> Void
    let googleAccountAction: () -> Void
    let toggleIncognitoAction: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ActionChip(
                    title: "Switch account",
                    systemImage: "person.crop.circle.fill",
                    action: switchAccountAction
                )

                ActionChip(
                    title: "Google Account",
                    systemImage: "g.circle.fill",
                    action: googleAccountAction
                )

                ActionChip(
                    title: isIncognito ? "Incognito On" : "Incognito",
                    systemImage: isIncognito ? "eye.slash.circle.fill" : "eye.slash.circle",
                    isHighlighted: isIncognito,
                    action: toggleIncognitoAction
                )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: AppTheme.Colors.background.opacity(0), location: 0.0),
                    .init(color: AppTheme.Colors.background, location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 20)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Action Chip Component

struct ActionChip: View {
    let title: String
    let systemImage: String
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHighlighted ? Color.white : AppTheme.Colors.textPrimary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHighlighted ? Color.white : AppTheme.Colors.textPrimary)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background {
                Capsule()
                    .fill(isHighlighted
                        ? AppTheme.Colors.primary
                        : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isHighlighted ? Color.clear : Color(.systemGray4),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isHighlighted)
    }
}

// MARK: - Previews

#Preview("Quick Actions Chips") {
    ProfileQuickActionsChips(
        isIncognito: false,
        switchAccountAction: {},
        googleAccountAction: {},
        toggleIncognitoAction: {}
    )
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Quick Actions Chips - Incognito On") {
    ProfileQuickActionsChips(
        isIncognito: true,
        switchAccountAction: {},
        googleAccountAction: {},
        toggleIncognitoAction: {}
    )
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Action Chip") {
    HStack {
        ActionChip(title: "Normal", systemImage: "star", action: {})
        ActionChip(title: "Highlighted", systemImage: "star.fill", isHighlighted: true, action: {})
    }
    .padding()
    .background(AppTheme.Colors.background)
}







