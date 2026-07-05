//
//  CreatorProfileSheet.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI

struct CreatorProfileSheet: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var isSubscribed = false
    @State private var showingFullProfile = false
    @State private var creatorVideos: [Video] = []
    @State private var isLoadingVideos = false
    @State private var subscribeScale: CGFloat = 1.0
    @State private var headerOffset: CGFloat = 0
    @State private var shareItems: [Any]?
    
    private let bannerHeight: CGFloat = 140
    private let avatarSize: CGFloat = 88
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Banner + Avatar Header
                    ZStack(alignment: .bottom) {
                        // Banner
                        bannerSection
                        
                        // Avatar overlapping banner bottom
                        avatarView
                            .offset(y: avatarSize / 2)
                    }
                    .padding(.bottom, avatarSize / 2 + 8)
                    
                    // MARK: - Creator Identity
                    creatorIdentitySection
                        .padding(.top, 4)
                    
                    // MARK: - Inline Stats
                    inlineStatsRow
                        .padding(.top, 12)
                    
                    // MARK: - Bio
                    if let bio = creator.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }
                    
                    // MARK: - Action Buttons
                    actionButtonsRow
                        .padding(.top, 20)
                    
                    // MARK: - Divider
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .frame(height: 1)
                        .padding(.top, 20)
                    
                    // MARK: - Videos Section
                    videosSection
                        .padding(.top, 16)
                    
                    Spacer(minLength: 60)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.surface.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(creator.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingFullProfile = true }) {
                            Label("View Full Channel", systemImage: "person.crop.rectangle")
                        }
                        Button {
                            let handle = creator.username.isEmpty ? creator.id : creator.username
                            if let url = URL(string: "https://mychannel.live/channel/\(handle)") {
                                shareItems = ["\(creator.displayName) on MyChannel", url]
                            }
                        } label: {
                            Label("Share Channel", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.surface.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onAppear {
            isSubscribed = appState.isSubscribedTo(creator.id)
            loadCreatorVideos()
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            if let items = shareItems {
                NativeShareSheet(items: items)
            }
        }
        .fullScreenCover(isPresented: $showingFullProfile) {
            if creator.id == authManager.currentUser?.id {
                ProfileView()
                    .environmentObject(authManager)
                    .environmentObject(appState)
            } else {
                PublicProfileView(user: creator)
                    .environmentObject(authManager)
                    .environmentObject(appState)
            }
        }
    }
    
    // MARK: - Banner
    private var bannerSection: some View {
        ZStack {
            if let bannerURL = creator.bannerImageURL, !bannerURL.isEmpty {
                AsyncImage(url: URL(string: bannerURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    bannerGradientFallback
                }
            } else {
                bannerGradientFallback
            }
        }
        .frame(height: bannerHeight)
        .clipped()
        .overlay(
            LinearGradient(
                colors: [.clear, AppTheme.Colors.background.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var bannerGradientFallback: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.primary.opacity(0.7),
                AppTheme.Colors.primary.opacity(0.3),
                AppTheme.Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle pattern
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - Avatar
    private var avatarView: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(AppTheme.Colors.background)
                .frame(width: avatarSize + 8, height: avatarSize + 8)
            
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.surface, AppTheme.Colors.surface.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        }
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Creator Identity
    private var creatorIdentitySection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(creator.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if creator.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.system(size: 16))
                }
            }
            
            Text("@\(creator.username)")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Inline Stats (YouTube style: "2 videos · 0 subscribers · 4 views")
    private var inlineStatsRow: some View {
        HStack(spacing: 6) {
            statPill(value: formatCount(creator.subscriberCount), label: "subscribers")
            
            Circle()
                .fill(AppTheme.Colors.textSecondary.opacity(0.5))
                .frame(width: 3, height: 3)
            
            statPill(value: formatCount(creator.videoCount), label: "videos")
            
            Circle()
                .fill(AppTheme.Colors.textSecondary.opacity(0.5))
                .frame(width: 3, height: 3)
            
            statPill(value: formatCount(creator.totalViews ?? 0), label: "views")
        }
    }
    
    private func statPill(value: String, label: String) -> some View {
        Text("\(value) \(label)")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
    }
    
    // MARK: - Action Buttons
    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            // Subscribe / Subscribed
            Button(action: toggleSubscription) {
                HStack(spacing: 6) {
                    Image(systemName: isSubscribed ? "bell.fill" : "person.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isSubscribed ? "Subscribed" : "Subscribe")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(isSubscribed ? AppTheme.Colors.textPrimary : .white)
                .frame(height: 40)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSubscribed ? AppTheme.Colors.textSecondary.opacity(0.2) : .clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(subscribeScale)
            
            // Join / Membership
            Button(action: { showingFullProfile = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("View Channel")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(height: 40)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.surface)
                )
            }
            .buttonStyle(.plain)
            
            // Notification bell
            if isSubscribed {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                }) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.surface)
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSubscribed)
    }
    
    // MARK: - Videos Section
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(alignment: .center) {
                Text("Videos")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if !creatorVideos.isEmpty {
                    Text("\(creatorVideos.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                if !creatorVideos.isEmpty {
                    Button(action: { showingFullProfile = true }) {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Video Content
            if isLoadingVideos {
                videoSkeletons
            } else if creatorVideos.isEmpty {
                emptyVideosState
            } else {
                videoGrid
            }
        }
    }
    
    // MARK: - Video Grid (2-up layout)
    private var videoGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 16
        ) {
            ForEach(creatorVideos.prefix(6)) { video in
                CompactVideoCard(video: video)
                    .onTapGesture {
                        GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true, queue: creatorVideos)
                        dismiss()
                    }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Skeleton Loaders
    private var videoSkeletons: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 16
        ) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.surface)
                        .aspectRatio(16/9, contentMode: .fit)
                        .shimmer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.surface)
                            .frame(height: 12)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 80, height: 10)
                            .shimmer()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty State
    private var emptyVideosState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
            
            Text("No videos yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("When \(creator.displayName) uploads videos, they'll appear here.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    
    private func loadCreatorVideos() {
        isLoadingVideos = true
        
        Task {
            do {
                let videos = try await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: creator.id)
                
                await MainActor.run {
                    self.creatorVideos = videos
                    self.isLoadingVideos = false
                }
            } catch {
                await MainActor.run {
                    self.creatorVideos = []
                    self.isLoadingVideos = false
                    print("❌ Failed to load creator videos: \(error)")
                }
            }
        }
    }
    
    private func toggleSubscription() {
        HapticManager.shared.impact(style: .medium)
        
        // Bounce animation
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            subscribeScale = 0.9
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                subscribeScale = 1.0
                isSubscribed.toggle()
            }
        }
        
        appState.toggleSubscription(for: creator.id)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Supporting Views

struct CreatorStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

struct CompactVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with duration badge
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Duration badge
                if video.duration > 0 {
                    Text(formatDuration(video.duration))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.8))
                        )
                        .padding(6)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            
            // Video Info
            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(formatCount(video.viewCount) + " views")
                    
                    Text("·")
                    
                    Text(timeAgo(video.createdAt))
                }
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let seconds = Int(interval)
        
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }
        if seconds < 2592000 { return "\(seconds / 604800)w ago" }
        if seconds < 31536000 { return "\(seconds / 2592000)mo ago" }
        return "\(seconds / 31536000)y ago"
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

#Preview {
    CreatorProfileSheet(creator: User.defaultUser)
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager.shared)
}
