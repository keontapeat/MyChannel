//
//  ProfileQuickMenu.swift
//  MyChannel
//
//  Created by AI Assistant on 11/1/25.
//

import SwiftUI

// MARK: - Profile Quick Menu (Dropdown from Home)
struct ProfileQuickMenu: View {
    let user: User
    @Binding var isPresented: Bool
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 REAL-TIME STATS: Fetch fresh data from analytics
    @State private var realtimeStats: ChannelStats = ChannelStats()
    @State private var isLoadingStats = true
    
    struct ChannelStats {
        var subscribers: Int = 0
        var videos: Int = 0
        var views: Int = 0
        var watchTime: Int = 0 // in minutes
        var engagement: Double = 0 // percentage
        var revenue: Double = 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Avatar & Name
            VStack(spacing: 12) {
                ProfileAvatarView(urlString: user.profileImageURL, size: 64)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Stats Row - REAL DATA
            if isLoadingStats {
                ProgressView()
                    .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    // Top Row - Main Stats
                    HStack(spacing: 0) {
                        StatColumn(
                            value: formatCount(realtimeStats.subscribers),
                            label: "Subscribers",
                            isLive: true
                        )
                        
                        Divider()
                            .frame(height: 50)
                        
                        StatColumn(
                            value: formatCount(realtimeStats.videos),
                            label: "Videos",
                            isLive: true
                        )
                        
                        Divider()
                            .frame(height: 50)
                        
                        StatColumn(
                            value: formatCount(realtimeStats.views),
                            label: "Views",
                            isLive: true
                        )
                    }
                    
                    Divider()
                    
                    // Bottom Row - Performance Metrics
                    HStack(spacing: 0) {
                        StatColumn(
                            value: formatWatchTime(realtimeStats.watchTime),
                            label: "Watch Time",
                            isLive: false
                        )
                        
                        Divider()
                            .frame(height: 40)
                        
                        StatColumn(
                            value: String(format: "%.1f%%", realtimeStats.engagement),
                            label: "Engagement",
                            isLive: false
                        )
                        
                        Divider()
                            .frame(height: 40)
                        
                        StatColumn(
                            value: formatRevenue(realtimeStats.revenue),
                            label: "Revenue",
                            isLive: false
                        )
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(.systemGray6), Color(.systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 0) {
                MenuButton(
                    icon: "chart.bar.doc.horizontal.fill",
                    title: "Creator Studio",
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        isPresented = false
                        NotificationCenter.default.post(
                            name: Notification.Name("OpenCreatorStudioDashboard"),
                            object: user
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "person.circle.fill",
                    title: "View Channel",
                    action: {
                        isPresented = false
                        // Navigate to full profile
                        NotificationCenter.default.post(
                            name: Notification.Name("OpenFullProfile"),
                            object: user
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "gearshape.fill",
                    title: "Settings",
                    action: {
                        isPresented = false
                        NotificationCenter.default.post(
                            name: Notification.Name("OpenSettings"),
                            object: nil
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "person.2.fill",
                    title: "Switch Profile",
                    action: {
                        isPresented = false
                        NotificationCenter.default.post(
                            name: Notification.Name("ShowSwitchProfile"),
                            object: nil
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "arrow.right.square.fill",
                    title: "Sign Out",
                    isDestructive: true,
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        try? authManager.signOut()
                        isPresented = false
                    }
                )
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            // 🔥 LOAD REAL ANALYTICS DATA
            await loadRealtimeStats()
        }
    }
    
    private func loadRealtimeStats() async {
        isLoadingStats = true
        
        // Try to fetch analytics from AdvancedAnalyticsService
        let analytics = AdvancedAnalyticsService.shared
        
        do {
            // Try to get channel analytics
            if let channelAnalytics = try? await analytics.getChannelAnalytics(for: user.id) {
                await MainActor.run {
                    realtimeStats.subscribers = channelAnalytics.totalSubscribers
                    realtimeStats.videos = channelAnalytics.totalVideos
                    realtimeStats.views = channelAnalytics.totalViews
                    realtimeStats.watchTime = Int(channelAnalytics.totalWatchTime / 60) // Convert to minutes
                    // Calculate engagement rate: (watch time / total views) * 100
                    let engagementRate = channelAnalytics.totalViews > 0 
                        ? (channelAnalytics.totalWatchTime / Double(channelAnalytics.totalViews)) * 100 
                        : 0
                    realtimeStats.engagement = min(engagementRate, 100) // Cap at 100%
                    realtimeStats.revenue = channelAnalytics.totalRevenue
                }
            } else {
                // Fallback to user model data
                await MainActor.run {
                    realtimeStats.subscribers = user.subscriberCount
                    realtimeStats.videos = user.videoCount
                    realtimeStats.views = user.totalViews ?? 0
                    realtimeStats.watchTime = 0
                    realtimeStats.engagement = 0
                    realtimeStats.revenue = 0
                }
            }
        } catch {
            // Error fetching analytics, use user model data
            await MainActor.run {
                realtimeStats.subscribers = user.subscriberCount
                realtimeStats.videos = user.videoCount
                realtimeStats.views = user.totalViews ?? 0
                realtimeStats.watchTime = 0
                realtimeStats.engagement = 0
                realtimeStats.revenue = 0
            }
        }
        
        isLoadingStats = false
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
    
    private func formatWatchTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
    
    private func formatRevenue(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}

// MARK: - Stat Column
private struct StatColumn: View {
    let value: String
    let label: String
    var isLive: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if isLive {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: .red, radius: 3)
                }
                
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Button
private struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : AppTheme.Colors.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
                
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileQuickMenu(
        user: User.sampleUsers[0],
        isPresented: .constant(true)
    )
    .environmentObject(AuthenticationManager.shared)
}

