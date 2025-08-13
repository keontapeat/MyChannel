//
//  ProfileContentView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Safe Profile Content View
struct SafeProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    
    var body: some View {
        SafeViewWrapper {
            ProfileContentView(
                selectedTab: selectedTab,
                user: user,
                videos: videos
            )
        } fallback: {
            ProfileContentFallback(selectedTab: selectedTab)
        }
    }
}

// MARK: - Profile Content View
struct ProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    
    var body: some View {
        LazyVStack(spacing: 0) {
            switch selectedTab {
            case .videos:
                ProfileVideosView(videos: videos, user: user)
            case .shorts:
                ProfileShortsView(videos: videos, user: user)
            case .playlists:
                ProfilePlaylistsView(user: user)
            case .community:
                ProfileCommunityView(user: user)
            case .about:
                ProfileAboutView(user: user)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}

// MARK: - Profile Videos View
struct ProfileVideosView: View {
    let videos: [Video]
    let user: User
    
    @State private var layoutMode: VideoLayoutMode = .grid2
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Stock Banners Carousel (beautiful defaults)
            StockVideoBannersCarousel(banners: StockVideoBanner.defaults)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // Layout toggle
            HStack {
                Text("Videos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(VideoLayoutMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                layoutMode = mode
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(layoutMode == mode ? .white : AppTheme.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(layoutMode == mode ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Content
            Group {
                if layoutMode == .grid2 {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(videos) { video in
                            ProfileVideoCard(video: video)
                                .onTapGesture {
                                    HapticManager.shared.impact(style: .light)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(videos) { video in
                            ProfileVideoListRow(video: video)
                                .onTapGesture {
                                    HapticManager.shared.impact(style: .light)
                                }
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            
            Color.clear.frame(height: 8)
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Profile Video Card
struct ProfileVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .cornerRadius(8)
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(6),
                alignment: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(video.formattedViewCount)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text(video.uploadTimeAgo)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Save to Watch Later", systemImage: "bookmark")
            }
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Not interested", systemImage: "hand.thumbsdown")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(video.title)
    }
}

// MARK: - Profile Shorts View
struct ProfileShortsView: View {
    let videos: [Video]
    let user: User
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ], spacing: 8) {
            ForEach(videos.prefix(12)) { video in
                ProfileShortCard(video: video)
                    .onTapGesture {
                        HapticManager.shared.impact(style: .light)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Short Card
struct ProfileShortCard: View {
    let video: Video
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                    
                    Text(video.formattedViewCount)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.1), radius: 3, x: 0, y: 1)
        .contextMenu {
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Save to Watch Later", systemImage: "bookmark")
            }
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityLabel("\(video.title) short")
    }
}

// MARK: - Profile Playlists View
struct ProfilePlaylistsView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { index in
                ProfilePlaylistCard(
                    title: "My Playlist \(index + 1)",
                    videoCount: Int.random(in: 5...25),
                    thumbnailURL: "https://picsum.photos/400/300?random=\(index + 10)"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Playlist Card
struct ProfilePlaylistCard: View {
    let title: String
    let videoCount: Int
    let thumbnailURL: String
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(videoCount) videos")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Community View
struct ProfileCommunityView: View {
    let user: User
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5) { index in
                ProfileCommunityPost(
                    author: user,
                    content: "This is a sample community post \(index + 1). Thanks for following my channel!",
                    timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                    likeCount: Int.random(in: 10...500),
                    commentCount: Int.random(in: 2...50)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Community Post
struct ProfileCommunityPost: View {
    let author: User
    let content: String
    let timestamp: Date
    let likeCount: Int
    let commentCount: Int
    
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.7))
                        .overlay(
                            Text(String(author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(author.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text(timeAgoString(from: timestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            
            // Content
            Text(content)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isLiked.toggle()
                    }
                    HapticManager.shared.impact(style: .light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(isLiked ? .red : AppTheme.Colors.textSecondary)
                        
                        Text("\(likeCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        
                        Text("\(commentCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Profile About View
struct ProfileAboutView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 24) {
            // Channel stats
            ProfileStatsSection(user: user)
            
            // Description
            if let bio = user.bio {
                ProfileDescriptionSection(bio: bio)
            }
            
            // Social links
            if !user.socialLinks.isEmpty {
                ProfileSocialLinksSection(socialLinks: user.socialLinks)
            }
            
            // Additional info
            ProfileAdditionalInfoSection(user: user)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Stats Section
struct ProfileStatsSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Channel Statistics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Subscribers",
                    value: "\(user.subscriberCount.formatted())",
                    icon: "person.2.fill",
                    color: AppTheme.Colors.primary
                )
                
                StatCard(
                    title: "Videos",
                    value: "\(user.videoCount)",
                    icon: "play.rectangle.fill",
                    color: AppTheme.Colors.secondary
                )
                
                if let totalViews = user.totalViews {
                    StatCard(
                        title: "Total Views",
                        value: "\(totalViews.formatted())",
                        icon: "eye.fill",
                        color: .green
                    )
                }
                
                StatCard(
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.year().month(.abbreviated)),
                    icon: "calendar.badge.plus",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Profile Description Section
struct ProfileDescriptionSection: View {
    let bio: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(bio)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Social Links Section
struct ProfileSocialLinksSection: View {
    let socialLinks: [SocialLink]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(socialLinks) { link in
                    ProfileSocialLinkCard(link: link)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Additional Info Section
struct ProfileAdditionalInfoSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                if let location = user.location {
                    InfoRow(icon: "location.fill", title: "Location", value: location)
                }
                
                if let website = user.website {
                    InfoRow(icon: "globe", title: "Website", value: website)
                }
                
                InfoRow(
                    icon: "calendar.badge.plus",
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.day().month().year())
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(width: 20, height: 20)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile Social Link Card (renamed to avoid conflict with EditProfileView)
struct ProfileSocialLinkCard: View {
    let link: SocialLink
    
    var body: some View {
        Button(action: {
            // Open link
        }) {
            HStack(spacing: 8) {
                Image(systemName: link.platform.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20, height: 20)
                
                Text(link.platform.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Fallback
struct ProfileContentFallback: View {
    let selectedTab: ProfileTab
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab.iconName)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Content Unavailable")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("Unable to load \(selectedTab.title.lowercased())")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(40)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

private enum VideoLayoutMode: String, CaseIterable {
    case grid2
    case list1
    
    var icon: String {
        switch self {
        case .grid2: return "square.grid.2x2"
        case .list1: return "list.bullet"
        }
    }
    
    var title: String {
        switch self {
        case .grid2: return "Grid"
        case .list1: return "List"
        }
    }
}

private struct StockVideoBannersCarousel: View {
    let banners: [StockVideoBanner]
    @State private var current: Int = 0
    
    var body: some View {
        TabView(selection: $current) {
            ForEach(Array(banners.enumerated()), id: \.offset) { idx, banner in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: banner.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.textTertiary.opacity(0.15))
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(banner.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(banner.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 150)
    }
}

private struct StockVideoBanner: Identifiable {
    let id = UUID()
    let imageURL: String
    let title: String
    let subtitle: String
    
    static let defaults: [StockVideoBanner] = [
        .init(
            imageURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80",
            title: "Travel Vlog",
            subtitle: "Explore the world in 4K"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80",
            title: "Cinematic Nature",
            subtitle: "Relaxing landscapes and skies"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1518770660439-b723cf961d3e?w=1600&q=80",
            title: "Tech Reviews",
            subtitle: "Latest gadgets and gear"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1495195134817-aeb325a55b65?w=1600&q=80",
            title: "Cooking Series",
            subtitle: "Delicious recipes made simple"
        )
    ]
}

private struct ProfileVideoListRow: View {
    let video: Video
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(6),
                alignment: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(video.creator.displayName)
                    Text("•")
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.uploadTimeAgo)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 12) {
                    Label("Like", systemImage: "hand.thumbsup")
                    Label("Share", systemImage: "square.and.arrow.up")
                    Label("Save", systemImage: "bookmark")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.06), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button { HapticManager.shared.impact(style: .light) } label: {
                Label("Save to Watch Later", systemImage: "bookmark")
            }
            Button { HapticManager.shared.impact(style: .light) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { HapticManager.shared.impact(style: .light) } label: {
                Label("Not interested", systemImage: "hand.thumbsdown")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(video.title)
    }
}

#Preview("Profile Videos Layout Toggle") {
    ScrollView {
        ProfileVideosView(
            videos: Array(Video.sampleVideos.prefix(8)),
            user: User.sampleUsers.first ?? .defaultUser
        )
    }
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.light)
}