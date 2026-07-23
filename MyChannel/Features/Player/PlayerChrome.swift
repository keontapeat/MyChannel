//
//  PlayerChrome.swift
//  MyChannel
//
//  Centralized design tokens for the video-player overlay chrome.
//
//  WHY THIS EXISTS (and why it is NOT AppTheme.Colors):
//  A video player's controls sit on top of moving video, so they are intentionally
//  a FIXED white-on-black palette regardless of the app's light/dark appearance.
//  AppTheme.Colors.textPrimary / .background are ADAPTIVE — using them here would
//  make the controls invert (white icons would turn dark and disappear on a light
//  UI). This enum gives the player a single, semantic, non-adaptive source of truth
//  so the chrome stays consistent and maintainable — the goal of the theming rule —
//  without breaking the white-on-black requirement.
//
//  Accent color intentionally reuses AppTheme.Colors.primary so brand tint stays in
//  sync with the rest of the app.
//

import SwiftUI

enum PlayerChrome {
    // MARK: - Foreground (fixed white — sits on video)
    /// Primary control foreground (icons, labels).
    static let onSurface: Color = .white
    /// Secondary/de-emphasized foreground.
    static let onSurfaceDim: Color = Color.white.opacity(0.7)
    /// Tertiary foreground (timestamps, hints).
    static let onSurfaceFaint: Color = Color.white.opacity(0.8)

    // MARK: - Scrims / control backgrounds (fixed black)
    /// Circular control-button background and standard chips.
    static let controlBackground: Color = Color.black.opacity(0.7)
    /// Stronger scrim (top/bottom gradients, end screen).
    static let scrimStrong: Color = Color.black.opacity(0.8)
    /// Softer scrim (title pill, subtle backing).
    static let scrimSoft: Color = Color.black.opacity(0.4)
    /// Medium scrim used behind transient overlays.
    static let scrimMedium: Color = Color.black.opacity(0.75)

    // MARK: - Accent (brand — kept in sync with AppTheme)
    static let accent: Color = AppTheme.Colors.primary

    // MARK: - Top / bottom gradients
    static let topGradient = LinearGradient(
        colors: [scrimStrong, .clear],
        startPoint: .top,
        endPoint: .bottom
    )
    static let bottomGradient = LinearGradient(
        colors: [.clear, scrimStrong],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Control button metrics
    /// Diameter of the small circular chrome buttons (chevron, gear, close, cast).
    static let controlButtonSize: CGFloat = 36
}
