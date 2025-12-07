//
//  YouTubeStyleFeatureCard.swift
//  MyChannel
//
//  Reusable YouTube-style feature card component
//

import SwiftUI

// MARK: - YouTube-Style Feature Card Component

struct YouTubeStyleFeatureCard<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: Destination
    var isAdmin: Bool = false
    var badgeText: String? = nil
    var badgeColor: Color = .red
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon (YouTube-style: neutral background, subtle)
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isAdmin {
                            Text("ADMIN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red, in: Capsule())
                        }
                        
                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor, in: Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron (YouTube-style: subtle)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - YouTube-Style Feature Card (Action Version)

struct YouTubeStyleFeatureCardAction: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var isAdmin: Bool = false
    var badgeText: String? = nil
    var badgeColor: Color = .red
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isAdmin {
                            Text("ADMIN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red, in: Capsule())
                        }
                        
                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor, in: Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview("YouTube Feature Card") {
    NavigationStack {
        VStack(spacing: 12) {
            YouTubeStyleFeatureCard(
                icon: "graduationcap.fill",
                title: "MyChannel University",
                subtitle: "Learn & earn certificates",
                destination: Text("University")
            )
            
            YouTubeStyleFeatureCard(
                icon: "gamecontroller.fill",
                title: "Gaming & Esports",
                subtitle: "Tournaments & competitions",
                destination: Text("Gaming"),
                badgeText: "NEW",
                badgeColor: .green
            )
            
            YouTubeStyleFeatureCard(
                icon: "brain.head.profile",
                title: "AGI Agent Dashboard",
                subtitle: "Manage all 30 AI agents",
                destination: Text("AGI"),
                isAdmin: true
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}

#Preview("YouTube Feature Card Action") {
    VStack(spacing: 12) {
        YouTubeStyleFeatureCardAction(
            icon: "arrow.down.circle.fill",
            title: "Downloads",
            subtitle: "Watch videos offline",
            action: { print("Downloads tapped") }
        )
        
        YouTubeStyleFeatureCardAction(
            icon: "plus.circle",
            title: "MyChannel Plus+",
            subtitle: "Try 7 days free",
            action: { print("Plus tapped") },
            badgeText: "FREE TRIAL",
            badgeColor: .black
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
}







