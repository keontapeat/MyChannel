//
//  AppTheme.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - App Theme
struct AppTheme {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "FF6B6B")
        static let secondary = Color(hex: "4ECDC4")
        static let accent = Color(hex: "45B7D1")
        static let background = Color(hex: "FFFFFF")
        static let surface = Color(hex: "F8F9FA")
        static let cardBackground = Color(hex: "FFFFFF")
        static let textPrimary = Color(hex: "1A1A1A")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")
        static let divider = Color(hex: "E5E7EB")
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")
        // ADD: secondary background for chips, tags, elevated containers
        static let backgroundSecondary = Color(hex: "F2F3F5")
        static let gradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let bodySemibold = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
    
    // MARK: - Modern Animations
    struct AnimationPresets {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let easeInOut = Animation.easeInOut(duration: 0.3)
        static let bouncy = Animation.spring(response: 0.6, dampingFraction: 0.6)
        static let gentle = Animation.easeInOut(duration: 0.5)
        static let quick = Animation.easeInOut(duration: 0.2)
    }
    
    // MARK: - Modern Effects
    struct ModernEffects {
        static let glassmorphism = Material.ultraThinMaterial
        static let cardShadow = Shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        static let buttonShadow = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        static let floatingShadow = Shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.md)
            .shadow(
                color: AppTheme.Shadows.medium.color,
                radius: AppTheme.Shadows.medium.radius,
                x: AppTheme.Shadows.medium.x,
                y: AppTheme.Shadows.medium.y
            )
    }
    
    func primaryButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.gradient)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.md)
            .font(AppTheme.Typography.bodyMedium)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .cornerRadius(AppTheme.CornerRadius.md)
            .font(AppTheme.Typography.bodyMedium)
    }
    
    func modernCardStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            .shadow(
                color: AppTheme.ModernEffects.cardShadow.color,
                radius: AppTheme.ModernEffects.cardShadow.radius,
                x: AppTheme.ModernEffects.cardShadow.x,
                y: AppTheme.ModernEffects.cardShadow.y
            )
    }
    
    func modernButtonStyle() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.gradient)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .font(AppTheme.Typography.bodyMedium)
            .shadow(
                color: AppTheme.ModernEffects.buttonShadow.color,
                radius: AppTheme.ModernEffects.buttonShadow.radius,
                x: AppTheme.ModernEffects.buttonShadow.x,
                y: AppTheme.ModernEffects.buttonShadow.y
            )
    }
    
    func floatingStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl))
            .shadow(
                color: AppTheme.ModernEffects.floatingShadow.color,
                radius: AppTheme.ModernEffects.floatingShadow.radius,
                x: AppTheme.ModernEffects.floatingShadow.x,
                y: AppTheme.ModernEffects.floatingShadow.y
            )
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