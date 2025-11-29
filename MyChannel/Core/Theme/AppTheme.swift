//
//  AppTheme.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - App Theme
struct AppTheme {
    
    // MARK: - Premium Colors (Sleeker than YouTube)
    struct Colors {
        // Primary brand - refined coral with depth
        static let primary = Color(hex: "E85D5D") ?? Color.red
        static let primaryLight = Color(hex: "FF8A8A") ?? Color.red.opacity(0.7)
        static let primaryDark = Color(hex: "C94444") ?? Color.red
        
        // Secondary - sophisticated teal
        static let secondary = Color(hex: "3BB8AB") ?? Color.teal
        static let secondaryLight = Color(hex: "5CD6C9") ?? Color.teal.opacity(0.7)
        
        // Accent - premium blue with luminosity
        static let accent = Color(hex: "3D9FE0") ?? Color.blue
        static let accentGlow = Color(hex: "3D9FE0").map { $0.opacity(0.4) } ?? Color.blue.opacity(0.4)
        
        // Backgrounds - refined neutrals with subtle warmth
        static let background = Color(hex: "FAFBFC") ?? Color.white
        static let backgroundDark = Color(hex: "0A0A0C") ?? Color.black  // OLED-optimized
        static let surface = Color(hex: "F4F5F7") ?? Color(white: 0.97)
        static let surfaceDark = Color(hex: "161618") ?? Color(white: 0.08)
        static let cardBackground = Color(hex: "FFFFFF") ?? Color.white
        static let cardBackgroundDark = Color(hex: "1C1C1E") ?? Color(white: 0.11)
        static let backgroundSecondary = Color(hex: "EBEDF0") ?? Color(white: 0.95)
        static let backgroundTertiary = Color(hex: "E4E6E9") ?? Color(white: 0.92)
        
        // Elevated surfaces (for modals, sheets)
        static let elevated = Color(hex: "FFFFFF") ?? Color.white
        static let elevatedDark = Color(hex: "2C2C2E") ?? Color(white: 0.17)
        
        // Text - refined hierarchy with proper contrast
        static let textPrimary = Color(hex: "0F1419") ?? Color.black
        static let textPrimaryDark = Color(hex: "F5F5F7") ?? Color.white
        static let textSecondary = Color(hex: "536471") ?? Color.gray
        static let textSecondaryDark = Color(hex: "8E8E93") ?? Color.gray
        static let textTertiary = Color(hex: "8899A6") ?? Color.gray
        static let textTertiaryDark = Color(hex: "636366") ?? Color.gray
        static let textMuted = Color(hex: "B0BEC5") ?? Color.gray.opacity(0.6)
        
        // Dividers - subtle and refined
        static let divider = Color(hex: "EFF3F4") ?? Color.gray.opacity(0.2)
        static let dividerDark = Color(hex: "2F2F31") ?? Color.white.opacity(0.1)
        
        // Status colors - balanced and professional
        static let success = Color(hex: "00BA7C") ?? Color.green
        static let successLight = Color(hex: "00BA7C").map { $0.opacity(0.15) } ?? Color.green.opacity(0.15)
        static let warning = Color(hex: "FFB800") ?? Color.orange
        static let warningLight = Color(hex: "FFB800").map { $0.opacity(0.15) } ?? Color.orange.opacity(0.15)
        static let error = Color(hex: "F4212E") ?? Color.red
        static let errorLight = Color(hex: "F4212E").map { $0.opacity(0.15) } ?? Color.red.opacity(0.15)
        
        // Verification & special
        static let verificationBlue = Color(hex: "1D9BF0") ?? Color.blue
        static let premium = Color(hex: "FFD700") ?? Color.yellow
        static let live = Color(hex: "FF0000") ?? Color.red
        
        // Premium gradients
        static let gradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let premiumGradient = LinearGradient(
            colors: [Color(hex: "E85D5D") ?? .red, Color(hex: "FF8A5B") ?? .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let subtleGradient = LinearGradient(
            colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let darkGradient = LinearGradient(
            colors: [Color(hex: "1C1C1E") ?? .black, Color(hex: "0A0A0C") ?? .black],
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