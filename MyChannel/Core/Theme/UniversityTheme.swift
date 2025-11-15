//
//  UniversityTheme.swift
//  MyChannel
//
//  Modern Academic Design System for MyChannel University
//  Professional, sleek, clean - Harvard/Stanford aesthetic
//

import SwiftUI

/// 🎓 UNIVERSITY THEME: Modern Academic Design System
/// Professional colors, typography, and styling for premium educational experience
struct UniversityTheme {
    
    // MARK: - Colors
    
    /// Academic color palette - professional and sophisticated
    struct Colors {
        // Primary Academic Colors
        static let academicBlue = Color(red: 0.15, green: 0.3, blue: 0.85)      // Deep academic blue
        static let scholarPurple = Color(red: 0.25, green: 0.15, blue: 0.65)    // Rich scholar purple
        static let knowledgeNavy = Color(red: 0.1, green: 0.2, blue: 0.5)       // Knowledge navy
        
        // Career Path Colors (Muted & Professional)
        static let iosDevelopment = Color(red: 0.0, green: 0.5, blue: 0.9)      // Tech blue
        static let webDevelopment = Color(red: 0.2, green: 0.6, blue: 0.4)      // Digital green
        static let dataScience = Color(red: 0.6, green: 0.3, blue: 0.8)         // Analytics purple
        static let uxDesign = Color(red: 0.9, green: 0.4, blue: 0.3)            // Creative coral
        static let digitalMarketing = Color(red: 0.3, green: 0.7, blue: 0.9)    // Marketing cyan
        static let businessAnalytics = Color(red: 0.7, green: 0.5, blue: 0.2)   // Business gold
        static let projectManagement = Color(red: 0.5, green: 0.6, blue: 0.3)   // Management olive
        static let graphicDesign = Color(red: 0.8, green: 0.3, blue: 0.6)       // Design magenta
        
        // Semantic Colors
        static let certificateGold = Color(red: 0.85, green: 0.65, blue: 0.13)  // Achievement gold
        static let progressGreen = Color(red: 0.2, green: 0.7, blue: 0.3)       // Progress green
        static let learningOrange = Color(red: 0.9, green: 0.5, blue: 0.2)      // Active learning
        
        // Neutral Academic
        static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.15)        // Deep charcoal
        static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.45)      // Muted gray
        static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.65)       // Light gray
        
        // Backgrounds
        static let backgroundPrimary = Color(red: 0.98, green: 0.98, blue: 0.99) // Clean white
        static let backgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.97) // Soft gray
        static let surface = Color.white
        
        // UI Elements
        static let divider = Color(red: 0.85, green: 0.85, blue: 0.88)
        static let shadow = Color.black.opacity(0.08)
        
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
            default: return academicBlue
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

/// Apply university hero gradient
struct UniversityHeroGradientModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        UniversityTheme.Colors.academicBlue,
                        UniversityTheme.Colors.scholarPurple,
                        UniversityTheme.Colors.knowledgeNavy
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply university card style
    func universityCard(color: Color = UniversityTheme.Colors.academicBlue) -> some View {
        modifier(UniversityCardModifier(color: color))
    }
    
    /// Apply university button style
    func universityButton(color: Color = UniversityTheme.Colors.academicBlue, isSecondary: Bool = false) -> some View {
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
            return (Colors.learningOrange.opacity(0.7), Colors.learningOrange)
        case 25..<50:
            return (Colors.progressGreen.opacity(0.7), Colors.progressGreen)
        case 50..<75:
            return (Colors.academicBlue.opacity(0.7), Colors.academicBlue)
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
            return Colors.progressGreen
        case .intermediate:
            return Colors.academicBlue
        case .advanced:
            return Colors.scholarPurple
        case .expert:
            return Colors.certificateGold
        }
    }
}

