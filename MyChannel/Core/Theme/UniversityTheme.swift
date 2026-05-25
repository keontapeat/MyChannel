//
//  UniversityTheme.swift
//  MyChannel
//
//  Modern Academic Design System for MyChannel University
//  Professional, sleek, clean - Harvard/Stanford aesthetic
//

import SwiftUI

/// 🎓 UNIVERSITY THEME: Clean Adaptive Design System
/// Neutral system colors — serious, professional, dark/light adaptive
struct UniversityTheme {
    
    // MARK: - Colors
    
    /// Neutral adaptive palette — no color blobs, system-adaptive
    struct Colors {
        // Primary Accent — YouTube-red, used sparingly for CTAs only
        static let accent = Color(red: 1.0, green: 0.18, blue: 0.18)
        
        // Career Path Colors — kept for progress rings & category icons only (muted)
        static let iosDevelopment = Color(red: 0.0, green: 0.48, blue: 1.0)
        static let webDevelopment = Color(red: 0.18, green: 0.58, blue: 0.35)
        static let dataScience = Color(red: 0.55, green: 0.27, blue: 0.75)
        static let uxDesign = Color(red: 0.88, green: 0.38, blue: 0.28)
        static let digitalMarketing = Color(red: 0.2, green: 0.65, blue: 0.88)
        static let businessAnalytics = Color(red: 0.65, green: 0.48, blue: 0.18)
        static let projectManagement = Color(red: 0.45, green: 0.58, blue: 0.25)
        static let graphicDesign = Color(red: 0.75, green: 0.28, blue: 0.55)
        
        // Semantic — minimal, purposeful
        static let certificateGold = Color(red: 0.85, green: 0.65, blue: 0.13)
        static let verified = Color(red: 0.2, green: 0.7, blue: 0.3)
        
        // Adaptive neutrals — use these everywhere instead of fixed colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        
        // Adaptive backgrounds
        static let backgroundPrimary = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let surface = Color(.systemBackground)
        static let cardSurface = Color(.secondarySystemBackground)
        
        // UI Elements
        static let divider = Color(.separator)
        static let shadow = Color.black.opacity(0.06)
        
        /// Get career path color by ID
        static func careerPathColor(for id: String) -> Color {
            switch id {
            case "ios-development": return iosDevelopment
            case "web-development": return webDevelopment
            case "data-science": return dataScience
            case "ux-design": return uxDesign
            case "digital-marketing": return digitalMarketing
            case "business-analytics": return businessAnalytics
            case "project-management": return projectManagement
            case "graphic-design": return graphicDesign
            default: return accent
            }
        }
    }
    
    // MARK: - Typography
    
    /// Academic typography - clean, readable, professional
    struct Typography {
        // Headings
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // Body Text
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let callout = Font.system(size: 15, weight: .regular, design: .rounded)
        
        // Small Text
        static let subheadline = Font.system(size: 14, weight: .medium, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption1 = Font.system(size: 12, weight: .medium, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .rounded)
        
        // Special
        static let statNumber = Font.system(size: 36, weight: .bold, design: .rounded)  // Big numbers
        static let heroTitle = Font.system(size: 48, weight: .bold, design: .rounded)   // Hero sections
    }
    
    // MARK: - Spacing
    
    /// Consistent spacing system
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        
        // Padding presets
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let rowSpacing: CGFloat = 16
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let circle: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        static let card = ShadowConfig(
            color: Colors.shadow,
            radius: 12,
            x: 0,
            y: 4
        )
        
        static let floating = ShadowConfig(
            color: Colors.shadow,
            radius: 20,
            x: 0,
            y: 8
        )
        
        static let hero = ShadowConfig(
            color: Color.black.opacity(0.15),
            radius: 24,
            x: 0,
            y: 12
        )
    }
    
    struct ShadowConfig {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Animations
    
    struct Animation {
        /// Spring animation for interactive elements
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        
        /// Smooth animation for state changes
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        
        /// Quick animation for hover effects
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        
        /// Gentle animation for progress indicators
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
    }
    
    // MARK: - Icon Sizes
    
    struct IconSize {
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let hero: CGFloat = 48
    }
}

// MARK: - View Modifiers

/// Apply university card style
struct UniversityCardModifier: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .padding(UniversityTheme.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: UniversityTheme.CornerRadius.md)
                    .fill(UniversityTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: UniversityTheme.CornerRadius.md)
                            .stroke(color.opacity(0.15), lineWidth: 1.5)
                    )
            )
            .shadow(
                color: UniversityTheme.Shadow.card.color,
                radius: UniversityTheme.Shadow.card.radius,
                x: UniversityTheme.Shadow.card.x,
                y: UniversityTheme.Shadow.card.y
            )
    }
}

/// Apply university button style
struct UniversityButtonModifier: ViewModifier {
    let color: Color
    let isSecondary: Bool
    
    func body(content: Content) -> some View {
        content
            .font(UniversityTheme.Typography.bodyBold)
            .foregroundColor(isSecondary ? color : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: UniversityTheme.CornerRadius.sm)
                    .fill(isSecondary ? color.opacity(0.1) : color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UniversityTheme.CornerRadius.sm)
                    .stroke(isSecondary ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
    }
}

/// Apply university hero background — clean adaptive surface
struct UniversityHeroGradientModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply university card style
    func universityCard(color: Color = UniversityTheme.Colors.accent) -> some View {
        modifier(UniversityCardModifier(color: color))
    }
    
    /// Apply university button style
    func universityButton(color: Color = UniversityTheme.Colors.accent, isSecondary: Bool = false) -> some View {
        modifier(UniversityButtonModifier(color: color, isSecondary: isSecondary))
    }
    
    /// Apply university hero gradient
    func universityHeroGradient() -> some View {
        modifier(UniversityHeroGradientModifier())
    }
}

// MARK: - Progress Ring Colors

extension UniversityTheme {
    /// Get progress ring colors based on percentage
    static func progressRingColors(for percentage: Double) -> (start: Color, end: Color) {
        switch percentage {
        case 0..<25:
            return (Color(.systemOrange).opacity(0.7), Color(.systemOrange))
        case 25..<50:
            return (Colors.verified.opacity(0.7), Colors.verified)
        case 50..<75:
            return (Color(.systemBlue).opacity(0.7), Color(.systemBlue))
        case 75..<100:
            return (Colors.certificateGold.opacity(0.7), Colors.certificateGold)
        default:
            return (Colors.certificateGold, Colors.certificateGold.opacity(0.7))
        }
    }
}

// MARK: - Difficulty Level Colors

extension UniversityTheme {
    /// Get color for difficulty level
    static func difficultyColor(_ level: UniversityVideo.DifficultyLevel) -> Color {
        switch level {
        case .beginner:
            return Colors.verified
        case .intermediate:
            return Color(.systemBlue)
        case .advanced:
            return Color(.systemOrange)
        case .expert:
            return Colors.certificateGold
        }
    }
}






