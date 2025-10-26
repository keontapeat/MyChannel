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
    @State private var isIncognito: Bool = false

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
            if !authManager.isAuthenticated {
                // Show YouTube-like sign-in prompt when not authenticated
                UnauthenticatedPromptView(promptType: .profile) {
                    // Present our professional sign-in sheet
                    NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                }
            } else if hasError {
                profileErrorView
            } else if isLoading {
                profileLoadingView
            } else {
                profileContent
            }
        }
        .onAppear { loadProfileSafely() }
        .onChange(of: authManager.currentUser) { newUser in
            handleUserChange(newUser)
        }
        .onChange(of: appState.currentUser) { newUser in
            handleUserChange(newUser)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { note in
            if let updated = note.object as? User {
                handleUserChange(updated)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            // 🔥 IMMEDIATE REFRESH: Reload profile when video is uploaded
            loadProfileSafely()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenNotificationsInbox"))) { _ in
            showingSettings = false
            NotificationCenter.default.post(name: Notification.Name("PresentNotificationsInbox"), object: nil)
        }
        .fullScreenCover(isPresented: Binding(
            get: { false },
            set: { _ in }
        )) {
            EmptyView()
        }
    }

    // MARK: - Main Profile Content

    @ViewBuilder
    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header - flush to top
                ProfileHeaderView(
                    user: user,
                    scrollOffset: scrollOffset,
                    isFollowing: $isFollowing,
                    showingEditProfile: $showingEditProfile,
                    showingSettings: $showingSettings
                )
                .ignoresSafeArea(edges: .top)
                
                // Profile Tabs
                ProfileTabNavigation(
                    selectedTab: $selectedTab,
                    user: user,
                    scrollOffset: scrollOffset
                )
                
                // Profile Content
                SafeProfileContentView(
                    selectedTab: selectedTab,
                    user: user,
                    videos: userVideos
                )
                
                // Quick Actions and Links
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    // Quick Actions Chips
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
                    
                    // Creator Studio Link
                    NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(AppTheme.Colors.primary)
                            Text("Open Creator Studio")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding()
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // History Section
                    if !watchHistory.isEmpty {
                        ProfileHistorySection(
                            title: "History",
                            videos: watchHistory
                        ) {
                            NotificationCenter.default.post(name: .openFullHistory, object: nil)
                        }
                    }
                    
                    // AI Content Factory Link - TEMPORARILY HIDDEN
                    // NavigationLink(destination: AIContentFactoryView()) {
                    //     HStack(spacing: 12) {
                    //         Image(systemName: "brain.head.profile")
                    //             .foregroundColor(.purple)
                    //         Text("🤖 AI Content Factory")
                    //             .font(.system(size: 15, weight: .semibold))
                    //             .foregroundColor(AppTheme.Colors.textPrimary)
                    //         Spacer()
                    //         Text("NEW")
                    //             .font(.system(size: 9, weight: .bold))
                    //             .foregroundColor(.white)
                    //             .padding(.horizontal, 5)
                    //             .padding(.vertical, 1)
                    //             .background(.red, in: Capsule())
                    //     }
                    //     .padding()
                    //     .background(AppTheme.Colors.surface)
                    //     .cornerRadius(12)
                    //     .padding(.horizontal)
                    // }
                    
                    // Quantum Analytics Link - TEMPORARILY HIDDEN
                    // NavigationLink(destination: QuantumAnalyticsDashboard()) {
                    //     HStack(spacing: 12) {
                    //         Image(systemName: "atom")
                    //             .foregroundColor(.cyan)
                    //         Text("🌌 Quantum Analytics")
                    //             .font(.system(size: 15, weight: .semibold))
                    //             .foregroundColor(AppTheme.Colors.textPrimary)
                    //         Spacer()
                    //         Text("NEW")
                    //             .font(.system(size: 9, weight: .bold))
                    //             .foregroundColor(.white)
                    //             .padding(.horizontal, 5)
                    //             .padding(.vertical, 1)
                    //             .background(.green, in: Capsule())
                    //     }
                    //     .padding()
                    //     .background(AppTheme.Colors.surface)
                    //     .cornerRadius(12)
                    //     .padding(.horizontal)
                    // }
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditWrapper(user: $user)
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsWrapper()
        }
        .overlay(alignment: .top) {
            if let u = authManager.currentUser, u.isVerified == false {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verify your email")
                            .font(.system(size: 13, weight: .semibold))
                        Text("We sent a verification link to \(u.email).")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Resend") {
                        Task { try? await AuthService.shared.requestEmailVerification() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.surface)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
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
            user = currentUser
            Task { @MainActor in
                let creatorId = user.id
                var vids = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: creatorId)
                if vids.isEmpty {
                    // 🔥 FALLBACK: Check local storage first
                    if let localVids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: creatorId), !localVids.isEmpty {
                        vids = localVids
                    } else {
                        // Fallback to API if available
                        if let summaries = try? await VideoAPIService.shared.getHomeFeed(page: 1, limit: 24).videos {
                            // Map summaries to full Video only if they belong to this creator (best-effort)
                            let mapped: [Video] = summaries.compactMap { s in
                                if s.creator.id == creatorId {
                                    return Video(
                                        id: s.id,
                                        title: s.title,
                                        description: s.description ?? "",
                                        thumbnailURL: s.thumbnailUrl ?? "",
                                        videoURL: "",
                                        duration: TimeInterval(s.duration ?? 0),
                                        viewCount: s.viewCount,
                                        likeCount: s.likeCount,
                                        creator: user,
                                        category: .entertainment
                                    )
                                }
                                return nil
                            }
                            vids = mapped
                        }
                        }
                }
                userVideos = vids
                
                // 🔥 REAL-TIME STATS UPDATE: Update user stats based on actual videos
                let totalViews = vids.reduce(0) { $0 + $1.viewCount }
                let updatedUser = User(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    email: user.email,
                    profileImageURL: user.profileImageURL,
                    bannerImageURL: user.bannerImageURL,
                    bio: user.bio,
                    subscriberCount: user.subscriberCount,
                    videoCount: vids.count, // 🔥 REAL VIDEO COUNT
                    isVerified: user.isVerified,
                    isCreator: user.isCreator,
                    createdAt: user.createdAt,
                    location: user.location,
                    website: user.website,
                    socialLinks: user.socialLinks,
                    followerCount: user.followerCount,
                    followingCount: user.followingCount,
                    joinDate: user.joinDate,
                    totalViews: totalViews, // 🔥 REAL TOTAL VIEWS
                    totalEarnings: user.totalEarnings,
                    membershipTiers: user.membershipTiers,
                    bannerVideoURL: user.bannerVideoURL,
                    bannerVideoMuted: user.bannerVideoMuted,
                    bannerVideoContentMode: user.bannerVideoContentMode
                )
                user = updatedUser
                
                // Update AppState with new stats
                appState.currentUser = updatedUser
                
                // Fetch watch history from Firestore
                if let uid = authManager.currentUser?.id {
                    let historyVideos = await HistoryService.shared.fetch(userId: uid, limit: 20)
                    watchHistory = historyVideos
                } else {
                    watchHistory = []
                }
                isLoading = false
                hasError = false
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
                    Task { @MainActor in
                        let vids = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: newUser.id)
                        userVideos = vids
                        watchHistory = []
                    }
            } else {
                user = User.defaultUser
                userVideos = []
                watchHistory = []
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
    
    // MARK: - Profile Content with Tabs
    @ViewBuilder
    private var profileContentWithTabs: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
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
                        
                        NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.bar.xaxis")
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text("Open Creator Studio")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        AppTheme.Colors.primary.opacity(0.1),
                                        AppTheme.Colors.primary.opacity(0.05)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // History Section (commented out due to scope issues)
                        // History content would go here
                    }
                    .padding(.bottom, 24)
                } header: {
                    // Absolutely flush, pinned tabs
                    // ProfileTabNavigation(
                    //     selectedTab: $selectedTab,
                    //     user: user,
                    //     scrollOffset: scrollOffset
                    // )
                    Text("Tab Navigation")
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

// MARK: - SafeProfileHeaderView (Updated – No selectedTab)

// Removed SafeProfileHeaderView - replaced with simpler structure

// Removed ProfileHeaderSection - using ProfileHeaderView directly

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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    static let presentSignInSheet = Notification.Name("presentSignInSheet")
}

// MARK: - Previews

#Preview("Profile Header Section") {
    ProfileHeaderView(
        user: User.sampleUsers.first ?? .defaultUser,
        scrollOffset: 0,
        isFollowing: Binding.constant(false),
        showingEditProfile: Binding.constant(false),
        showingSettings: Binding.constant(false)
    )
    .environmentObject(AppState())
}

#Preview("Profile Tabs Section") {
    ProfileTabsSection(
        selectedTab: Binding.constant(.videos),
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

#Preview("Profile View") {
    ProfileView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}

#Preview("Profile Edit Wrapper") {
    ProfileEditWrapper(user: Binding.constant(User.defaultUser))
}

#Preview("Profile Settings Wrapper") {
    ProfileSettingsWrapper()
}