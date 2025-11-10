//
//  ProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
    
    // ⚡ PERFORMANCE: Pagination state
    @State private var isLoadingMoreVideos = false
    @State private var hasMoreVideos = true
    @State private var lastVideoDocument: Any? = nil // Firestore DocumentSnapshot
    private let videosPerPage = 24

    @State private var scrollOffset: CGFloat = 0
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""
    
    // Video Analytics Navigation
    @State private var showingVideoAnalytics: Bool = false
    @State private var videoToAnalyze: Video?
    
    // Premium & Downloads Navigation
    @StateObject private var storeKit = StoreKitService.shared
    @State private var showingDownloads = false
    @State private var showingPremiumBenefits = false
    @State private var showingMyChannelPlus = false

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
                print("🔄 ProfileView received userProfileUpdated notification with profileImageURL: \(updated.profileImageURL ?? "nil")")
                handleUserChange(updated)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            print("🔄 ProfileView received RefreshProfile notification")
            // 🔥 IMMEDIATE REFRESH: Reload profile when video is uploaded
            loadProfileSafely()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenNotificationsInbox"))) { _ in
            showingSettings = false
            NotificationCenter.default.post(name: Notification.Name("PresentNotificationsInbox"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideoAnalytics"))) { notification in
            if let video = notification.object as? Video {
                videoToAnalyze = video
                // Show analytics immediately without delay
                showingVideoAnalytics = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowVideoAnalyticsInStudio"))) { notification in
            if let videoId = notification.object as? String {
                // Create a dummy video object for analytics
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
                videoToAnalyze = video
                showingVideoAnalytics = true
            }
        }
        .fullScreenCover(isPresented: $showingVideoAnalytics) {
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
                        videos: userVideos,
                        onLoadMore: { await loadMoreVideos() },
                        hasMoreVideos: hasMoreVideos,
                        isLoadingMore: isLoadingMoreVideos
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
                    
                    // 🎬 Creator Studio Link - BOLD & VISIBLE WITH PROPER SPACING
                    Spacer()
                        .frame(height: 32)
                    
                    NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Creator Studio")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("Manage your content")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.primary.opacity(0.15),
                                    AppTheme.Colors.primary.opacity(0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.primary.opacity(0.4), lineWidth: 2)
                        )
                        .cornerRadius(16)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // 🔥 PREMIUM & DOWNLOADS SECTION
                    VStack(spacing: 12) {
                        // Downloads (if premium)
                        if storeKit.isPremium {
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
                        }
                        
                        // Premium Benefits (if premium) or Upgrade to Plus+ (if not premium)
                        Button {
                            if storeKit.isPremium {
                                showingPremiumBenefits = true
                            } else {
                                showingMyChannelPlus = true
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                
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
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
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
                                destination: GamingView()
                            )
                            
                            // 3. Championship Hub
                            YouTubeStyleFeatureCard(
                                icon: "crown.fill",
                                title: "Championship Hub",
                                subtitle: "Belts, rankings & VS matches",
                                destination: ChampionshipHubView()
                            )
                            
                            // 4. Thumbnail Creator
                            YouTubeStyleFeatureCard(
                                icon: "photo.on.rectangle.angled",
                                title: "Thumbnail Creator",
                                subtitle: "AI-powered thumbnails",
                                destination: ThumbnailCreatorView()
                            )
                            
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
                                    subtitle: "Manage all 30 AI agents",
                                    destination: AGIAgentDashboardView(),
                                    isAdmin: true
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.bottom, 120)
                    
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
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditWrapper(user: $user)
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsWrapper()
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
                // ⚡ PERFORMANCE: Load only first page (24 videos) for faster initial load
                do {
                    let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                        creatorId: creatorId,
                        limit: videosPerPage,
                        lastDocument: nil
                    )
                    userVideos = result.videos
                    lastVideoDocument = result.lastDocument
                    hasMoreVideos = result.videos.count == videosPerPage
                    
                    // Check local storage as backup only if Firestore is empty
                    if userVideos.isEmpty {
                        if let localVids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: creatorId), !localVids.isEmpty {
                            userVideos = Array(localVids.prefix(videosPerPage))
                            hasMoreVideos = localVids.count > videosPerPage
                        }
                    }
                } catch {
                    print("🚨 [ProfileView] Error loading videos: \(error)")
                    userVideos = []
                    hasMoreVideos = false
                }
                
                // 🔥 REAL-TIME STATS UPDATE: Update user stats based on ACTUAL videos only
                // Ensure video count matches EXACTLY what's displayed - no mock data
                let actualVideoCount = userVideos.count // Use userVideos, not vids, to ensure accuracy
                let totalViews = userVideos.reduce(0) { $0 + $1.viewCount }
                
                let updatedUser = User(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    email: user.email,
                    profileImageURL: user.profileImageURL,
                    bannerImageURL: user.bannerImageURL,
                    bio: user.bio,
                    subscriberCount: user.subscriberCount,
                    videoCount: actualVideoCount, // 🔥 EXACT COUNT - matches userVideos.count
                    isVerified: user.isVerified,
                    isCreator: user.isCreator,
                    createdAt: user.createdAt,
                    location: user.location,
                    website: user.website,
                    socialLinks: user.socialLinks,
                    followerCount: user.followerCount,
                    followingCount: user.followingCount,
                    joinDate: user.joinDate,
                    totalViews: totalViews, // 🔥 REAL TOTAL VIEWS from actual videos
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

    // REMOVED: createFallbackVideos() - No more mock/fallback videos
    // Only show real videos the user has actually posted

    private func handleUserChange(_ newUser: User?) {
        print("🔄 handleUserChange called with profileImageURL: \(newUser?.profileImageURL ?? "nil")")
        DispatchQueue.main.async {
            if let newUser {
                print("🔄 Setting user state to new user with profileImageURL: \(newUser.profileImageURL ?? "nil")")
                user = newUser
                Task { @MainActor in
                    // ⚡ PERFORMANCE: Load only first page (24 videos)
                    do {
                        let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                            creatorId: newUser.id,
                            limit: videosPerPage,
                            lastDocument: nil
                        )
                        userVideos = result.videos
                        lastVideoDocument = result.lastDocument
                        hasMoreVideos = result.videos.count == videosPerPage
                        
                        // Check local storage as backup only if Firestore is empty
                        if userVideos.isEmpty {
                            if let localVids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: newUser.id), !localVids.isEmpty {
                                userVideos = Array(localVids.prefix(videosPerPage))
                                hasMoreVideos = localVids.count > videosPerPage
                            }
                        }
                    } catch {
                        print("🚨 [ProfileView] Error loading videos: \(error)")
                        userVideos = []
                        hasMoreVideos = false
                    }
                    
                    // Update user stats to match actual video count
                    var updatedUser = newUser
                    updatedUser = User(
                        id: newUser.id,
                        username: newUser.username,
                        displayName: newUser.displayName,
                        email: newUser.email,
                        profileImageURL: newUser.profileImageURL,
                        bannerImageURL: newUser.bannerImageURL,
                        bio: newUser.bio,
                        subscriberCount: newUser.subscriberCount,
                        videoCount: userVideos.count, // 🔥 EXACT COUNT
                        isVerified: newUser.isVerified,
                        isCreator: newUser.isCreator,
                        createdAt: newUser.createdAt,
                        location: newUser.location,
                        website: newUser.website,
                        socialLinks: newUser.socialLinks,
                        followerCount: newUser.followerCount,
                        followingCount: newUser.followingCount,
                        joinDate: newUser.joinDate,
                        totalViews: userVideos.reduce(0) { $0 + $1.viewCount }, // 🔥 REAL TOTAL VIEWS
                        totalEarnings: newUser.totalEarnings,
                        membershipTiers: newUser.membershipTiers,
                        bannerVideoURL: newUser.bannerVideoURL,
                        bannerVideoMuted: newUser.bannerVideoMuted,
                        bannerVideoContentMode: newUser.bannerVideoContentMode
                    )
                    user = updatedUser
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
    
    // ⚡ PERFORMANCE: Load more videos (pagination)
    private func loadMoreVideos() async {
        guard !isLoadingMoreVideos && hasMoreVideos else { return }
        
        isLoadingMoreVideos = true
        defer { isLoadingMoreVideos = false }
        
        #if canImport(FirebaseFirestore)
        do {
            guard let lastDoc = lastVideoDocument as? DocumentSnapshot else {
                hasMoreVideos = false
                return
            }
            
            let result = try await VideoFirestoreService.shared.fetchVideosByCreatorPaginated(
                creatorId: user.id,
                limit: videosPerPage,
                lastDocument: lastDoc
            )
            
            await MainActor.run {
                userVideos.append(contentsOf: result.videos)
                lastVideoDocument = result.lastDocument
                hasMoreVideos = result.videos.count == videosPerPage
            }
        } catch {
            print("🚨 [ProfileView] Error loading more videos: \(error)")
            await MainActor.run { hasMoreVideos = false }
        }
        #endif
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
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state

    var body: some View {
        SafeProfileContentView(
            selectedTab: selectedTab,
            user: user,
            videos: videos,
            onLoadMore: onLoadMore,
            hasMoreVideos: hasMoreVideos,
            isLoadingMore: isLoadingMore
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

// MARK: - YouTube-Style Feature Card Component
struct YouTubeStyleFeatureCard<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: Destination
    var isAdmin: Bool = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon (YouTube-style: neutral background, subtle)
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isAdmin {
                            Text("ADMIN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red, in: Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron (YouTube-style: subtle)
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
        .buttonStyle(PlainButtonStyle())
    }
}