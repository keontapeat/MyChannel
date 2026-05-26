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
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 REAL-TIME STATS: Fetch fresh data from analytics
    @State private var realtimeStats: ChannelStats = ChannelStats()
    @State private var isLoadingStats = true
    @State private var showingSignOutConfirm = false
    
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
            // MARK: - Profile Header
            VStack(spacing: 14) {
                ProfileAvatarView(urlString: user.profileImageURL, size: 72)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // MARK: - Stats Card
            if isLoadingStats {
                ProgressView()
                    .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    // Top Row - Subscribers / Videos / Views
                    HStack(spacing: 0) {
                        ProfileStatCell(
                            value: formatCount(realtimeStats.subscribers),
                            label: "Subscribers"
                        )
                        
                        ProfileStatCell(
                            value: formatCount(realtimeStats.videos),
                            label: "Videos"
                        )
                        
                        ProfileStatCell(
                            value: formatCount(realtimeStats.views),
                            label: "Views"
                        )
                    }
                    .padding(.vertical, 14)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Bottom Row - Watch Time / Engagement / Revenue
                    HStack(spacing: 0) {
                        ProfileStatCell(
                            value: formatWatchTime(realtimeStats.watchTime),
                            label: "Watch Time"
                        )
                        
                        ProfileStatCell(
                            value: String(format: "%.1f%%", realtimeStats.engagement),
                            label: "Engagement"
                        )
                        
                        ProfileStatCell(
                            value: formatRevenue(realtimeStats.revenue),
                            label: "Revenue"
                        )
                    }
                    .padding(.vertical, 14)
                }
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            
            // MARK: - Menu Items
            VStack(spacing: 0) {
                ProfileSheetMenuRow(
                    icon: "doc.text.fill",
                    title: "Creator Studio",
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        isPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            NotificationCenter.default.post(
                                name: Notification.Name("OpenCreatorStudioDashboard"),
                                object: user
                            )
                        }
                    }
                )
                
                ProfileSheetMenuRow(
                    icon: "person.circle.fill",
                    title: "View Channel",
                    action: {
                        isPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            NotificationCenter.default.post(
                                name: Notification.Name("OpenFullProfile"),
                                object: user
                            )
                        }
                    }
                )
                
                ProfileSheetMenuRow(
                    icon: "gearshape.fill",
                    title: "Settings",
                    action: {
                        isPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            NotificationCenter.default.post(
                                name: Notification.Name("OpenSettings"),
                                object: nil
                            )
                        }
                    }
                )
                
                ProfileSheetMenuRow(
                    icon: "person.2.fill",
                    title: "Switch Profile",
                    action: {
                        isPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            NotificationCenter.default.post(
                                name: Notification.Name("ShowSwitchProfile"),
                                object: nil
                            )
                        }
                    }
                )
                
                ProfileSheetMenuRow(
                    icon: "rectangle.portrait.and.arrow.forward.fill",
                    title: "Sign Out",
                    isDestructive: true,
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        showingSignOutConfirm = true
                    }
                )
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                try? authManager.signOut()
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await loadRealtimeStats()
        }
    }
    
    // MARK: - Data Loading
    private func loadRealtimeStats() async {
        isLoadingStats = true
        
        let analytics = AdvancedAnalyticsService.shared
        
        do {
            if let channelAnalytics = try? await analytics.getChannelAnalytics(for: user.id) {
                await MainActor.run {
                    realtimeStats.subscribers = channelAnalytics.totalSubscribers
                    realtimeStats.videos = channelAnalytics.totalVideos
                    realtimeStats.views = channelAnalytics.totalViews
                    realtimeStats.watchTime = Int(channelAnalytics.totalWatchTime / 60)
                    let engagementRate = channelAnalytics.totalViews > 0 
                        ? (channelAnalytics.totalWatchTime / Double(channelAnalytics.totalViews)) * 100 
                        : 0
                    realtimeStats.engagement = min(engagementRate, 100)
                    realtimeStats.revenue = channelAnalytics.totalRevenue
                }
            } else {
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
    
    // MARK: - Formatters
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
        if minutes >= 1440 {
            return "\(minutes / 1440)d"
        } else if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
    
    private func formatRevenue(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}

// MARK: - Profile Stat Cell (matches screenshot: red dot + bold value + label)
private struct ProfileStatCell: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Sheet Menu Row (matches screenshot: icon + title + chevron)
private struct ProfileSheetMenuRow: View {
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
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? .red : .primary.opacity(0.7))
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
                
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
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
    .environmentObject(AppState())
}

