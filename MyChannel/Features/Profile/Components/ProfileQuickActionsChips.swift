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
            HStack(spacing: 12) {
                ActionChip(
                    title: "Switch account",
                    systemImage: "person.crop.circle",
                    action: switchAccountAction
                )

                ActionChip(
                    title: "Google Account",
                    systemImage: "globe",
                    action: googleAccountAction
                )

                ActionChip(
                    title: isIncognito ? "Incognito On" : "Turn on Incognito",
                    systemImage: isIncognito ? "eye.slash.circle.fill" : "eye.slash",
                    isHighlighted: isIncognito,
                    action: toggleIncognitoAction
                )
            }
            .padding(.vertical, 6)
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
            .frame(width: 16)
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(isHighlighted ? Color.white : AppTheme.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(isHighlighted ? AppTheme.Colors.primary : AppTheme.Colors.backgroundSecondary.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isHighlighted ? AppTheme.Colors.primary : AppTheme.Colors.backgroundSecondary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .shadow(color: Color.black.opacity(isHighlighted ? 0.12 : 0.06), radius: 8, x: 0, y: 3)
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







