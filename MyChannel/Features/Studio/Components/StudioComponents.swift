import SwiftUI
import AVKit
import Combine

// MARK: - Supporting Views

// 🔥 PREMIUM: Studio Stat Card with Animated Count-Up
struct StudioStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    @State private var hasAppeared = false
    @State private var changeScale: CGFloat = 0.8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // 🔥 PREMIUM: Animated value with content transition
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .contentTransition(.numericText())
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
            
            // 🔥 PREMIUM: Animated change indicator
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .medium))
                Text(change)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isPositive ? .green : .red)
            .scaleEffect(changeScale)
            .opacity(hasAppeared ? 1 : 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
        .onAppear {
            // 🔥 PREMIUM: Staggered animation on appear
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) {
                changeScale = 1.0
            }
        }
    }
}


// MARK: - Recent Video Card

struct RecentVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.background)
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(video.formattedViewCount) views")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Studio Comment Model & Card

struct StudioComment: Identifiable {
    let id: String
    let username: String
    let userAvatarURL: String
    let text: String
    let videoTitle: String
    let timestamp: Date
    
    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

struct StudioCommentCard: View {
    let comment: StudioComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            AsyncImage(url: URL(string: comment.userAvatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.background)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(comment.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(3)
                
                Text("on \(comment.videoTitle)")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.background)
        .cornerRadius(8)
    }
}

// MARK: - Studio Quick Action Button

struct StudioStudioQuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Complete Views Now in Separate Files
// All views have been moved to MyChannel/Features/Studio/Views/
// - ContentManagementView.swift
// - AdvancedAnalyticsView.swift  
// - EarningsManagementView.swift
// - ChannelCustomizationView.swift
// - CommunityManagementView.swift
// - LiveStreamingStudioView.swift
// - FlicksStudioView.swift
// - PlaylistManagementView.swift
// - CopyrightManagementView.swift
// - StudioSettingsView.swift

