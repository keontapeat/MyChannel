//
//  AppTheme.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UIKit

// MARK: - App Theme
struct AppTheme {
    
    // MARK: - Premium Colors (Adaptive Light/Dark — YouTube-parity)
    struct Colors {
        // Primary brand - refined coral with depth (same in both modes)
        static let primary = Color(hexString: "E85D5D")
        static let primaryLight = Color(hexString: "FF8A8A")
        static let primaryDark = Color(hexString: "C94444")
        
        // Secondary - sophisticated teal
        static let secondary = Color(hexString: "3BB8AB")
        static let secondaryLight = Color(hexString: "5CD6C9")
        
        // Accent - premium blue with luminosity
        static let accent = Color(hexString: "3D9FE0")
        static let accentGlow = Color(hexString: "3D9FE0").opacity(0.4)
        
        // MARK: Adaptive Backgrounds (light → dark)
        // background: #FAFBFC (light) / #0A0A0C OLED-black (dark)
        static let background = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1) // #0A0A0C
                : UIColor(red: 0.980, green: 0.984, blue: 0.988, alpha: 1) // #FAFBFC
        }))
        // Legacy alias kept for any call-sites that used backgroundDark directly
        static let backgroundDark = Color(hexString: "0A0A0C")

        // surface: #F4F5F7 (light) / #161618 (dark)
        static let surface = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1) // #161618
                : UIColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1) // #F4F5F7
        }))
        static let surfaceDark = Color(hexString: "161618")

        // cardBackground: #FFFFFF (light) / #1C1C1E (dark)
        static let cardBackground = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // #1C1C1E
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1) // #FFFFFF
        }))
        static let cardBackgroundDark = Color(hexString: "1C1C1E")

        // backgroundSecondary: #EBEDF0 (light) / #1C1C1E (dark)
        static let backgroundSecondary = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // #1C1C1E
                : UIColor(red: 0.922, green: 0.929, blue: 0.941, alpha: 1) // #EBEDF0
        }))

        // backgroundTertiary: #E4E6E9 (light) / #2C2C2E (dark)
        static let backgroundTertiary = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1) // #2C2C2E
                : UIColor(red: 0.894, green: 0.902, blue: 0.914, alpha: 1) // #E4E6E9
        }))
        
        // elevated: #FFFFFF (light) / #2C2C2E (dark)
        static let elevated = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1) // #2C2C2E
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1) // #FFFFFF
        }))
        static let elevatedDark = Color(hexString: "2C2C2E")

        // MARK: Adaptive Text
        // textPrimary: #0F1419 (light) / #F5F5F7 (dark)
        static let textPrimary = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1) // #F5F5F7
                : UIColor(red: 0.059, green: 0.078, blue: 0.098, alpha: 1) // #0F1419
        }))
        static let textPrimaryDark = Color(hexString: "F5F5F7")

        // textSecondary: #536471 (light) / #8E8E93 (dark)
        static let textSecondary = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1) // #8E8E93
                : UIColor(red: 0.325, green: 0.392, blue: 0.443, alpha: 1) // #536471
        }))
        static let textSecondaryDark = Color(hexString: "8E8E93")

        // textTertiary: #8899A6 (light) / #636366 (dark)
        static let textTertiary = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.388, green: 0.388, blue: 0.400, alpha: 1) // #636366
                : UIColor(red: 0.533, green: 0.600, blue: 0.651, alpha: 1) // #8899A6
        }))
        static let textTertiaryDark = Color(hexString: "636366")

        static let textMuted = Color(hexString: "B0BEC5")
        
        // MARK: Adaptive Divider
        // divider: #EFF3F4 (light) / #2F2F31 (dark)
        static let divider = Color(uiColor: UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.184, green: 0.184, blue: 0.192, alpha: 1) // #2F2F31
                : UIColor(red: 0.937, green: 0.953, blue: 0.957, alpha: 1) // #EFF3F4
        }))
        static let dividerDark = Color(hexString: "2F2F31")
        
        // MARK: Status colors - same in both modes
        static let success = Color(hexString: "00BA7C")
        static let successLight = Color(hexString: "00BA7C").opacity(0.15)
        static let warning = Color(hexString: "FFB800")
        static let warningLight = Color(hexString: "FFB800").opacity(0.15)
        static let error = Color(hexString: "F4212E")
        static let errorLight = Color(hexString: "F4212E").opacity(0.15)
        
        // Verification & special
        static let verificationBlue = Color(hexString: "1D9BF0")
        static let premium = Color(hexString: "FFD700")
        static let live = Color(hexString: "FF0000")
        
        // Premium gradients
        static let gradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let premiumGradient = LinearGradient(
            colors: [Color(hexString: "E85D5D"), Color(hexString: "FF8A5B")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let subtleGradient = LinearGradient(
            colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let darkGradient = LinearGradient(
            colors: [Color(hexString: "1C1C1E"), Color(hexString: "0A0A0C")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Glass effect backgrounds
        static let glassLight = Color.white.opacity(0.7)
        static let glassDark = Color.black.opacity(0.5)
    }
    
    // MARK: - Premium Typography
    struct Typography {
        // Display - for hero sections
        static let displayLarge = Font.system(size: 44, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)
        
        // Standard hierarchy
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .medium, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let bodySemibold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let calloutMedium = Font.system(size: 16, weight: .medium, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let footnoteMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Mono for numbers/stats
        static let monoLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
        static let monoMedium = Font.system(size: 16, weight: .semibold, design: .monospaced)
        static let monoSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Spacing System
    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let smd: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 100  // For pill-shaped buttons
        static let circle: CGFloat = 9999
    }
    
    // MARK: - Premium Shadows (Multi-layered for depth)
    struct Shadows {
        // Subtle - for cards at rest
        static let subtle = Shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        
        // Small - for elevated elements
        static let small = Shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        
        // Medium - for interactive elements
        static let medium = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        
        // Large - for modals and overlays
        static let large = Shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        
        // XL - for floating elements
        static let xl = Shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 12)
        
        // Colored shadows for premium feel
        static let primaryGlow = Shadow(color: Colors.primary.opacity(0.25), radius: 16, x: 0, y: 4)
        static let accentGlow = Shadow(color: Colors.accent.opacity(0.25), radius: 16, x: 0, y: 4)
        
        // Inner shadow simulation
        static let inset = Shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Premium Animations
    struct AnimationPresets {
        // Micro-interactions (< 200ms)
        static let micro = Animation.spring(response: 0.2, dampingFraction: 0.9)
        static let quick = Animation.easeOut(duration: 0.15)
        
        // Standard interactions (200-400ms)
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let easeInOut = Animation.easeInOut(duration: 0.3)
        
        // Emphasized (for attention)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let elastic = Animation.spring(response: 0.6, dampingFraction: 0.5)
        
        // Slow & luxurious (for reveals)
        static let gentle = Animation.easeInOut(duration: 0.5)
        static let cinematic = Animation.easeInOut(duration: 0.7)
        static let reveal = Animation.spring(response: 0.8, dampingFraction: 0.8)
        
        // Interactive (for dragging)
        static let interactive = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8)
    }
    
    // MARK: - Modern Effects
    struct ModernEffects {
        static let glassmorphism = Material.ultraThinMaterial
        static let regularGlass = Material.regularMaterial
        static let thickGlass = Material.thickMaterial
        
        // Premium card shadow (multi-layered)
        static let cardShadow = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let cardShadowHover = Shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        
        // Button effects
        static let buttonShadow = Shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        static let buttonShadowPressed = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        
        // Floating elements
        static let floatingShadow = Shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
        
        // Glow effects
        static let primaryGlow = Shadow(color: Colors.primary.opacity(0.4), radius: 20, x: 0, y: 0)
        static let accentGlow = Shadow(color: Colors.accent.opacity(0.3), radius: 16, x: 0, y: 0)
    }
    
    // MARK: - Touch Targets
    struct TouchTargets {
        static let minimum: CGFloat = 44
        static let comfortable: CGFloat = 48
        static let large: CGFloat = 56
    }
    
    // MARK: - Z-Index Layers
    struct ZIndex {
        static let background: Double = 0
        static let content: Double = 1
        static let elevated: Double = 10
        static let overlay: Double = 100
        static let modal: Double = 1000
        static let toast: Double = 9999
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Premium View Extensions
extension View {
    
    // MARK: - Card Styles
    
    /// Standard card with subtle elevation
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous))
            .shadow(
                color: AppTheme.Shadows.subtle.color,
                radius: AppTheme.Shadows.subtle.radius,
                x: AppTheme.Shadows.subtle.x,
                y: AppTheme.Shadows.subtle.y
            )
            .shadow(
                color: AppTheme.Shadows.medium.color,
                radius: AppTheme.Shadows.medium.radius,
                x: AppTheme.Shadows.medium.x,
                y: AppTheme.Shadows.medium.y
            )
    }
    
    /// Premium card with multi-layered shadow and smooth corners
    func premiumCardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
    
    /// Glassmorphism card for floating elements
    func glassCardStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
    }
    
    /// Modern card with glass effect
    func modernCardStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
            .shadow(
                color: AppTheme.ModernEffects.cardShadow.color,
                radius: AppTheme.ModernEffects.cardShadow.radius,
                x: AppTheme.ModernEffects.cardShadow.x,
                y: AppTheme.ModernEffects.cardShadow.y
            )
    }
    
    // MARK: - Button Styles
    
    /// Primary button with gradient and glow
    func primaryButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(AppTheme.Colors.premiumGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous))
            .font(AppTheme.Typography.bodyMedium)
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    /// Secondary button with subtle background
    func secondaryButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(AppTheme.Colors.backgroundSecondary)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous))
            .font(AppTheme.Typography.bodyMedium)
    }
    
    /// Ghost button (outline only)
    func ghostButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(Color.clear)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1.5)
            )
            .font(AppTheme.Typography.bodyMedium)
    }
    
    /// Modern button with shadow
    func modernButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(AppTheme.Colors.premiumGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
            .font(AppTheme.Typography.bodyMedium)
            .shadow(
                color: AppTheme.ModernEffects.buttonShadow.color,
                radius: AppTheme.ModernEffects.buttonShadow.radius,
                x: AppTheme.ModernEffects.buttonShadow.x,
                y: AppTheme.ModernEffects.buttonShadow.y
            )
    }
    
    /// Pill-shaped button
    func pillButtonStyle(filled: Bool = true) -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(filled ? AppTheme.Colors.textPrimary : Color.clear)
            .foregroundColor(filled ? AppTheme.Colors.background : AppTheme.Colors.textPrimary)
            .clipShape(Capsule())
            .font(AppTheme.Typography.footnoteMedium)
            .overlay(
                Capsule()
                    .stroke(filled ? Color.clear : AppTheme.Colors.divider, lineWidth: 1)
            )
    }
    
    // MARK: - Floating & Elevated Styles
    
    /// Floating element style
    func floatingStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl, style: .continuous))
            .shadow(
                color: AppTheme.ModernEffects.floatingShadow.color,
                radius: AppTheme.ModernEffects.floatingShadow.radius,
                x: AppTheme.ModernEffects.floatingShadow.x,
                y: AppTheme.ModernEffects.floatingShadow.y
            )
    }
    
    /// Elevated surface style
    func elevatedStyle() -> some View {
        self
            .background(AppTheme.Colors.elevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Chip & Tag Styles
    
    /// Chip style for tags and filters
    func chipStyle(isSelected: Bool = false) -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.smd)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.backgroundSecondary)
            .foregroundColor(isSelected ? AppTheme.Colors.background : AppTheme.Colors.textPrimary)
            .clipShape(Capsule())
            .font(AppTheme.Typography.footnoteMedium)
    }
    
    // MARK: - Input Styles
    
    /// Text field style
    func textFieldStyle() -> some View {
        self
            .padding(AppTheme.Spacing.smd)
            .background(AppTheme.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous))
            .font(AppTheme.Typography.body)
    }
    
    // MARK: - Shadow Helpers
    
    /// Apply shadow from Shadow struct
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    /// Multi-layered shadow for premium depth
    func premiumShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
    
    /// Glow effect for highlighted elements
    func glowEffect(color: Color = AppTheme.Colors.primary, radius: CGFloat = 16) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }
    
    // MARK: - Animation Helpers
    
    /// Smooth fade-in animation
    func fadeIn(delay: Double = 0) -> some View {
        self
            .opacity(1)
            .animation(AppTheme.AnimationPresets.gentle.delay(delay), value: true)
    }
    
    /// Staggered animation helper
    func staggerAnimation(index: Int, baseDelay: Double = 0.05) -> some View {
        self
            .animation(AppTheme.AnimationPresets.spring.delay(Double(index) * baseDelay), value: true)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("MyChannel Theme")
            .font(AppTheme.Typography.largeTitle)
            .foregroundColor(AppTheme.Colors.textPrimary)
        
        HStack(spacing: 16) {
            Button("Primary") { }
                .primaryButtonStyle()
            
            Button("Secondary") { }
                .secondaryButtonStyle()
        }
        
        VStack(spacing: 12) {
            Text("Card Example")
                .font(AppTheme.Typography.headline)
            Text("This is a card with our theme applied")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .cardStyle()
        .padding()
    }
    .padding()
    .background(AppTheme.Colors.background)
}