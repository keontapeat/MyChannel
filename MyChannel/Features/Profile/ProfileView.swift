//
//  ProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab: ProfileTab = .videos
    @State private var showingSettings: Bool = false
    @State private var showingEditProfile: Bool = false
    @State private var user: User = User.sampleUsers[0]
    @State private var isFollowing: Bool = false
    @State private var userVideos: [Video] = Video.sampleVideos
    @State private var scrollOffset: CGFloat = 0

    var currentUser: User {
        authManager.currentUser ?? User.sampleUsers[0]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) { // Changed from VStack to LazyVStack
                // Profile Header with Parallax
                ProfileHeaderView(
                    user: currentUser,
                    scrollOffset: scrollOffset,
                    isFollowing: $isFollowing,
                    showingEditProfile: $showingEditProfile,
                    showingSettings: $showingSettings
                )

                // Tab Navigation
                ProfileTabNavigation(
                    selectedTab: $selectedTab,
                    user: currentUser
                )

                // Content based on selected tab
                ProfileContentView(
                    selectedTab: selectedTab,
                    user: currentUser,
                    videos: userVideos
                )

                // Community Section Integration
                if selectedTab == .about {
                    communitySection
                }
            }
            // Removed problematic frame modifiers
        }
        .coordinateSpace(name: "scroll")
        .background(AppTheme.Colors.background)
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(user: .constant(currentUser))
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsView()
        }
        .onAppear {
            // Update local user from auth manager
            user = currentUser
        }
    }

    // MARK: - Community Section in Profile (Fixed)
    private var communitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Fixed header section
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(AppTheme.Colors.primary)

                    Text("Community")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    Button("View All") {
                        // Navigate to full community view
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.primary)
                }
                .frame(maxWidth: .infinity) // Ensure full width
            }

            // Recent Community Posts - Fixed layout
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(CommunityPost.samplePosts.prefix(3))) { post in
                    VStack(alignment: .leading, spacing: 8) { // Changed from HStack to VStack
                        Text(post.content)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Text(post.createdAt, style: .relative)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)

                            Spacer()

                            Label("\(post.likeCount)", systemImage: "heart")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)

                            Label("\(post.commentCount)", systemImage: "bubble.right")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading) // Fixed alignment
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure full width alignment
    }
}

// MARK: - ProfileTab Enum
enum ProfileTab: String, CaseIterable {
    case videos = "videos"
    case shorts = "shorts"
    case playlists = "playlists"
    case about = "about"
}

// MARK: - Profile Settings View (Enhanced with Better Organization)
struct ProfileSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutAlert: Bool = false
    @State private var selectedTheme: Int = 0
    @State private var pushNotificationsEnabled: Bool = true
    @State private var emailNotificationsEnabled: Bool = true
    @State private var darkModeEnabled: Bool = false

    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Light").tag(0)
                        Text("Dark").tag(1)
                        Text("System").tag(2)
                    }
                    .pickerStyle(.menu)

                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                }

                Section("Account") {
                    SettingsRow(
                        icon: "person.circle",
                        title: "Edit Profile",
                        action: {
                            // Edit profile
                        }
                    )

                    SettingsRow(
                        icon: "lock",
                        title: "Privacy & Security",
                        action: {
                            // Privacy settings
                        }
                    )

                    SettingsRow(
                        icon: "key",
                        title: "Change Password",
                        action: {
                            // Change password
                        }
                    )
                }

                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $pushNotificationsEnabled)

                    Toggle("Email Notifications", isOn: $emailNotificationsEnabled)

                    SettingsRow(
                        icon: "bell.badge",
                        title: "Notification Settings",
                        action: {
                            // Detailed notification settings
                        }
                    )
                }

                Section("Content") {
                    SettingsRow(
                        icon: "video",
                        title: "My Videos",
                        action: {
                            // My videos
                        }
                    )

                    SettingsRow(
                        icon: "bookmark",
                        title: "Saved Videos",
                        action: {
                            // Saved videos
                        }
                    )

                    SettingsRow(
                        icon: "clock",
                        title: "Watch History",
                        action: {
                            // Watch history
                        }
                    )

                    SettingsRow(
                        icon: "arrow.down.circle",
                        title: "Downloads",
                        action: {
                            // Downloads
                        }
                    )
                }

                Section("Data & Storage") {
                    SettingsRow(
                        icon: "network",
                        title: "Data Saver",
                        action: {
                            // Data saver settings
                        }
                    )

                    SettingsRow(
                        icon: "externaldrive",
                        title: "Storage Management",
                        action: {
                            // Storage management
                        }
                    )
                }

                Section("Support") {
                    SettingsRow(
                        icon: "questionmark.circle",
                        title: "Help & Support",
                        action: {
                            // Help
                        }
                    )

                    SettingsRow(
                        icon: "exclamationmark.bubble",
                        title: "Send Feedback",
                        action: {
                            // Send feedback
                        }
                    )

                    SettingsRow(
                        icon: "star",
                        title: "Rate This App",
                        action: {
                            // Rate app
                        }
                    )
                }

                Section("Legal") {
                    SettingsRow(
                        icon: "doc.text",
                        title: "Terms of Service",
                        action: {
                            // Terms
                        }
                    )

                    SettingsRow(
                        icon: "hand.raised",
                        title: "Privacy Policy",
                        action: {
                            // Privacy policy
                        }
                    )
                }

                Section {
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.error)
                                .frame(width: 24)

                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.error)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out of your account?")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Rest of ProfileView components...

struct ProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool

    private var headerOpacity: Double {
        let threshold: CGFloat = 200
        let opacity = 1.0 - (abs(scrollOffset) / threshold)
        return max(0.0, opacity)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Banner with parallax effect
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: user.bannerImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipped()
                    .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: 200)
                }

                // Profile info
                VStack(spacing: 20) {
                    // Avatar and basic info
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        Image(systemName: "person.circle")
                                            .font(.system(size: 40))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    )
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(radius: 10)
                            .offset(y: -50)

                            // Online status
                            if user.isCreator {
                                Circle()
                                    .fill(AppTheme.Colors.success)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .offset(x: 8, y: -42)
                            }
                        }

                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(user.displayName)
                                    .font(AppTheme.Typography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)

                                if user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.title3)
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }

                            Text("@\(user.username)")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            if let bio = user.bio {
                                Text(bio)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, -30)

                    // Stats
                    ProfileStatsView(user: user)

                    // Action buttons (current user gets edit profile, others get follow)
                    ProfileActionButtons(
                        user: user,
                        isFollowing: $isFollowing,
                        showingEditProfile: $showingEditProfile
                    )

                    // Social links
                    if !user.socialLinks.isEmpty {
                        SocialLinksView(socialLinks: user.socialLinks)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 24)
                .background(AppTheme.Colors.background)
            }
            .frame(maxWidth: .infinity)

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding()
            .opacity(headerOpacity)
        }
        .frame(maxWidth: .infinity)
        .opacity(headerOpacity)
    }
}

struct ProfileStatsView: View {
    let user: User

    var body: some View {
        HStack(spacing: 32) {
            StatItem(
                title: "Subscribers",
                value: user.subscriberCount.formatted(),
                icon: "person.2.fill"
            )

            StatItem(
                title: "Videos",
                value: "\(user.videoCount)",
                icon: "play.rectangle.fill"
            )

            if let totalViews = user.totalViews {
                StatItem(
                    title: "Views",
                    value: totalViews.formatted(),
                    icon: "eye.fill"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppTheme.Colors.primary)

            Text(value)
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfileActionButtons: View {
    let user: User
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Always show edit profile for current user
            Button(action: { showingEditProfile = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
            }
            .secondaryButtonStyle()

            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
            }
            .secondaryButtonStyle()
        }
    }
}

struct SocialLinksView: View {
    let socialLinks: [SocialLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect")
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(socialLinks.prefix(4)) { link in
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: link.platform.iconName)
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.primary)

                            Text(link.platform.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(8)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surface.opacity(0.5))
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

struct ProfileTabNavigation: View {
    @Binding var selectedTab: ProfileTab
    let user: User

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    ProfileTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        count: tab.count(for: user),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct ProfileTabButton: View {
    let tab: ProfileTab
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 16))

                    Text(tab.displayName)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)

                    if let count = count, count > 0 {
                        Text("(\(count))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .foregroundColor(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                )

                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]

    var body: some View {
        switch selectedTab {
        case .videos:
            ProfileVideosView(videos: videos)
        case .shorts:
            ProfileShortsView(shorts: videos.filter { $0.isShort })
        case .playlists:
            ProfilePlaylistsView()
        case .about:
            ProfileAboutView(user: user)
        }
    }
}

struct ProfileVideosView: View {
    let videos: [Video]

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(videos) { video in
                ProfileVideoCard(video: video)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct ProfileVideoCard: View {
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(AppTheme.CornerRadius.md)
            .clipped()
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4),
                alignment: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("\(video.formattedViews) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)

                HStack(spacing: 16) {
                    Label("\(video.likeCount)", systemImage: "heart")
                    Label("\(video.commentCount)", systemImage: "bubble.right")
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

struct ProfileShortsView: View {
    let shorts: [Video]

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(shorts) { short in
                ProfileShortCard(video: short)
            }
        }
        .padding()
    }
}

struct ProfileShortCard: View {
    let video: Video

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(9/16, contentMode: .fit)
            }
            .cornerRadius(AppTheme.CornerRadius.md)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            .cornerRadius(AppTheme.CornerRadius.md)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)

                    Text(video.formattedViews)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(8)
        }
    }
}

struct ProfilePlaylistsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textTertiary)

            VStack(spacing: 8) {
                Text("No playlists yet")
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Create your first playlist to organize your videos")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Playlist") {
                // Create playlist
            }
            .primaryButtonStyle()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProfileAboutView: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let bio = user.bio {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text(bio)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            if let website = user.website {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Website")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Link(website, destination: URL(string: website)!)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }

            if let location = user.location {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text(location)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Joined")
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(user.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Enhanced Edit Profile View (Simplified)
struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("Edit Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Profile editing coming soon!")
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Supporting Types
extension ProfileTab {
    var displayName: String {
        switch self {
        case .videos: return "Videos"
        case .shorts: return "Shorts"
        case .playlists: return "Playlists"
        case .about: return "About"
        }
    }

    var iconName: String {
        switch self {
        case .videos: return "play.rectangle"
        case .shorts: return "bolt"
        case .playlists: return "list.bullet"
        case .about: return "info.circle"
        }
    }

    func count(for user: User) -> Int? {
        switch self {
        case .videos: return user.videoCount
        case .shorts: return nil
        case .playlists: return nil
        case .about: return nil
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager.shared)
        .preferredColorScheme(.light)
}
