//
//  ProfileContentView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    
    var body: some View {
        Group {
            switch selectedTab {
            case .videos:
                ProfileVideosView(videos: videos)
            case .shorts:
                ProfileFlicksView(videos: videos.filter { $0.isShort })
            case .playlists:
                ProfilePlaylistsView(user: user)
            case .community:
                ProfileCommunityView(user: user)
            case .about:
                ProfileAboutView(user: user)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Profile Videos View
struct ProfileVideosView: View {
    let videos: [Video]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        // Back to vertical grid layout (top to bottom scroll)
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(videos) { video in
                ProfileVideoCard(video: video)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

struct ProfileVideoCard: View {
    let video: Video
    @State private var isPressed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                
                // Duration Badge
                Text(video.formattedDuration)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
            
            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text("\(video.formattedViews) views")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(video.timeAgo)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            // Handle video tap
            HapticManager.shared.impact(style: .light)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Profile Flicks View
struct ProfileFlicksView: View {
    let videos: [Video]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(videos) { video in
                ProfileFlickCard(video: video)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

struct ProfileFlickCard: View {
    let video: Video
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(9/16, contentMode: .fill)
                    .overlay(
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
            
            VStack(alignment: .leading) {
                Text(video.title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text("\(video.formattedViews) views")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Profile Shorts View
struct ProfileShortsView: View {
    let videos: [Video]
    
    var body: some View {
        ProfileFlicksView(videos: videos)
    }
}

struct ProfileShortCard: View {
    let video: Video
    
    var body: some View {
        ProfileFlickCard(video: video)
    }
}

// MARK: - Profile Playlists View
struct ProfilePlaylistsView: View {
    let user: User
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(samplePlaylists(for: user), id: \.id) { playlist in
                ProfilePlaylistRow(playlist: playlist)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private func samplePlaylists(for user: User) -> [MockPlaylist] {
        [
            MockPlaylist(
                id: UUID().uuidString,
                title: "Best of \(user.displayName)",
                videoCount: 12,
                thumbnailURL: "https://picsum.photos/200/150?random=1"
            ),
            MockPlaylist(
                id: UUID().uuidString,
                title: "Recent Uploads",
                videoCount: 8,
                thumbnailURL: "https://picsum.photos/200/150?random=2"
            ),
            MockPlaylist(
                id: UUID().uuidString,
                title: "Popular Videos",
                videoCount: 15,
                thumbnailURL: "https://picsum.photos/200/150?random=3"
            )
        ]
    }
}

struct MockPlaylist {
    let id: String
    let title: String
    let videoCount: Int
    let thumbnailURL: String
}

struct ProfilePlaylistRow: View {
    let playlist: MockPlaylist
    @State private var isPressed: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: playlist.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(playlist.videoCount) videos")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Profile Community View
struct ProfileCommunityView: View {
    let user: User
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(sampleCommunityPosts(for: user), id: \.id) { post in
                ProfileCommunityPostCard(post: post, user: user)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private func sampleCommunityPosts(for user: User) -> [MockCommunityPost] {
        [
            MockCommunityPost(
                id: UUID().uuidString,
                content: "Working on some exciting new content! What would you like to see next? 🎬",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                likeCount: 145,
                commentCount: 23
            ),
            MockCommunityPost(
                id: UUID().uuidString,
                content: "Behind the scenes from yesterday's shoot. The creativity never stops! ✨",
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                likeCount: 287,
                commentCount: 45
            ),
            MockCommunityPost(
                id: UUID().uuidString,
                content: "Thank you for 100K subscribers! This community is amazing 💫",
                timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                likeCount: 892,
                commentCount: 156
            )
        ]
    }
}

struct MockCommunityPost {
    let id: String
    let content: String
    let timestamp: Date
    let likeCount: Int
    let commentCount: Int
}

struct ProfileCommunityPostCard: View {
    let post: MockCommunityPost
    let user: User
    @State private var isLiked: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack(spacing: 12) {
                if let profileImageURL = user.profileImageURL {
                    CachedAsyncImage(url: URL(string: profileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.displayName)
                            .font(AppTheme.Typography.bodyMedium)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(post.timestamp.timeIntervalSinceNow < -86400 ? 
                         post.timestamp.formatted(.dateTime.month().day()) : 
                         RelativeDateTimeFormatter().localizedString(for: post.timestamp, relativeTo: Date())
                    )
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Post Content
            Text(post.content)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Actions
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                    }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : AppTheme.Colors.textSecondary)
                        
                        Text("\(post.likeCount + (isLiked ? 1 : 0))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .scaleEffect(isLiked ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("\(post.commentCount)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Shadows.small.color,
            radius: AppTheme.Shadows.small.radius,
            x: AppTheme.Shadows.small.x,
            y: AppTheme.Shadows.small.y
        )
    }
}

// MARK: - Profile About View
struct ProfileAboutView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Basic Info
            if let bio = user.bio {
                InfoSection(title: "About", icon: "info.circle") {
                    Text(bio)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            // Stats
            InfoSection(title: "Channel Statistics", icon: "chart.bar") {
                VStack(spacing: 12) {
                    StatRow(label: "Joined", value: user.createdAt.formatted(.dateTime.month().day().year()))
                    StatRow(label: "Total Subscribers", value: user.subscriberCount.formatted())
                    StatRow(label: "Total Videos", value: "\(user.videoCount)")
                    
                    if let totalViews = user.totalViews {
                        StatRow(label: "Total Views", value: formatLargeNumber(totalViews))
                    }
                }
            }
            
            // Location & Links
            if user.location != nil || !user.socialLinks.isEmpty {
                InfoSection(title: "Links & Location", icon: "link") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let location = user.location {
                            HStack(spacing: 8) {
                                Image(systemName: "location")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Text(location)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        }
                        
                        if let website = user.website {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        ForEach(user.socialLinks) { socialLink in
                            HStack(spacing: 8) {
                                Image(systemName: socialLink.platform.iconName)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Link(socialLink.displayName, destination: URL(string: socialLink.url) ?? URL(string: "https://example.com")!)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 100)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1_000_000_000 {
            return String(format: "%.1fB", Double(number) / 1_000_000_000)
        } else if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return number.formatted()
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            content
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Shadows.small.color,
            radius: AppTheme.Shadows.small.radius,
            x: AppTheme.Shadows.small.x,
            y: AppTheme.Shadows.small.y
        )
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

#Preview {
    ScrollView {
        ProfileContentView(
            selectedTab: .about,
            user: User.sampleUsers[0],
            videos: Video.sampleVideos
        )
    }
    .background(AppTheme.Colors.background)
}