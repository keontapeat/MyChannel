//
//  ProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab: ProfileTab = .videos
    @State private var showingSettings: Bool = false
    @State private var showingEditProfile: Bool = false

    @State private var user: User = User.defaultUser
    @State private var isFollowing: Bool = false
    @State private var userVideos: [Video] = []
    @State private var watchHistory: [Video] = []

    @State private var scrollOffset: CGFloat = 0
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""

    private var currentUser: User {
        if let appUser = appState.currentUser {
            return appUser
        } else if let authUser = authManager.currentUser {
            return authUser
        } else {
            return User.defaultUser
        }
    }

    var body: some View {
        Group {
            if hasError {
                profileErrorView
            } else if isLoading {
                profileLoadingView
            } else {
                profileContent
            }
        }
        .onAppear { loadProfileSafely() }
        .onChange(of: authManager.currentUser) { _, newUser in
            handleUserChange(newUser)
        }
        .onChange(of: appState.currentUser) { _, newUser in
            handleUserChange(newUser)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { note in
            if let updated = note.object as? User {
                handleUserChange(updated)
            }
        }
    }

    // MARK: - Main Profile Content

    @ViewBuilder
    private var profileContent: some View {
        ProfileMainSection(
            user: user,
            selectedTab: $selectedTab,
            isFollowing: $isFollowing,
            showingEditProfile: $showingEditProfile,
            showingSettings: $showingSettings,
            userVideos: $userVideos,
            watchHistory: $watchHistory,
            scrollOffset: $scrollOffset
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditWrapper(user: $user)
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsWrapper()
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var profileLoadingView: some View {
        ProfileLoadingSkeleton()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
    }

    // MARK: - Error View

    @ViewBuilder
    private var profileErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)

            VStack(spacing: 8) {
                Text("Profile Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(errorMessage.isEmpty ? "Unable to load profile" : errorMessage)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Try Again") {
                retryLoadProfile()
            }
            .buttonStyle(ProfileRetryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationBarHidden(true)
    }

    // MARK: - Helpers

    private func loadProfileSafely() {
        isLoading = true
        hasError = false
        errorMessage = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                user = currentUser

                if Video.sampleVideos.isEmpty {
                    userVideos = createFallbackVideos()
                    watchHistory = createFallbackVideos().reversed()
                } else {
                    userVideos = Array(Video.sampleVideos.prefix(20))
                    let pool = Array(Video.sampleVideos.dropFirst(min(4, Video.sampleVideos.count)).prefix(18))
                    watchHistory = pool.isEmpty ? userVideos : pool
                }

                isLoading = false
                hasError = false

                print("✅ Profile loaded successfully for user: \(user.displayName)")
            } catch {
                handleError("Failed to load profile: \(error.localizedDescription)")
            }
        }
    }

    private func createFallbackVideos() -> [Video] {
        [
            Video(
                title: "Welcome to MyChannel!",
                description: "Getting started with content creation",
                thumbnailURL: "https://picsum.photos/1280/720?random=1",
                videoURL: "https://example.com/video1.mp4",
                duration: 180,
                viewCount: 1234,
                likeCount: 89,
                commentCount: 23,
                creator: user,
                category: .entertainment,
                tags: ["Welcome", "Getting Started"]
            ),
            Video(
                title: "Behind the Scenes",
                description: "A look at how content is made",
                thumbnailURL: "https://picsum.photos/1280/720?random=2",
                videoURL: "https://example.com/video2.mp4",
                duration: 300,
                viewCount: 856,
                likeCount: 45,
                commentCount: 12,
                creator: user,
                category: .entertainment,
                tags: ["Behind the Scenes"]
            ),
            Video(
                title: "Creator Tips: Grow Faster",
                description: "Top tips for creators",
                thumbnailURL: "https://picsum.photos/1280/720?random=3",
                videoURL: "https://example.com/video3.mp4",
                duration: 255,
                viewCount: 2310,
                likeCount: 153,
                commentCount: 34,
                creator: user,
                category: .education,
                tags: ["Tips", "Growth"]
            )
        ]
    }

    private func handleUserChange(_ newUser: User?) {
        DispatchQueue.main.async {
            if let newUser {
                user = newUser
                if Video.sampleVideos.isEmpty {
                    userVideos = createFallbackVideos()
                    watchHistory = createFallbackVideos().reversed()
                } else {
                    userVideos = Array(Video.sampleVideos.prefix(20))
                    let pool = Array(Video.sampleVideos.dropFirst(min(4, Video.sampleVideos.count)).prefix(18))
                    watchHistory = pool.isEmpty ? userVideos : pool
                }
            } else {
                user = User.defaultUser
                userVideos = createFallbackVideos()
                watchHistory = createFallbackVideos().reversed()
            }
        }
    }

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            hasError = true
            isLoading = false

            print("❌ Profile error: \(message)")
        }
    }

    private func retryLoadProfile() {
        hasError = false
        errorMessage = ""
        loadProfileSafely()
    }
}

// MARK: - SafeProfileHeaderView (Updated – No selectedTab)

struct SafeProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool

    var body: some View {
        SafeViewWrapper {
            ProfileHeaderView(
                user: user,
                scrollOffset: scrollOffset,
                isFollowing: $isFollowing,
                showingEditProfile: $showingEditProfile,
                showingSettings: $showingSettings
            )
        } fallback: {
            VStack {
                Rectangle()
                    .fill(AppTheme.Colors.primary.opacity(0.3))
                    .frame(height: 365)

                Text("Header unavailable")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding()
            }
        }
    }
}

// MARK: - Profile Main Section

private struct ProfileMainSection: View {
    let user: User
    @Binding var selectedTab: ProfileTab
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool
    @Binding var userVideos: [Video]
    @Binding var watchHistory: [Video]
    @Binding var scrollOffset: CGFloat

    @State private var isIncognito: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Track scroll offset for header collapse animations
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ProfileScrollOffsetPreferenceKey.self,
                                        value: proxy.frame(in: .named("profileScroll")).minY)
                    }
                    .frame(height: 0)

                    // Header
                    ProfileHeaderSection(
                        user: user,
                        scrollOffset: scrollOffset,
                        isFollowing: $isFollowing,
                        showingEditProfile: $showingEditProfile,
                        showingSettings: $showingSettings
                    )
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)

                    // Pinned Tabs (flush under header)
                    Section {
                        // Content under tabs
                        ProfileContentSection(
                            selectedTab: selectedTab,
                            user: user,
                            videos: userVideos
                        )
                        .padding(.top, 8)
                        .background(AppTheme.Colors.background)

                        VStack(spacing: 14) {
                            Divider()
                                .padding(.horizontal)

                            ProfileQuickActionsChips(
                                isIncognito: isIncognito,
                                switchAccountAction: {
                                    HapticManager.shared.impact(style: .light)
                                    NotificationCenter.default.post(name: .navigateToAccountSwitcher, object: nil)
                                },
                                googleAccountAction: {
                                    HapticManager.shared.impact(style: .light)
                                    NotificationCenter.default.post(name: .openGoogleAccount, object: nil)
                                },
                                toggleIncognitoAction: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        isIncognito.toggle()
                                    }
                                    HapticManager.shared.impact(style: .rigid)
                                }
                            )
                            .padding(.horizontal)

                            ProfileHistorySection(
                                title: "History",
                                videos: watchHistory,
                                onViewAll: {
                                    HapticManager.shared.impact(style: .light)
                                    NotificationCenter.default.post(name: .openFullHistory, object: nil)
                                }
                            )
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    } header: {
                        // Absolutely flush, pinned tabs
                        ProfileTabNavigation(
                            selectedTab: $selectedTab,
                            user: user,
                            scrollOffset: scrollOffset
                        )
                        .background(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .fill(AppTheme.Colors.textSecondary.opacity(0.08))
                                .frame(height: 0.5),
                            alignment: .bottom
                        )
                    }
                }
            }
            .coordinateSpace(name: "profileScroll")
            .ignoresSafeArea(.container, edges: .top)
            .onPreferenceChange(ProfileScrollOffsetPreferenceKey.self) { value in
                withAnimation(.easeOut(duration: 0.12)) {
                    scrollOffset = value
                }
            }
        }
    }
}

private struct ProfileHeaderSection: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool

    var body: some View {
        SafeProfileHeaderView(
            user: user,
            scrollOffset: scrollOffset,
            isFollowing: $isFollowing,
            showingEditProfile: $showingEditProfile,
            showingSettings: $showingSettings
        )
    }
}

private struct ProfileTabsSection: View {
    @Binding var selectedTab: ProfileTab
    let user: User
    let scrollOffset: CGFloat

    var body: some View {
        ProfileTabNavigation(
            selectedTab: $selectedTab,
            user: user,
            scrollOffset: scrollOffset
        )
    }
}

private struct ProfileContentSection: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]

    var body: some View {
        SafeProfileContentView(
            selectedTab: selectedTab,
            user: user,
            videos: videos
        )
    }
}

// MARK: - New: Quick Actions Chips (Switch account / Google Account / Incognito)

private struct ProfileQuickActionsChips: View {
    let isIncognito: Bool
    let switchAccountAction: () -> Void
    let googleAccountAction: () -> Void
    let toggleIncognitoAction: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ActionChip(
                    title: "Switch account",
                    systemImage: "person.crop.circle",
                    action: switchAccountAction
                )

                ActionChip(
                    title: "Google Account",
                    systemImage: "globe",
                    action: googleAccountAction
                )

                ActionChip(
                    title: isIncognito ? "Incognito On" : "Turn on Incognito",
                    systemImage: isIncognito ? "eye.slash.circle.fill" : "eye.slash",
                    isHighlighted: isIncognito,
                    action: toggleIncognitoAction
                )
            }
            .padding(.vertical, 6)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: AppTheme.Colors.background.opacity(0), location: 0.0),
                    .init(color: AppTheme.Colors.background, location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 16)
        }
    }
}

private struct ActionChip: View {
    let title: String
    let systemImage: String
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(isHighlighted ? Color.white : AppTheme.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(isHighlighted ? AppTheme.Colors.primary : AppTheme.Colors.backgroundSecondary.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isHighlighted ? AppTheme.Colors.primary : AppTheme.Colors.backgroundSecondary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .shadow(color: Color.black.opacity(isHighlighted ? 0.12 : 0.06), radius: 8, x: 0, y: 3)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isHighlighted)
    }
}

// MARK: - New: History Section (horizontal carousel like YouTube)

private struct ProfileHistorySection: View {
    let title: String
    let videos: [Video]
    var onViewAll: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Button(action: onViewAll) {
                    Text("View all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.backgroundSecondary.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(videos) { video in
                        HistoryVideoCard(video: video)
                            .frame(width: 280)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.04),
                        .init(color: .black, location: 0.96),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .onAppear {
            if !appear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    appear = true
                }
            }
        }
    }
}

private struct HistoryVideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.backgroundSecondary.opacity(0.6))

                AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            LinearGradient(colors: [AppTheme.Colors.backgroundSecondary, AppTheme.Colors.background], startPoint: .top, endPoint: .bottom)
                            ProgressView()
                                .tint(AppTheme.Colors.primary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .failure:
                        ZStack {
                            Color.gray.opacity(0.25)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 160)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.25)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )

                Text(video.duration.formattedAsTimestamp())
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
        }
    }
}

// MARK: - Wrappers for previews

struct ProfileEditWrapper: View {
    @Binding var user: User
    var body: some View {
        NavigationStack {
            EditProfileView(user: $user)
        }
    }
}

struct ProfileSettingsWrapper: View {
    var body: some View {
        SafeProfileSettingsView()
    }
}

// MARK: - Notifications used by the new sections

extension Notification.Name {
    static let openFullHistory = Notification.Name("openFullHistory")
    static let navigateToAccountSwitcher = Notification.Name("navigateToAccountSwitcher")
    static let openGoogleAccount = Notification.Name("openGoogleAccount")
    static let openVideoFromHistory = Notification.Name("openVideoFromHistory")
}

// MARK: - Previews

#Preview("Profile Header Section") {
    ProfileHeaderSection(
        user: User.sampleUsers.first ?? .defaultUser,
        scrollOffset: 0,
        isFollowing: .constant(false),
        showingEditProfile: .constant(false),
        showingSettings: .constant(false)
    )
    .environmentObject(AppState())
}

#Preview("Profile Tabs Section") {
    ProfileTabsSection(
        selectedTab: .constant(.videos),
        user: User.sampleUsers.first ?? .defaultUser,
        scrollOffset: 0
    )
    .environmentObject(AppState())
}

#Preview("History Section") {
    ProfileHistorySection(
        title: "History",
        videos: Array(Video.sampleVideos.prefix(6))
    ) { }
    .environmentObject(AppState())
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Quick Actions Chips") {
    ProfileQuickActionsChips(
        isIncognito: false,
        switchAccountAction: {},
        googleAccountAction: {},
        toggleIncognitoAction: {}
    )
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Profile Content Section") {
    ProfileContentSection(
        selectedTab: .videos,
        user: User.sampleUsers.first ?? .defaultUser,
        videos: Array(Video.sampleVideos.prefix(6))
    )
    .environmentObject(AppState())
}

#Preview("Profile Main Section") {
    ProfileMainSection(
        user: User.sampleUsers.first ?? .defaultUser,
        selectedTab: .constant(.videos),
        isFollowing: .constant(false),
        showingEditProfile: .constant(false),
        showingSettings: .constant(false),
        userVideos: .constant(Array(Video.sampleVideos.prefix(8))),
        watchHistory: .constant(Array(Video.sampleVideos.prefix(8))),
        scrollOffset: .constant(0)
    )
    .environmentObject(AppState())
}

#Preview("Profile Edit Wrapper") {
    ProfileEditWrapper(user: .constant(User.defaultUser))
}

#Preview("Profile Settings Wrapper") {
    ProfileSettingsWrapper()
}