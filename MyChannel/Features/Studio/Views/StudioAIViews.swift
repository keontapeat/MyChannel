// ⚡ PERFORMANCE: Extracted from StudioPlaceholderViews.swift — independent compilation unit.
// AIToolsStudioView, QuickTabs, QuickActionButton compile in parallel.
import SwiftUI

struct AIToolsStudioView: View {
    var body: some View {
        AICoCreatorView()
            .navigationTitle("AI Tools")
    }
}

// MARK: - Mobile Quick Tabs Extension
extension ComprehensiveCreatorStudioView {
    // 🔥 PREMIUM: Mobile Quick Tabs with spring animations
    var mobileQuickTabs: some View {
        HStack(spacing: 0) {
            // Dashboard
            StudioQuickTab(
                icon: "chart.bar",
                filledIcon: "chart.bar.fill",
                title: "Dashboard",
                isSelected: selectedTab == .dashboard
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .dashboard
                }
                HapticManager.shared.impact(style: .light)
            }
            
            // Analytics
            StudioQuickTab(
                icon: "chart.line.uptrend.xyaxis",
                filledIcon: "chart.line.uptrend.xyaxis",
                title: "Analytics",
                isSelected: selectedTab == .analytics
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .analytics
                }
                HapticManager.shared.impact(style: .light)
            }
            
            // Content
            StudioQuickTab(
                icon: "play.rectangle",
                filledIcon: "play.rectangle.fill",
                title: "Content",
                isSelected: selectedTab == .content
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .content
                }
                HapticManager.shared.impact(style: .light)
            }
            
            // Earnings
            StudioQuickTab(
                icon: "dollarsign.circle",
                filledIcon: "dollarsign.circle.fill",
                title: "Earnings",
                isSelected: selectedTab == .earnings
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .earnings
                }
                HapticManager.shared.impact(style: .light)
            }
            
            // More (Menu)
            Menu {
                ForEach([StudioTab.customization, .community, .premieres, .live, .flicks, .playlists, .copyright, .monetization, .settings], id: \.self) { tab in
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                    Text("More")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
        .overlay(
            Rectangle()
                .fill(AppTheme.Colors.divider.opacity(0.3))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// 🔥 PREMIUM: Studio Quick Tab with bounce animation
private struct StudioQuickTab: View {
    let icon: String
    let filledIcon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filledIcon : icon)
                    .font(.system(size: 20, weight: .medium))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - StudioQuickActionButton Component

struct StudioQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ComprehensiveCreatorStudioView()
        .environmentObject(AppState())
}
