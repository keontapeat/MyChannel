//
//  ProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    
    // ⚡ PERF: Use @ObservedObject for singletons (they manage their own lifecycle)
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @ObservedObject private var playlistService = PlaylistFirestoreService.shared
    @ObservedObject private var profileCache = ProfileCacheService.shared
    @ObservedObject private var storeKit = StoreKitService.shared
    
    // Local state objects (we own these)
    @StateObject private var toastManager = ToastManager()

    @State private var selectedTab: ProfileTab = .videos
    @State private var showingSettings: Bool = false
    @State private var showingEditProfile: Bool = false

    @State private var user: User = User.defaultUser
    @State private var isFollowing: Bool = false
    @State private var userVideos: [Video] = []
    @State private var watchHistory: [WatchHistoryItem] = []
    @State private var isIncognito: Bool = false
    
    // Video Management
    @State private var isManagingVideos = false
    @State private var selectedVideoIDs: Set<String> = []
    @State private var isBulkDeletingVideos = false
    @State private var showBulkDeleteConfirmation = false
    @State private var bulkDeleteErrorMessage: String?
    @State private var showingBulkEditSheet = false
    @State private var showingBulkVisibilitySheet = false
    @State private var showingBulkPlaylistSheet = false
    @State private var playlists: [Playlist] = []
    @State private var isLoadingPlaylists = false
    @State private var undoPayload: BulkUndoPayload?
    @State private var watchHistoryVideos: [Video] = []
    @State private var selectedHighlight: StoryHighlight?
    
    // ⚡ PERFORMANCE: Pagination state with proper type safety
    @State private var isLoadingMoreVideos = false
    @State private var hasMoreVideos = true
    #if canImport(FirebaseFirestore)
    @State private var lastVideoDocument: DocumentSnapshot? = nil
    #else
    @State private var lastVideoDocument: Any? = nil
    #endif
    private let videosPerPage = 24

    @State private var scrollOffset: CGFloat = 0
    @State private var isLoading: Bool = true
    @State private var isLoadingVideos: Bool = true
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""
    
    // Debounce double-fire: authManager + appState both publish when user changes
    @State private var userChangeTask: Task<Void, Never>? = nil
    // 🔥 FIX: Track the main load task so we can cancel on reload/user-change
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var historyTask: Task<Void, Never>? = nil
    
    // Video Analytics Navigation
    @State private var showingVideoAnalytics: Bool = false
    @State private var videoToAnalyze: Video?

    // AI Agent Insights (background-loaded from Cloud Run)
    @State private var aiViralScore: Double? = nil
    @State private var aiChurnRisk: Double? = nil
    @State private var aiRetentionActions: [String] = []
    @State private var aiCreatorInsights: [String] = []
    
    // Premium & Downloads Navigation
    @State private var showingDownloads = false
    @State private var showingPremiumBenefits = false
    @State private var showingMyChannelPlus = false
    
    // Reserve enough space so scrollable content never hides behind the floating MainTabView
    private let tabBarOverlaySafeAreaPadding: CGFloat = 180

    private var currentUser: User {
        if let authUser = authManager.currentUser {
            return authUser
        } else if let appUser = appState.currentUser, !isSampleUser(appUser) {
            return appUser
        } else {
            return User.defaultUser
        }
    }
    
    /// Reject sample users (e.g., "Music Artist") from being used as currentUser.
    private func isSampleUser(_ user: User) -> Bool {
        User.sampleUsers.contains { $0.id == user.id || $0.email == user.email }
    }
    
    private var isViewingOwnProfile: Bool {
        currentUser.id == user.id
    }
    
    // UIDs / emails that identify the single owner account
    private static let ownerUIDs: Set<String> = ["7EAoUc1aKsNRqR4cYBIOYVGB3Mf2"]
    private static let ownerEmails: Set<String> = ["keontapeat@gmail.com", "keontapeat@mychannel.live"]

    /// Returns true only when the currently logged-in user is the channel owner.
    private var isOwnerAccount: Bool {
        if Self.ownerUIDs.contains(currentUser.id) { return true }
        if Self.ownerEmails.contains(currentUser.email.lowercased()) { return true }
        return false
    }

    private var isOwnerProfile: Bool {
        if Self.ownerUIDs.contains(user.id) { return true }
        if Self.ownerEmails.contains(user.email.lowercased()) { return true }
        if user.username.lowercased() == "sbkeonta_" { return true }
        if user.displayName.lowercased().contains("shot by keonta") { return true }
        return false
    }

    // 🔥 OWNER INTRO VIDEO: First video on profile with reliable YouTube thumbnail
    private func ownerIntroVideo() -> Video? {
        let introId = "owner_intro_video"
        let url = "https://firebasestorage.googleapis.com/v0/b/mychannel-ca26d.firebasestorage.app/o/Shot%20By%20Keonta%20Intro%204k.MP4?alt=media&token=88e366e2-efde-4631-9707-d7e9fadc9568"
        let thumbnailURL = "asset://ShotByKeontaThumbnail"
        
        return Video(
            id: introId,
            title: "Shot By Keonta Intro",
            description: "Welcome to MyChannel - Shot By Keonta 🎬🔥",
            thumbnailURL: thumbnailURL,
            videoURL: url,
            duration: 35,
            viewCount: 0,
            likeCount: 0,
            creator: user,
            category: .entertainment,
            tags: ["intro", "keonta", "mychannel"],
            isPublic: true
        )
    }
    
    private var videoManagementContext: VideoManagementContext? {
        guard isViewingOwnProfile else { return nil }
        return VideoManagementContext(
            isManaging: $isManagingVideos,
            selectedIDs: $selectedVideoIDs,
            onToggleSelection: { toggleVideoSelection($0) },
            onSetSelections: { setVideoSelections($0) },
            onAction: { handleBulkAction($0) },
            onExit: { exitVideoManagementMode() },
            isDeleting: isBulkDeletingVideos
        )
    }

    var body: some View {
        mainContentView
            .applyLifecycleModifiers(
                onAppearAction: loadProfileSafely,
                onDisappearAction: {
                    // 🔥 FIX: Cancel in-flight tasks when leaving profile
                    loadTask?.cancel()
                    historyTask?.cancel()
                    print("🎥 [ProfileView] Profile page disappeared — tasks cancelled")
                }
            )
            .applyUserChangeModifiers(
                authManager: authManager,
                appState: appState,
                handleUserChange: handleUserChange
            )
            .applyNotificationModifiers(
                showingSettings: $showingSettings,
                videoToAnalyze: $videoToAnalyze,
                showingVideoAnalytics: $showingVideoAnalytics,
                currentUser: currentUser,
                handleVideoViewCountUpdate: handleVideoViewCountUpdate,
                loadProfileSafely: loadProfileSafely
            )
            .applyVideoManagementModifiers(
                userVideos: userVideos,
                isManagingVideos: isManagingVideos,
                pruneSelectedVideoIDs: pruneSelectedVideoIDs,
                clearSelectedVideoIDs: { selectedVideoIDs.removeAll() }
            )
            .applyAlertModifiers(
                showBulkDeleteConfirmation: $showBulkDeleteConfirmation,
                bulkDeleteErrorMessage: $bulkDeleteErrorMessage,
                selectedVideoIDs: selectedVideoIDs,
                deleteSelectedVideos: deleteSelectedVideos
            )
            .fullScreenCover(isPresented: $showingVideoAnalytics) {
                videoAnalyticsSheet
            }
            .toast(toast: $toastManager.toast)
            .overlay(alignment: .bottom) {
                undoOverlay
            }
            .sheet(item: $selectedHighlight) { highlight in
                StoryHighlightViewer(highlight: highlight)
            }
    }
    
    // MARK: - Body Sub-Views (Broken up to help compiler)
    
    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if !authManager.isAuthenticated {
                UnauthenticatedPromptView(promptType: .profile) {
                    NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                }
            } else if hasError && userVideos.isEmpty {
                // 🔥 FIX: Only show full-screen error if we have NO content to display at all
                profileErrorView
            } else if isLoading && user.id == User.defaultUser.id {
                // 🔥 FIX: Show skeleton only on very first load (no user data yet)
                profileLoadingView
            } else {
                profileContent
            }
        }
    }
    
    @ViewBuilder
    private var videoAnalyticsSheet: some View {
        if let video = videoToAnalyze {
            NavigationStack {
                VideoAnalyticsView(videoId: video.id)
                    .navigationTitle("Video Analytics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingVideoAnalytics = false
                                videoToAnalyze = nil
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.xaxis")
                                    Text("Studio")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var undoOverlay: some View {
        if let payload = undoPayload {
            UndoSnackBar(
                message: payload.message,
                actionTitle: "Undo",
                onAction: { handleUndoAction(payload) },
                onDismiss: { undoPayload = nil }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Main Profile Content

    @ViewBuilder
    private var profileContent: some View {
        GeometryReader { geo in
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

                StoryHighlightsTray(creatorId: user.id) { highlight in
                    selectedHighlight = highlight
                }
                .iPadReadableWidth()

                // Profile Tabs
                ProfileTabNavigation(
                    selectedTab: $selectedTab,
                    user: user,
                    scrollOffset: scrollOffset
                )
                .iPadReadableWidth()

                // Profile Content
                SafeProfileContentView(
                    selectedTab: $selectedTab,
                    user: user,
                    videos: userVideos,
                    onLoadMore: { await loadMoreVideos() },
                    hasMoreVideos: hasMoreVideos,
                    isLoadingMore: isLoadingMoreVideos,
                    isOwnProfile: isViewingOwnProfile,
                    videoManagementContext: videoManagementContext,
                    isLoadingVideos: isLoadingVideos
                )
                .iPadReadableWidth()

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
                    
                    // 🎬 Creator Studio Link - BOLD & VISIBLE WITH PROPER SPACING
                    Spacer()
                        .frame(height: 32)
                    
                    NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                        HStack(spacing: 12) {
                            // 🔥 YOUTUBE PARITY: Neutral icon background (not red)
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Creator Studio")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("Manage your content")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // 🔥 YOUTUBE PARITY: Subtle chevron (not primary color)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // 🔥 PREMIUM & DOWNLOADS SECTION
                    VStack(spacing: 12) {
                        // Downloads
                        Button {
                            showingDownloads = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Downloads")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Text("Watch videos offline")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        if AppConfig.Features.enableSubscriptions || storeKit.isPremium {
                            Button {
                                if storeKit.isPremium {
                                    showingPremiumBenefits = true
                                } else {
                                    showingMyChannelPlus = true
                                }
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                HStack(spacing: 12) {
                                    // 🔥 FIX: Clean icon without circle (like other tabs)
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .frame(width: 44, height: 44)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(storeKit.isPremium ? "Your Premium Benefits" : "MyChannel Plus+")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        Text(storeKit.isPremium ? "View your usage stats" : "Try 7 days free")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !storeKit.isPremium {
                                        Text("FREE TRIAL")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black)
                                            .cornerRadius(6)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.Colors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 🔥 YOUTUBE PARITY: Professional Features Section
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Features")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        
                        // Feature Cards (YouTube-style: clean, minimal, no emojis, neutral colors)
                        VStack(spacing: 12) {
                            // 1. MyChannel University
                            YouTubeStyleFeatureCard(
                                icon: "graduationcap.fill",
                                title: "MyChannel University",
                                subtitle: "Learn & earn certificates",
                                destination: UniversityHomeView()
                            )
                            
                            // 2. Gaming & Esports
                            YouTubeStyleFeatureCard(
                                icon: "gamecontroller.fill",
                                title: "Gaming & Esports",
                                subtitle: "Tournaments & competitions",
                                destination: GamingEsportsView()
                            )
                            
                            // 3. Championship Hub
                            YouTubeStyleFeatureCard(
                                icon: "crown.fill",
                                title: "Championship Hub",
                                subtitle: "Medals, rankings & VS matches",
                                destination: ChampionshipHubView()
                            )
                            
                            // 4. Thumbnail Creator - HIDDEN (can be re-enabled later)
                            /*
                            YouTubeStyleFeatureCard(
                                icon: "photo.on.rectangle.angled",
                                title: "Thumbnail Creator",
                                subtitle: "AI-powered thumbnails",
                                destination: ThumbnailCreatorView()
                            )
                            */
                            
                            // 5. Live Shopping
                            YouTubeStyleFeatureCard(
                                icon: "bag.fill",
                                title: "Live Shopping",
                                subtitle: "Shop from creators",
                                destination: LiveShoppingView()
                            )
                            
                            // 6. Streamer Awards
                            YouTubeStyleFeatureCard(
                                icon: "trophy.fill",
                                title: "Streamer Awards",
                                subtitle: "Compete to be the best • Rankings & Achievements",
                                destination: LiveStreamerAwardsView()
                            )
                            
                            // 7. AGI Agent Dashboard (Admin Only)
                            if currentUser.email.lowercased() == "keontapeat@mychannel.live" || currentUser.email.lowercased() == "keontapeat@gmail.com" {
                                YouTubeStyleFeatureCard(
                                    icon: "brain.head.profile",
                                    title: "AGI Agent Dashboard",
                                    subtitle: "\(AGIAgentManager.shared.agents.filter { $0.status == .live }.count) of 30 agents live",
                                    destination: AGIAgentDashboardView(),
                                    isAdmin: true
                                )
                                
                                // 8. 3-Strike Review Queue (Admin Only)
                                YouTubeStyleFeatureCard(
                                    icon: "bolt.fill",
                                    title: "⚖️ 3-Strike Review",
                                    subtitle: "You decide — warn, strike, suspend or ban",
                                    destination: StrikeReviewView(),
                                    isAdmin: true
                                )

                                // 9. Owner Command Center (Admin Only)
                                YouTubeStyleFeatureCard(
                                    icon: "antenna.radiowaves.left.and.right",
                                    title: "⚡ Command Center",
                                    subtitle: "Users · Fraud · Content · Daily Reports",
                                    destination: OwnerCommandCenterView(),
                                    isAdmin: true
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.bottom, 120)
                    
                    // History Section - ALWAYS SHOW
                    ProfileHistorySection(
                        title: "History",
                        videos: watchHistory.map { $0.toVideo() }
                    ) {
                        NotificationCenter.default.post(name: .openFullHistory, object: nil)
                    }
                }
                .padding(.vertical)
                .iPadReadableWidth()
            }
        }
        .frame(maxWidth: .infinity)
        // 🔥 FIX: Provide breathing room so History & bottom sections stay above the floating tab bar
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: tabBarOverlaySafeAreaPadding)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(user: $user)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsWrapper()
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.medium(), .large()],
                            largestUndimmedDetentIdentifier: .large,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
        }
        .sheet(item: $selectedHighlight) { highlight in
            StoryHighlightViewer(highlight: highlight)
        }
        .fullScreenCover(isPresented: $showingDownloads) {
            NavigationStack {
                DownloadsView()
            }
        }
        .fullScreenCover(isPresented: $showingPremiumBenefits) {
            NavigationStack {
                PremiumBenefitsView()
            }
        }
        .fullScreenCover(isPresented: $showingMyChannelPlus) {
            NavigationStack {
                MyChannelPlusView()
            }
        }
        .sheet(isPresented: $showingBulkEditSheet) {
            BulkEditSheet(
                selectedVideoIds: Array(selectedVideoIDs),
                videos: userVideos
            ) {
                loadProfileSafely()
            }
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
        }
        .sheet(isPresented: $showingBulkVisibilitySheet) {
            ProfileBulkVisibilitySheet(
                selectedVideoIds: Array(selectedVideoIDs)
            ) { visibility in
                applyBulkVisibility(visibility)
            }
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium(), .large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
        }
        .sheet(isPresented: $showingBulkPlaylistSheet) {
            ProfileBulkPlaylistSheet(
                playlists: playlists,
                isLoading: isLoadingPlaylists,
                selectedVideoIds: Array(selectedVideoIDs)
            ) { playlistIDs in
                applyBulkPlaylists(playlistIDs)
            }
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium(), .large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
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
        // 🔥 FIX: Cancel any in-flight load to prevent race conditions
        loadTask?.cancel()
        historyTask?.cancel()
        
        // 🔥 FIX: Always reset error state on reload so error view clears
        hasError = false
        errorMessage = ""
        isLoading = true
        
        // 🔥 FIX: Reset pagination cursor so we don't get stale pages
        lastVideoDocument = nil
        hasMoreVideos = true
        
        let userId = currentUser.id
        let cachedUser = profileCache.getCachedUser()
        let canUseCache = cachedUser?.id == userId
        let cachedVideos = canUseCache ? profileCache.getCachedVideos() : []

        // Step 1: Check cache for instant video display
        if !cachedVideos.isEmpty && profileCache.isCacheValid() {
            userVideos = cachedVideos
            isLoadingVideos = false
            print("⚡ [ProfileView] Instant load from cache: \(cachedVideos.count) videos")
        } else if !cachedVideos.isEmpty {
            userVideos = cachedVideos
            isLoadingVideos = true
            print("⚡ [ProfileView] Showing stale cache: \(cachedVideos.count) videos (refreshing)")
        } else {
            if cachedUser != nil && !canUseCache {
                print("⚠️ [ProfileView] Ignoring cached profile for different user: \(cachedUser?.displayName ?? "unknown")")
            }
            isLoadingVideos = true
            print("⏳ [ProfileView] No cache - showing skeleton")
        }
        
        // Step 2: Tracked Task — cancellable, single-flight
        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            // Load complete profile (cache → Firestore → fallback)
            if canUseCache, let cachedUser {
                user = cachedUser
                print("⚡ [ProfileView] Using cached complete profile: \(cachedUser.displayName) (@\(cachedUser.username))")
            } else {
                do {
                    if let firestoreUser = try await UserFirestoreService.shared.fetchUser(id: userId) {
                        guard !Task.isCancelled else { return }
                        user = firestoreUser
                        print("✅ [ProfileView] Loaded complete profile from Firestore: \(firestoreUser.displayName) (@\(firestoreUser.username))")
                    } else {
                        user = currentUser
                        print("⚠️ [ProfileView] No Firestore profile found, using basic auth data: \(currentUser.displayName)")
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    user = currentUser
                    print("🚨 [ProfileView] Error loading Firestore profile: \(error), using basic auth data")
                }
            }
            
            isLoading = false
            guard !Task.isCancelled else { return }
            let creatorId = user.id
            
            // Load first page of videos
            do {
                let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                    creatorId: creatorId,
                    limit: videosPerPage,
                    lastDocument: nil
                )
                guard !Task.isCancelled else { return }
                
                var videosWithIntro = result.videos
                
                if (isViewingOwnProfile && isOwnerAccount) || isOwnerProfile, let intro = ownerIntroVideo() {
                    videosWithIntro.removeAll { $0.id == intro.id }
                    videosWithIntro.insert(intro, at: 0)
                    PinnedVideosStore.shared.pin(intro.id, for: user.id)
                    GlobalVideoPlayerManager.shared.preloadVideo(url: intro.videoURL)
                }
                
                userVideos = videosWithIntro
                lastVideoDocument = result.lastDocument
                // 🔥 FIX: Use raw Firestore count for pagination (don't count injected intro)
                hasMoreVideos = result.videos.count >= videosPerPage
                isLoadingVideos = false
                
                profileCache.cacheProfile(user: user, videos: videosWithIntro)
                
                // Local storage backup only if Firestore returned empty
                if userVideos.isEmpty || (userVideos.count == 1 && userVideos.first?.id == "owner_intro_video") {
                    if let localVids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: creatorId), !localVids.isEmpty {
                        guard !Task.isCancelled else { return }
                        userVideos = Array(localVids.prefix(videosPerPage))
                        hasMoreVideos = localVids.count > videosPerPage
                        profileCache.updateCachedVideos(userVideos)
                    }
                }
                
                print("✅ [ProfileView] Loaded \(result.videos.count) videos from Firestore")
            } catch {
                guard !Task.isCancelled else { return }
                print("🚨 [ProfileView] Error loading videos: \(error)")
                
                // Try local storage as backup
                do {
                    let localVids = try await DatabaseService.shared.fetchVideosByCreator(creatorId: creatorId)
                    guard !Task.isCancelled else { return }
                    if !localVids.isEmpty {
                        userVideos = Array(localVids.prefix(videosPerPage))
                        hasMoreVideos = localVids.count > videosPerPage
                        isLoadingVideos = false
                        print("✅ [ProfileView] Loaded \(userVideos.count) videos from local storage as fallback")
                    } else {
                        finishVideoLoadWithError(hadCachedVideos: !cachedVideos.isEmpty)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    print("⚠️ [ProfileView] Local storage fallback also failed: \(error)")
                    finishVideoLoadWithError(hadCachedVideos: !cachedVideos.isEmpty)
                }
            }
            
            guard !Task.isCancelled else { return }
            
            // Stats update
            recalculateUserStats(propagateGlobalState: true)
            
            // 🔥 FIX: Tracked history task — cancellable on reload
            historyTask?.cancel()
            historyTask = Task {
                guard !Task.isCancelled else { return }
                if let uid = authManager.currentUser?.id {
                    let historyVideos = await HistoryService.shared.fetch(userId: uid, limit: 20)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { watchHistory = historyVideos }
                } else {
                    await MainActor.run { watchHistory = [] }
                }
            }

            // Fire AI agents in background (non-blocking, own profile only)
            if isViewingOwnProfile {
                let snapshotUser = user
                let snapshotVideos = userVideos
                Task {
                    guard !Task.isCancelled else { return }
                    await loadProfileAIInsights(userId: creatorId, snapshotUser: snapshotUser, snapshotVideos: snapshotVideos)
                }
            }
        }
    }
    
    /// Helper to finalize video load state on error
    private func finishVideoLoadWithError(hadCachedVideos: Bool) {
        if userVideos.isEmpty {
            userVideos = []
            if hadCachedVideos {
                setProfileError("Unable to refresh videos. Showing cached content.")
            }
            // Don't show error for empty profile — normal for new users
        } else {
            print("⚡ [ProfileView] Using cached videos due to refresh failure")
        }
        hasMoreVideos = false
        isLoadingVideos = false
    }

    // MARK: - AI Agent Insights

    private func loadProfileAIInsights(userId: String, snapshotUser: User, snapshotVideos: [Video]) async {
        let mlAgents = RealMLAgentsService.shared
        let agentAPI = AgentAPIService.shared

        // 1. Viral prediction on most recent video
        if let topVideo = snapshotVideos.first {
            let avgViews = Double((snapshotUser.totalViews ?? 0) / max(snapshotUser.videoCount, 1))
            if let result = try? await mlAgents.predictViral(
                title: topVideo.title,
                durationSeconds: Int(topVideo.duration),
                thumbnailScore: 0.7,
                subscriberCount: snapshotUser.subscriberCount,
                avgViews: avgViews,
                category: topVideo.category.rawValue,
                isShorts: topVideo.duration < 60
            ) {
                aiViralScore = result.viral_probability
                print("🤖 [ProfileAI] Viral score for \(topVideo.title): \(Int(result.viral_probability * 100))%")
            }
        }

        // 2. Churn/retention risk for this creator's audience
        let accountAgeDays = max(Int(Date().timeIntervalSince(snapshotUser.createdAt) / 86400), 1)
        let totalViewCount = snapshotUser.totalViews ?? 0
        let isPremium = !(snapshotUser.membershipTiers?.isEmpty ?? true)
        if let result = try? await mlAgents.predictChurn(
            userId: userId,
            daysSinceSignup: accountAgeDays,
            daysSinceLastVisit: 1,
            totalWatchTimeHours: Double(totalViewCount) * 0.05,
            avgSessionMinutes: 12.0,
            sessionsLast7Days: 7,
            sessionsLast30Days: 25,
            videosLast7Days: max(snapshotUser.videoCount / 4, 1),
            videosLast30Days: max(snapshotUser.videoCount, 1),
            isPremium: isPremium
        ) {
            aiChurnRisk = result.churn_probability
            aiRetentionActions = result.retention_actions
            print("🤖 [ProfileAI] Churn risk: \(result.risk_level) (\(Int(result.churn_probability * 100))%)")
        }

        // 3. Creator analytics agent
        if let result = try? await agentAPI.getCreatorAnalytics(
            creatorId: userId,
            timeRange: "30d"
        ) {
            aiCreatorInsights = result.insights
            print("🤖 [ProfileAI] Creator insights loaded: \(result.insights.count) tips")
        }
    }

    private func recalculateUserStats(propagateGlobalState: Bool = false) {
        let actualVideoCount = userVideos.count
        let totalViews = userVideos.reduce(0) { $0 + $1.viewCount }
        let updatedUser = user.updating(videoCount: actualVideoCount, totalViews: totalViews)
        applyUpdatedUser(updatedUser, propagateGlobalState: propagateGlobalState)
    }
    
    private func applyUpdatedUser(_ updatedUser: User, propagateGlobalState: Bool) {
        user = updatedUser
        
        guard propagateGlobalState else { return }
        appState.currentUser = updatedUser
    }
    
    private func handleVideoViewCountUpdate(videoId: String, latestCount: Int) {
        guard let index = userVideos.firstIndex(where: { $0.id == videoId }) else { return }
        guard userVideos[index].viewCount != latestCount else { return }
        
        userVideos[index].viewCount = latestCount
        recalculateUserStats()
    }
    
    // REMOVED: createFallbackVideos() - No more mock/fallback videos
    // Only show real videos the user has actually posted

    @MainActor
    private func handleUserChange(_ newUser: User?) {
        guard let newUser else {
            // 🔥 FIX: Cancel all in-flight work on logout
            loadTask?.cancel()
            historyTask?.cancel()
            userChangeTask?.cancel()
            user = User.defaultUser
            userVideos = []
            watchHistory = []
            hasError = false
            errorMessage = ""
            isLoading = false
            isLoadingVideos = false
            lastVideoDocument = nil
            hasMoreVideos = false
            profileCache.clearCache()
            return
        }
        
        // 🔥 FIX: Cancel loadTask too — handleUserChange replaces its work entirely
        loadTask?.cancel()
        historyTask?.cancel()
        userChangeTask?.cancel()
        
        userChangeTask = Task { @MainActor in
            // Small yield so any second fire in the same runloop cancels this before we start
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            guard !Task.isCancelled else { return }
            
            // 🔥 FIX: Reset error + pagination state
            hasError = false
            errorMessage = ""
            lastVideoDocument = nil
            hasMoreVideos = true
            
            let cachedUser = profileCache.getCachedUser()
            let canUseCache = cachedUser?.id == newUser.id
            let cachedVideos = canUseCache ? profileCache.getCachedVideos() : []

            // Show cached videos instantly
            if !cachedVideos.isEmpty { userVideos = cachedVideos }
            isLoadingVideos = true
            
            // Always fetch complete Firestore profile — don't use basic auth object
            do {
                if let firestoreUser = try await UserFirestoreService.shared.fetchUser(id: newUser.id) {
                    guard !Task.isCancelled else { return }
                    user = firestoreUser
                } else {
                    user = newUser
                }
            } catch {
                guard !Task.isCancelled else { return }
                user = newUser
            }
            guard !Task.isCancelled else { return }
            
            // Load videos for this user
            do {
                let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                    creatorId: user.id,
                    limit: videosPerPage,
                    lastDocument: nil
                )
                guard !Task.isCancelled else { return }
                
                var videosWithIntro = result.videos
                if (isViewingOwnProfile && isOwnerAccount) || isOwnerProfile, let intro = ownerIntroVideo() {
                    videosWithIntro.removeAll { $0.id == intro.id }
                    videosWithIntro.insert(intro, at: 0)
                    PinnedVideosStore.shared.pin(intro.id, for: user.id)
                }
                
                userVideos = videosWithIntro
                lastVideoDocument = result.lastDocument
                hasMoreVideos = result.videos.count >= videosPerPage
                isLoadingVideos = false
                profileCache.cacheProfile(user: user, videos: videosWithIntro)
                
                if userVideos.isEmpty || (userVideos.count == 1 && userVideos.first?.id == "owner_intro_video"),
                   let localVids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: user.id),
                   !localVids.isEmpty {
                    guard !Task.isCancelled else { return }
                    userVideos = Array(localVids.prefix(videosPerPage))
                    hasMoreVideos = localVids.count > videosPerPage
                    profileCache.updateCachedVideos(userVideos)
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("🚨 [ProfileView] handleUserChange video load error: \(error)")
                if userVideos.isEmpty { userVideos = [] }
                hasMoreVideos = false
                isLoadingVideos = false
            }
            
            guard !Task.isCancelled else { return }
            recalculateUserStats()
        }
    }

    private func setProfileError(_ message: String) {
        errorMessage = message
        hasError = true
        isLoading = false
        isLoadingVideos = false
        print("❌ Profile error: \(message)")
        
        // 🔥 FIX: Auto-retry for network errors using a cancellable Task (no strong self capture)
        if message.contains("network") || message.contains("connection") || message.contains("timeout") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                guard !Task.isCancelled, hasError else { return }
                print("🔄 [ProfileView] Auto-retrying after network error...")
                retryLoadProfile()
            }
        }
    }

    private func retryLoadProfile() {
        // loadProfileSafely already resets hasError/errorMessage at the top
        loadProfileSafely()
    }
    
    // ⚡ PERFORMANCE: Load more videos (pagination)
    @MainActor
    private func loadMoreVideos() async {
        guard !isLoadingMoreVideos && hasMoreVideos else { return }
        
        isLoadingMoreVideos = true
        defer { isLoadingMoreVideos = false }
        
        #if canImport(FirebaseFirestore)
        do {
            guard let lastDoc = lastVideoDocument else {
                hasMoreVideos = false
                return
            }
            
            let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                creatorId: user.id,
                limit: videosPerPage,
                lastDocument: lastDoc
            )
            
            // 🔥 FIX: Deduplicate — prevent appending videos already in the list
            let existingIDs = Set(userVideos.map { $0.id })
            let newVideos = result.videos.filter { !existingIDs.contains($0.id) }
            
            userVideos.append(contentsOf: newVideos)
            lastVideoDocument = result.lastDocument
            hasMoreVideos = result.videos.count >= videosPerPage
        } catch {
            print("🚨 [ProfileView] Error loading more videos: \(error)")
            hasMoreVideos = false
        }
        #endif
    }
    
    private func toggleVideoSelection(_ videoId: String) {
        // 🔥 PREMIUM: Haptic feedback for selection
        if selectedVideoIDs.contains(videoId) {
            selectedVideoIDs.remove(videoId)
            HapticManager.shared.impact(style: .light)
        } else {
            selectedVideoIDs.insert(videoId)
            HapticManager.shared.impact(style: .medium)
        }
    }
    
    private func setVideoSelections(_ ids: [String]) {
        let availableIDs = Set(userVideos.map { $0.id })
        selectedVideoIDs = Set(ids.filter { availableIDs.contains($0) })
    }
    
    private func pruneSelectedVideoIDs() {
        guard !selectedVideoIDs.isEmpty else { return }
        let availableIDs = Set(userVideos.map { $0.id })
        selectedVideoIDs = Set(selectedVideoIDs.filter { availableIDs.contains($0) })
    }
    
    private func exitVideoManagementMode() {
        isManagingVideos = false
        selectedVideoIDs.removeAll()
    }
    
    private func deleteSelectedVideos() {
        let idsToDelete = selectedVideoIDs
        guard !idsToDelete.isEmpty else { return }
        showBulkDeleteConfirmation = false
        isBulkDeletingVideos = true
        let videosBeingDeleted = userVideos.filter { idsToDelete.contains($0.id) }
        
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for id in idsToDelete {
                        group.addTask {
                            try await VideoFirestoreService.shared.deleteVideo(videoId: id)
                            try? await DatabaseService.shared.deleteVideo(id: id)
                        }
                    }
                    try await group.waitForAll()
                }
                
                await MainActor.run {
                    for id in idsToDelete {
                        PinnedVideosStore.shared.unpin(id, for: user.id)
                        profileCache.removeVideoFromCache(id)
                        userVideos.removeAll { $0.id == id }
                    }
                    selectedVideoIDs.removeAll()
                    isManagingVideos = false
                    isBulkDeletingVideos = false
                    recalculateUserStats(propagateGlobalState: true)
                    presentUndo(.init(action: .delete(videos: videosBeingDeleted)))
                    toastManager.show("Deleted \(idsToDelete.count) video\(idsToDelete.count == 1 ? "" : "s")", type: .success)
                }
            } catch {
                await MainActor.run {
                    isBulkDeletingVideos = false
                    bulkDeleteErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleBulkAction(_ action: VideoBulkAction) {
        guard !selectedVideoIDs.isEmpty else { return }
        switch action {
        case .delete:
            showBulkDeleteConfirmation = true
        case .edit:
            showingBulkEditSheet = true
        case .visibility:
            showingBulkVisibilitySheet = true
        case .playlist:
            showingBulkPlaylistSheet = true
            Task { await loadPlaylistsIfNeeded() }
        case .download:
            startBulkDownloads()
        case .share:
            shareSelectedVideos()
        }
    }
    
    private func applyBulkVisibility(_ visibility: Video.VisibilityStatus) {
        guard !selectedVideoIDs.isEmpty else { return }
        let ids = selectedVideoIDs
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for id in ids {
                        group.addTask {
                            try await VideoFirestoreService.shared.updateVideoVisibility(videoId: id, visibility: visibility)
                        }
                    }
                    try await group.waitForAll()
                }
                await MainActor.run {
                    showingBulkVisibilitySheet = false
                    toastManager.show("Visibility updated", type: .success)
                    loadProfileSafely()
                }
            } catch {
                await MainActor.run {
                    bulkDeleteErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func applyBulkPlaylists(_ playlistIDs: Set<String>) {
        guard !playlistIDs.isEmpty else { return }
        let videoIds = selectedVideoIDs
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for playlistId in playlistIDs {
                        for videoId in videoIds {
                            group.addTask {
                                try await PlaylistFirestoreService.shared.addVideoToPlaylist(videoId: videoId, playlistId: playlistId)
                            }
                        }
                    }
                    try await group.waitForAll()
                }
                await MainActor.run {
                    showingBulkPlaylistSheet = false
                    toastManager.show("Added to \(playlistIDs.count) playlist\(playlistIDs.count == 1 ? "" : "s")", type: .success)
                }
            } catch {
                await MainActor.run {
                    bulkDeleteErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func presentUndo(_ payload: BulkUndoPayload) {
        undoPayload = payload
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                if undoPayload?.id == payload.id {
                    undoPayload = nil
                }
            }
        }
    }
    
    private func handleUndoAction(_ payload: BulkUndoPayload) {
        undoPayload = nil
        switch payload.action {
        case .delete(let videos):
            Task {
                for video in videos {
                    try? await VideoFirestoreService.shared.saveVideo(video)
                }
                await MainActor.run {
                    loadProfileSafely()
                    toastManager.show("Restored \(videos.count) video\(videos.count == 1 ? "" : "s")", type: .success)
                }
            }
        }
    }
    
    private func startBulkDownloads() {
        let videosToDownload = userVideos.filter { selectedVideoIDs.contains($0.id) }
        guard !videosToDownload.isEmpty else { return }
        
        Task {
            var successes = 0
            for video in videosToDownload {
                do {
                    try await OfflineDownloadService.shared.downloadVideo(video)
                    successes += 1
                } catch {
                    print("📥 [ProfileView] Failed to queue download for \(video.id): \(error)")
                }
            }
            
            await MainActor.run {
                toastManager.show("Queued \(successes) download\(successes == 1 ? "" : "s")", type: .success)
            }
        }
    }
    
    private func shareSelectedVideos() {
        let links = userVideos
            .filter { selectedVideoIDs.contains($0.id) }
            .map { $0.link }
        
        guard !links.isEmpty else { return }
#if canImport(UIKit)
        UIPasteboard.general.string = links.joined(separator: "\n")
#endif
        toastManager.show("Copied \(links.count) link\(links.count == 1 ? "" : "s")", type: .info)
    }
    
    private func loadPlaylistsIfNeeded() async {
        guard !isLoadingPlaylists else { return }
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        
        do {
            playlists = try await playlistService.getPlaylists(for: currentUser.id)
        } catch {
            print("⚠️ [ProfileView] Failed to load playlists: \(error)")
        }
    }
    
    // MARK: - Profile Content with Tabs
    @ViewBuilder
    private var profileContentWithTabs: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Content under tabs
                    ProfileContentSection(
                        selectedTab: $selectedTab,
                        user: user,
                        videos: userVideos,
                        onLoadMore: { await loadMoreVideos() },
                        hasMoreVideos: hasMoreVideos,
                        isLoadingMore: isLoadingMoreVideos
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
                                // 🔥 YOUTUBE PARITY: Neutral icon (not red)
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text("Open Creator Studio")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)  // 🔥 YOUTUBE PARITY: Subtle chevron
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // 🔥 HISTORY SECTION - Full YouTube Parity
                        NavigationLink(destination: WatchHistoryView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text("History")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                } header: {
                    // Absolutely flush, pinned tabs
                    ProfileTabNavigation(
                        selectedTab: $selectedTab,
                        user: user,
                        scrollOffset: scrollOffset
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

// MARK: - Helper Sections (Keep minimal - main components extracted to separate files)

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
    @Binding var selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    var onLoadMore: (() async -> Void)? = nil
    var hasMoreVideos: Bool = false
    var isLoadingMore: Bool = false
    var isLoadingVideos: Bool = false

    var body: some View {
        SafeProfileContentView(
            selectedTab: $selectedTab,
            user: user,
            videos: videos,
            onLoadMore: onLoadMore,
            hasMoreVideos: hasMoreVideos,
            isLoadingMore: isLoadingMore,
            isLoadingVideos: isLoadingVideos
        )
    }
}

// MARK: - Wrappers for sheets

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

// MARK: - Notifications used by profile sections

extension Notification.Name {
    static let openFullHistory = Notification.Name("openFullHistory")
    static let navigateToAccountSwitcher = Notification.Name("navigateToAccountSwitcher")
    static let openGoogleAccount = Notification.Name("openGoogleAccount")
}

// MARK: - Previews

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

// MARK: - View Modifier Extensions (Helps compiler type-check)

private extension View {
    
    func applyLifecycleModifiers(
        onAppearAction: @escaping () -> Void,
        onDisappearAction: @escaping () -> Void
    ) -> some View {
        self
            .onAppear {
                onAppearAction()
                print("🎥 [ProfileView] Profile page appeared")
            }
            .onDisappear {
                onDisappearAction()
            }
    }
    
    func applyUserChangeModifiers(
        authManager: AuthenticationManager,
        appState: AppState,
        handleUserChange: @escaping (User?) -> Void
    ) -> some View {
        self
            .onChange(of: authManager.currentUser) { newUser in
                handleUserChange(newUser)
            }
            .onChange(of: appState.currentUser) { newUser in
                handleUserChange(newUser)
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { note in
                if let updated = note.object as? User {
                    print("🔄 ProfileView received userProfileUpdated notification")
                    handleUserChange(updated)
                }
            }
    }
    
    func applyNotificationModifiers(
        showingSettings: Binding<Bool>,
        videoToAnalyze: Binding<Video?>,
        showingVideoAnalytics: Binding<Bool>,
        currentUser: User,
        handleVideoViewCountUpdate: @escaping (String, Int) -> Void,
        loadProfileSafely: @escaping () -> Void = {}
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
                print("🔄 ProfileView received RefreshProfile notification")
                loadProfileSafely()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenNotificationsInbox"))) { _ in
                showingSettings.wrappedValue = false
                NotificationCenter.default.post(name: Notification.Name("PresentNotificationsInbox"), object: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideoAnalytics"))) { notification in
                if let video = notification.object as? Video {
                    videoToAnalyze.wrappedValue = video
                    showingVideoAnalytics.wrappedValue = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowVideoAnalyticsInStudio"))) { notification in
                if let videoId = notification.object as? String {
                    let video = Video(
                        id: videoId,
                        title: "",
                        description: "",
                        thumbnailURL: "",
                        videoURL: "",
                        duration: 0,
                        viewCount: 0,
                        likeCount: 0,
                        creator: currentUser,
                        category: .entertainment
                    )
                    videoToAnalyze.wrappedValue = video
                    showingVideoAnalytics.wrappedValue = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let videoId = userInfo["videoId"] as? String,
                    let latestCount = userInfo["viewCount"] as? Int
                else { return }
                handleVideoViewCountUpdate(videoId, latestCount)
            }
    }
    
    func applyVideoManagementModifiers(
        userVideos: [Video],
        isManagingVideos: Bool,
        pruneSelectedVideoIDs: @escaping () -> Void,
        clearSelectedVideoIDs: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: userVideos) { _ in
                pruneSelectedVideoIDs()
            }
            .onChange(of: isManagingVideos) { isManaging in
                if !isManaging {
                    clearSelectedVideoIDs()
                }
            }
    }
    
    func applyAlertModifiers(
        showBulkDeleteConfirmation: Binding<Bool>,
        bulkDeleteErrorMessage: Binding<String?>,
        selectedVideoIDs: Set<String>,
        deleteSelectedVideos: @escaping () -> Void
    ) -> some View {
        let hasError = Binding<Bool>(
            get: { bulkDeleteErrorMessage.wrappedValue != nil },
            set: { if !$0 { bulkDeleteErrorMessage.wrappedValue = nil } }
        )
        
        return self
            .alert("Delete selected videos?", isPresented: showBulkDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedVideos()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete \(selectedVideoIDs.count) video\(selectedVideoIDs.count == 1 ? "" : "s"). This action cannot be undone.")
            }
            .alert("Couldn't delete videos", isPresented: hasError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(bulkDeleteErrorMessage.wrappedValue ?? "")
            }
    }
}
