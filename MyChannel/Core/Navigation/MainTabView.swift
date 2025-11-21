//
//  MainTabView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - Preview-Safe Main Tab View
struct MainTabView: View {
    // Simple environment object access without complex initialization
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @StateObject private var inbox = NotificationsInboxService.shared
    
    @State private var selectedTab: TabItem = .home
    @State private var previousTab: TabItem = .home
    @State private var showingUpload: Bool = false
    @State private var isInitialized: Bool = false
    @State private var presentMiniPlayerDetail: Bool = false
    @State private var presentGlobalNowPlaying: Bool = false
    @State private var presentNotificationsInbox: Bool = false
    
    @State private var notificationBadges: [TabItem: Int] = [:]
    private let tabBarReservedBottomInset: CGFloat = 72
    
    // Error handling state
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""

    @State private var presentAccountSwitcher: Bool = false
    @State private var presentGoogleAccount: Bool = false
    @State private var presentSignInSheet: Bool = false
    @State private var presentFullHistory: Bool = false
    @State private var historyVideoToOpen: Video? = nil
    @State private var showAuthGate: Bool = false
    
    // Creator Studio (for video analytics)
    @State private var showingCreatorStudio: Bool = false
    @State private var videoIdForStudio: String?

    var body: some View {
        ZStack {
            if hasError {
                errorView
            } else {
                mainContent
                    .environmentObject(globalPlayer)
                    .overlay(alignment: .topLeading) {
                        if let player = globalPlayer.player {
                            PlayerPiPContainerView(
                                player: player,
                                isPictureInPictureActive: Binding(
                                    get: { globalPlayer.isPiPActive },
                                    set: { globalPlayer.isPiPActive = $0 }
                                )
                            )
                            .frame(width: 0, height: 0)
                            .hidden()
                        }
                    }
            }
        }
        .onAppear {
            setupInitialState()
            if let uid = authManager.currentUser?.id { inbox.listen(userId: uid) }
        }
        .onChange(of: authManager.currentUser) { newValue in
            print("🔄 MainTabView: authManager.currentUser changed to profileImageURL: \(newValue?.profileImageURL ?? "nil")")
            safeUserStateSync(newValue)
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: inbox.items) { items in
            let unread = items.filter { !$0.read }.count
            notificationBadges[.profile] = unread
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSearchTab"))) { _ in
            selectedTab = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfileTab"))) { _ in
            UIApplication.shared.endEditing()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = .profile
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowUpload"))) { _ in
            showingUpload = true
        }
        .onChange(of: globalPlayer.fullscreenRequestToken) { _ in
            // Additional safety: always honor fullscreen requests from the mini player,
            // even if a notification is missed.
            guard globalPlayer.showingFullscreen else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                presentMiniPlayerDetail = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopProfile)) { _ in
            // Handle scroll to top for profile
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentVideoDetailFromMiniPlayer"))) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                presentMiniPlayerDetail = true
            }
        }
        // Present video detail only when triggered by mini player event
        .fullScreenCover(isPresented: $presentMiniPlayerDetail) {
            if let video = globalPlayer.currentVideo {
                ZStack {
                    // 🔥 FIX: Black background to prevent white screen flash
                    Color.black.ignoresSafeArea()
                    
                    VideoDetailView(video: video)
                        .onAppear {
                            print("📺 [MainTabView] VideoDetailView appeared from mini player")
                            
                            // 🔥 CRITICAL: Ensure fullscreen state is set IMMEDIATELY and isTransitioning is still true
                            // This prevents mini player, PiP, and any other UI from showing
                            globalPlayer.showingFullscreen = true
                            globalPlayer.shouldShowMiniPlayer = false
                            globalPlayer.isMiniplayer = false
                            // Keep isTransitioning true until player is ready
                            
                            print("✅ [MainTabView] Fullscreen state set - showingFullscreen: \(globalPlayer.showingFullscreen), shouldShowMiniPlayer: \(globalPlayer.shouldShowMiniPlayer), isTransitioning: \(globalPlayer.isTransitioning)")
                            
                            // 🔥 FIX: Ensure player is properly set up BEFORE view appears
                            // This prevents white screen flash
                            if let player = globalPlayer.player {
                                print("✅ [MainTabView] Player exists and is ready")
                                
                                // Ensure player is playing if it was playing before
                                if globalPlayer.isPlaying && player.rate == 0 {
                                    print("▶️ [MainTabView] Resuming playback")
                                    player.play()
                                }
                            } else {
                                print("⚠️ [MainTabView] Player is nil - setting up new player")
                                // Player was lost - set it up again
                                globalPlayer.exposedPlayerManager?.setupPlayer(with: video)
                                
                                // Wait for player to be ready
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if let player = globalPlayer.player {
                                        if globalPlayer.isPlaying {
                                            player.play()
                                        }
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            print("📺 [MainTabView] VideoDetailView disappeared")
                            
                            // 🔥 FIX: Only restore mini player if user is actually dismissing (not going to fullscreen)
                            if globalPlayer.currentVideo != nil && !globalPlayer.showingFullscreen {
                                globalPlayer.showingFullscreen = false
                                globalPlayer.shouldShowMiniPlayer = true
                                globalPlayer.isMiniplayer = true
                            }
                        }
                }
            } else {
                // 🔥 FIX: Fallback if video is nil (shouldn't happen, but prevent white screen)
                Color.black.ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .onAppear {
                        print("⚠️ [MainTabView] No video available - dismissing")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentMiniPlayerDetail = false
                        }
                    }
            }
        }
        .ignoresSafeArea(.keyboard)

        .onReceive(NotificationCenter.default.publisher(for: .navigateToAccountSwitcher)) { _ in
            presentAccountSwitcher = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGoogleAccount)) { _ in
            presentGoogleAccount = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentSignInSheet)) { _ in
            presentSignInSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFullHistory)) { _ in
            if appState.requireAuthentication(hint: "Sign in to view your watch history.") {
                presentFullHistory = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenVideoEditor"))) { note in
            if let video = note.object as? Video {
                // Reuse UploadView in edit mode by preloading the video URL and jumping to the details step
                // We signal via AppState and a dedicated notification to keep coupling low
                NotificationCenter.default.post(name: Notification.Name("PresentUploadEditorForVideo"), object: video)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVideoFromHistory)) { note in
            if let video = note.object as? Video {
                historyVideoToOpen = video
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideo"))) { notification in
            if let video = notification.object as? Video {
                // Open video directly to play it
                historyVideoToOpen = video
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentGlobalNowPlayingSheet"))) { _ in
            presentGlobalNowPlaying = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentNotificationsInbox"))) { _ in
            presentNotificationsInbox = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenVideoAnalytics"))) { notification in
            if let video = notification.object as? Video {
                // Open Creator Studio focused on this video's analytics
                videoIdForStudio = video.id
                showingCreatorStudio = true
            }
        }
        .fullScreenCover(isPresented: $showingCreatorStudio) {
            ComprehensiveCreatorStudioView(videoId: videoIdForStudio)
                .environmentObject(authManager)
                .environmentObject(appState)
        }
        // Remove global auth flow listener to prevent unintended popups
        .sheet(isPresented: $presentAccountSwitcher) {
            AccountSwitcherView()
        }
        .sheet(isPresented: $presentGoogleAccount) { GoogleAccountView() }
        .sheet(isPresented: $presentSignInSheet) { SignInSheetView() }
        .fullScreenCover(isPresented: $presentFullHistory) {
            WatchHistoryView()
        }
        .sheet(isPresented: $presentGlobalNowPlaying) {
            NowPlayingSheet()
        }
        .fullScreenCover(isPresented: $presentNotificationsInbox) {
            NotificationsInboxView()
        }
        .fullScreenCover(item: $historyVideoToOpen) { video in
            VideoDetailView(video: video)
        }
        // Auth gate: if user selects profile while unauthenticated
        .fullScreenCover(isPresented: $showAuthGate, onDismiss: {
            if authManager.isAuthenticated {
                selectedTab = .profile
            } else {
                selectedTab = .home
            }
        }) {
            AuthenticationView()
        }
        // Ensure mini-player pauses on Flicks, resumes otherwise (covers programmatic tab changes too)
        .onChange(of: selectedTab) { newTab in
            if newTab == .flicks {
                GlobalVideoPlayerManager.shared.pauseForFlicksEngagement()
            } else {
                GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
            }
        }
        // 🔥 AUTO PiP: Start Picture-in-Picture when app goes to background
        // 🔥 FIX: Close mini-player when app is fully backgrounded (not just inactive)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                // 🔥 FIX: Close mini-player when app goes to background
                // This prevents mini-player from persisting when app is reopened
                if globalPlayer.shouldShowMiniPlayer,
                   globalPlayer.currentVideo != nil {
                    // If video is playing, try PiP first
                    if let player = globalPlayer.player, player.rate > 0 {
                        // Try to start PiP
                        Task { @MainActor in
                            await globalPlayer.startPiPWhenBackgrounding()
                        }
                    } else {
                        // Video is paused - just close mini-player
                        globalPlayer.closePlayer()
                        print("🔄 [MainTabView] App backgrounded with paused video - closing mini-player")
                    }
                }
            } else if newPhase == .active {
                // 🔥 FIX: When app becomes active, only restore mini-player if PiP was active
                if globalPlayer.isPiPActive {
                    print("🔄 [MainTabView] App became active - restoring from PiP")
                } else if globalPlayer.shouldShowMiniPlayer {
                    // Mini-player was showing but no PiP - clear it
                    print("🔄 [MainTabView] App became active - clearing stale mini-player state")
                    globalPlayer.shouldShowMiniPlayer = false
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        ErrorView(message: errorMessage) {
            hasError = false
            errorMessage = ""
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Main Content
            SafeContentView(selectedTab: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
                .zIndex(5)
                .allowsHitTesting(true)
                .safeAreaInset(edge: .bottom) {
                    // Reserve space so scrollable content does not sit beneath the flush tab bar
                    VStack(spacing: 8) {
                        // Hide weak mini player and audio bar when using the advanced inline player or video mini-player
                        if !globalPlayer.shouldShowMiniPlayer && !globalPlayer.showingFullscreen {
                            GlobalNowPlayingBar()
                        }
                        // Always keep tab bar reserve (no extra space for PiP)
                        Color.clear.frame(height: tabBarReservedBottomInset)
                    }
                }
            // 🔥 FIX: Tab bar properly positioned at bottom
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: $selectedTab,
                    notificationBadges: notificationBadges,
                    isHidden: false,
                    onUploadTap: {
                        if appState.requireAuthentication(hint: "Sign in to upload videos.") {
                            showingUpload = true
                        }
                    },
                    onTabSelected: handleTabSelection
                )
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(999)  // Tab bar below mini player
            .allowsHitTesting(true)
            
            // 🔥 FIX: Show VISIBLE mini player (not PiP-only)
            if globalPlayer.shouldShowMiniPlayer,
               !globalPlayer.showingFullscreen,
               !globalPlayer.isTransitioning,
               globalPlayer.currentVideo != nil {
                SafeFloatingMiniPlayer()
                    .environmentObject(globalPlayer)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showingUpload) {
            SafeUploadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PresentUploadEditorForVideo"))) { note in
            if let video = note.object as? Video {
                showingUpload = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: Notification.Name("StartUploadEditorWithExistingVideo"), object: video)
                }
            }
        }
    }
    
    // MARK: - Safe Methods
    private func setupInitialState() {
        guard !isInitialized else { return }
        
        do {
            // 🔥 CRITICAL FIX: Clear all mini-player state on app launch
            // This prevents stale mini-player from showing
            print("🔄 [MainTabView] setupInitialState - Clearing stale mini-player state")
            globalPlayer.shouldShowMiniPlayer = false
            globalPlayer.isMiniplayer = false
            globalPlayer.showingFullscreen = false
            globalPlayer.isTransitioning = false
            
            // 🔥 CRITICAL FIX: If there's a video but no active player, clear the video too
            if globalPlayer.currentVideo != nil && globalPlayer.player == nil {
                print("⚠️ [MainTabView] Found stale video with no player - clearing")
                globalPlayer.currentVideo = nil
            }
            
            // Initialize notification badges safely
            notificationBadges = [
                .home: 0,
                .flicks: 2,
                .upload: 0,
                .search: 0,
                .profile: 3
            ]
            
            // Sync user state safely
            appState.currentUser = authManager.currentUser
            isInitialized = true

            // Ensure correct initial preview state
            if selectedTab == .home {
                NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
            }
        } catch {
            handleError("Failed to initialize app state: \(error.localizedDescription)")
        }
    }
    
    private func safeUserStateSync(_ newUser: User?) {
        DispatchQueue.main.async {
            print("🔄 MainTabView: Setting appState.currentUser to profileImageURL: \(newUser?.profileImageURL ?? "nil")")
            appState.currentUser = newUser
        }
    }
    
    private func handleTabSelection(_ tab: TabItem) {
        guard tab != .upload else { return }
        
        do {
            // Immediately drop any keyboard/search focus before switching
            NotificationCenter.default.post(name: NSNotification.Name("SearchLoseFocus"), object: nil)
            UIApplication.shared.endEditing()
            
            let targetTab = tab
            let wasSameTab = (targetTab == selectedTab)
            previousTab = selectedTab

            // Pause mini-player when entering Flicks; resume when leaving
            if targetTab == .flicks {
                GlobalVideoPlayerManager.shared.pauseForFlicksEngagement()
            } else {
                GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
            }

            // Switch tabs on the next runloop tick so the focus change doesn't eat the tap
            DispatchQueue.main.async {
                var tx = SwiftUI.Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    selectedTab = targetTab
                }
                
                // If switching TO search, explicitly focus the field after selection
                if targetTab == .search {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(name: NSNotification.Name("FocusSearchBar"), object: nil)
                    }
                } else if targetTab == .profile && !authManager.isAuthenticated {
                    // Do not auto-present auth; let ProfileView show the lightweight prompt
                }
            }

            // Handle reselection behaviors without blocking the switch
            if wasSameTab {
                handleTabReselection(targetTab)
            }
            
            notificationBadges[targetTab] = 0
            
            Task { @MainActor in
                try? await AnalyticsService.shared.trackScreenView(targetTab.title)
            }
        } catch {
            handleError("Tab selection error: \(error.localizedDescription)")
        }
    }
    
    private func handleTabReselection(_ tab: TabItem) {
        switch tab {
        case .home:
            NotificationCenter.default.post(name: NSNotification.Name("HomeScrollToTop"), object: nil)
        case .flicks:
            NotificationCenter.default.post(name: NSNotification.Name("FlicksResetToFirst"), object: nil)
        case .search:
            NotificationCenter.default.post(name: NSNotification.Name("SearchClearAndReset"), object: nil)
        case .subscriptions:
            break
        case .profile:
            break
        case .upload:
            break
        }
        
        if tab != .profile {
            HapticManager.shared.impact(style: .medium)
        }
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            hasError = true
        }
    }
    
    private func cleanup() {
        print("🧹 MainTabView cleanup called")
    }
}

// MARK: - Safe Content View
struct SafeContentView: View {
    let selectedTab: TabItem
    
    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                SafeHomeView()
            case .subscriptions:
                NavigationStack { SubscriptionsView() }
            case .flicks:
                // Embed Flicks inside the tab with embedded flag on
                ErrorBoundary {
                    NuclearFlicksView()
                } fallback: {
                    if #available(iOS 17.0, *) {
                        return AnyView(
                            ContentUnavailableView(
                                "Flicks Unavailable",
                                systemImage: "play.slash",
                                description: Text("Please try again later")
                            )
                        )
                    } else {
                        return AnyView(
                            VStack(spacing: 12) {
                                Image(systemName: "play.slash").font(.largeTitle)
                                Text("Flicks Unavailable").font(.headline)
                                Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.Colors.background)
                        )
                    }
                }
            case .search:
                SafeSearchView()
            case .profile:
                NavigationView {
                    ProfileView()
                }
            case .upload:
                EmptyView()
            }
        }
        .transition(.identity)
    }
}

// MARK: - Safe View Wrappers
struct SafeHomeView: View {
    var body: some View {
        ErrorBoundary {
            HomeView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Home Unavailable",
                        systemImage: "house.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "house.slash").font(.largeTitle)
                        Text("Home Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeFlicksView: View {
    var body: some View {
        ErrorBoundary {
            FlicksView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Flicks Unavailable",
                        systemImage: "play.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "play.slash").font(.largeTitle)
                        Text("Flicks Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeSearchView: View {
    var body: some View {
        ErrorBoundary {
            SearchView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Search Unavailable",
                        systemImage: "magnifyingglass.circle.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle.slash").font(.largeTitle)
                        Text("Search Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeProfileView: View {
    var body: some View {
        ErrorBoundary {
            ProfileView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Profile Unavailable",
                        systemImage: "person.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash").font(.largeTitle)
                        Text("Profile Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeUploadView: View {
    var body: some View {
        ErrorBoundary {
            UploadView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Upload Unavailable",
                        systemImage: "plus.circle.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.slash").font(.largeTitle)
                        Text("Upload Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeFloatingMiniPlayer: View {
    var body: some View {
        ErrorBoundary {
            FloatingMiniPlayer()
        } fallback: {
            EmptyView()
        }
    }
}

// MARK: - Error Boundary
struct ErrorBoundary<Content: View, Fallback: View>: View {
    let content: () -> Content
    let fallback: () -> Fallback
    
    @State private var hasError = false
    
    var body: some View {
        Group {
            if hasError {
                fallback()
            } else {
                content()
                    .onAppear {
                        hasError = false
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ViewError"))) { _ in
            hasError = true
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(TabErrorButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Tab Error Button Style
struct TabErrorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Notification Model
struct AppNotification: Identifiable {
    let id = UUID().uuidString
    let title: String
    let message: String
    let type: NotificationType
    let timestamp: Date
    let isRead: Bool

    enum NotificationType {
        case like, comment, follow, upload, system

        var iconName: String {
            switch self {
            case .like: return "heart.fill"
            case .comment: return "bubble.right.fill"
            case .follow: return "person.badge.plus"
            case .upload: return "arrow.up.circle.fill"
            case .system: return "bell.fill"
            }
        }
    }
}

// MARK: - Tab Bar
enum TabItem: String, CaseIterable, Hashable {
    case home, subscriptions, flicks, upload, search, profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .subscriptions: return "Subscriptions"
        case .flicks: return "Flicks"
        case .upload: return "Create"
        case .search: return "Search"
        case .profile: return "You"
        }
    }

    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home: return isSelected ? "house.fill" : "house"
        case .subscriptions: return isSelected ? "bell.fill" : "bell"
        case .flicks: return isSelected ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle"
        case .upload: return "plus"
        case .search: return "magnifyingglass"
        case .profile: return isSelected ? "person.fill" : "person"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home: return "Home tab"
        case .subscriptions: return "Subscriptions tab"
        case .flicks: return "Flicks tab"
        case .upload: return "Create content"
        case .search: return "Search tab"
        case .profile: return "Profile tab"
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let isHidden: Bool
    let onUploadTap: () -> Void
    let onTabSelected: (TabItem) -> Void
    
    // Separate tabs into main group and profile. When Home is selected, show it as a separated button on the left.
    private var mainTabs: [TabItem] {
        if selectedTab == .home {
            return [.subscriptions, .flicks, .search]
        } else {
            return [.home, .subscriptions, .flicks, .search]
        }
    }
    
    var body: some View {
        HStack(spacing: (selectedTab == .profile || selectedTab == .home) ? 16 : 0) {
            // Separated Home Button (only when home is selected)
            if selectedTab == .home {
                SeparatedHomeButton(
                    isSelected: true,
                    action: { onTabSelected(.home) }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            // Main tab group (Home, Flicks, Upload, Search)
            HStack(spacing: 0) {
                ForEach(mainTabs, id: \.self) { tab in
                    CustomTabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        badgeCount: notificationBadges[tab] ?? 0,
                        action: {
                            onTabSelected(tab)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    
                    // Add upload button after flicks
                    if tab == .flicks {
                        UploadTabButton(action: onUploadTap)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Add profile button when connected (not on profile tab)
                if selectedTab != .profile {
                    ConnectedProfileButton(
                        isSelected: false,
                        badgeCount: notificationBadges[.profile] ?? 0,
                        action: {
                            onTabSelected(.profile)
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Capsule()
                        .fill(Color.white)
                    Capsule()
                        .stroke(AppTheme.Colors.textSecondary.opacity(0.08), lineWidth: 0.5)
                }
            )
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 16,
                x: 0,
                y: 8
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 4,
                x: 0,
                y: 2
            )
            
            // Separated Profile Button (only when profile is selected)
            if selectedTab == .profile {
                SeparatedProfileButton(
                    isSelected: true,
                    badgeCount: notificationBadges[.profile] ?? 0,
                    action: {
                        onTabSelected(.profile)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Connected Profile Button (when in main tab bar)
struct ConnectedProfileButton: View {
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: TabItem.profile.iconName(isSelected: isSelected))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
                            .frame(height: 32)

                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 10, y: -6)
                        }
                    }
                }
                .frame(height: 32)
            }
            .frame(height: 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.95))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TabItem.profile.accessibilityLabel)
        .accessibilityHint("Opens your profile")
    }
}

// MARK: - Separated Profile Button
struct SeparatedProfileButton: View {
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                    } else {
                        Circle()
                            .fill(Color.white)
                    }
                }
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(
                                AppTheme.Colors.textSecondary.opacity(0.08),
                                lineWidth: 0.5
                            )
                    )
                
                ZStack(alignment: .topTrailing) {
                    Image(systemName: TabItem.profile.iconName(isSelected: isSelected))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)

                    if badgeCount > 0 {
                        NotificationBadge(count: badgeCount)
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.95))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .shadow(
            color: Color.black.opacity(isSelected ? 0.2 : 0.1),
            radius: isSelected ? 12 : 8,
            x: 0,
            y: isSelected ? 6 : 4
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TabItem.profile.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Opens your profile")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Separated Home Button (mirrors profile style, left-aligned)
struct SeparatedHomeButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(AppTheme.Colors.primary)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                
                Image(systemName: TabItem.home.iconName(isSelected: isSelected))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.95))
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TabItem.home.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Open Home")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Upload Tab Button
struct UploadTabButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(style: .medium)
        }) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.3),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.94))
        .accessibilityLabel("Create content")
        .accessibilityHint("Open the upload flow")
    }
}

// MARK: - Custom Tab Bar Button
struct CustomTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 48, height: 32)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: tab.iconName(isSelected: isSelected))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(
                                isSelected ? .white : AppTheme.Colors.textSecondary
                            )
                        
                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 10, y: -6)
                        }
                    }
                }
                .frame(height: 32)
            }
            .frame(height: 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.95))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Open \(tab.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Notification Badge
struct NotificationBadge: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.primary)
                .frame(width: 16, height: 16)
            
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Preview-Safe Wrapper for App Injection
struct PreviewSafeMainTabWrapper: View {
    var body: some View {
        MainTabView()
            .environmentObject(createSafeAuthManager())
            .environmentObject(createSafeAppState())
            .environmentObject(createSafeVideoPlayerManager())
    }
    
    private func createSafeAuthManager() -> AuthenticationManager {
        let manager = AuthenticationManager.shared
        let avatar = (UIImage(named: "UserProfileAvatar") != nil) ? "asset://UserProfileAvatar" : "https://picsum.photos/200/200"
        manager.currentUser = User(
            username: "preview_user",
            displayName: "Preview User",
            email: "preview@mychannel.com",
            profileImageURL: avatar,
            bio: "Preview user for testing"
        )
        return manager
    }
    
    private func createSafeAppState() -> AppState {
        let state = AppState()
        let avatar = (UIImage(named: "UserProfileAvatar") != nil) ? "asset://UserProfileAvatar" : "https://picsum.photos/200/200"
        state.currentUser = User(
            username: "preview_user",
            displayName: "Preview User",
            email: "preview@mychannel.com",
            profileImageURL: avatar,
            bio: "Preview user for testing"
        )
        return state
    }
    
    private func createSafeVideoPlayerManager() -> GlobalVideoPlayerManager {
        return GlobalVideoPlayerManager.shared
    }
}

// MARK: - Simple Preview Alternative
struct SimpleMainTabPreview: View {
    @State private var selectedTab: TabItem = .home
    
    var body: some View {
        VStack {
            // Simple content area
            ZStack {
                switch selectedTab {
                case .home:
                    VStack {
                        Image(systemName: "house.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Home")
                            .font(AppTheme.Typography.title2)
                    }
                case .flicks:
                    VStack {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Flicks")
                            .font(AppTheme.Typography.title2)
                    }
                case .search:
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Search")
                            .font(AppTheme.Typography.title2)
                    }
                case .subscriptions:
                    VStack {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Subscriptions")
                            .font(AppTheme.Typography.title2)
                    }
                case .profile:
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Profile")
                            .font(AppTheme.Typography.title2)
                    }
                case .upload:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            
            // Simple tab bar
            HStack {
                ForEach(TabItem.allCases.filter { $0 != .upload }, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack {
                            Image(systemName: tab.iconName(isSelected: selectedTab == tab))
                                .font(.title2)
                            Text(tab.title)
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if tab == .flicks {
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(AppTheme.Colors.primary))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

struct ProfileGlitchIconView: View {
    let isSelected: Bool
    let size: CGFloat

    @EnvironmentObject private var appState: AppState

    @State private var showAvatar = false
    @State private var glitchActive = false
    @State private var turningOff = false
    @State private var jitter: CGSize = .zero
    @State private var loopTask: Task<Void, Never>? = nil

    private var baseIconColor: Color {
        isSelected ? .white : AppTheme.Colors.textSecondary
    }

    private var avatarURL: String? {
        appState.currentUser?.profileImageURL
    }

    var body: some View {
        ZStack {
            Image(systemName: TabItem.profile.iconName(isSelected: isSelected))
                .font(.system(size: size, weight: .medium))
                .foregroundColor(baseIconColor)
                .opacity(showAvatar ? 0 : 1)
                .offset(jitter)

            Group {
                if let url = avatarURL, !url.isEmpty {
                    ProfileAvatarView(urlString: url, size: size + 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: size + 8, height: size + 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                }
            }
            .scaleEffect(y: turningOff ? 0.04 : 1.0, anchor: .center)
            .opacity(showAvatar ? 1 : 0)
            .offset(jitter)
            .animation(.easeInOut(duration: turningOff ? 0.18 : 0.12), value: turningOff)

            TVStaticOverlay(isActive: glitchActive)
                .clipShape(Circle())
                .frame(width: max(size + 12, 28), height: max(size + 12, 28))
                .opacity(glitchActive ? 1 : 0)
                .allowsHitTesting(false)
        }
        .onAppear { startLoop() }
        .onDisappear { loopTask?.cancel() }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await glitchIn()

                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await glitchOut()
            }
        }
    }

    @MainActor
    private func glitchIn() async {
        glitchActive = true
        animateJitter()
        try? await Task.sleep(nanoseconds: 250_000_000)

        withAnimation(.easeOut(duration: 0.12)) {
            showAvatar = true
        }
        glitchActive = false
        resetJitter()
    }

    @MainActor
    private func glitchOut() async {
        glitchActive = true
        animateJitter()
        try? await Task.sleep(nanoseconds: 220_000_000)

        turningOff = true
        try? await Task.sleep(nanoseconds: 180_000_000)

        withAnimation(.easeInOut(duration: 0.12)) {
            showAvatar = false
        }
        turningOff = false
        glitchActive = false
        resetJitter()
    }

    private func animateJitter() {
        withAnimation(.linear(duration: 0.06).repeatForever(autoreverses: true)) {
            jitter = CGSize(width: 0.8, height: -0.8)
        }
    }

    private func resetJitter() {
        withAnimation(.linear(duration: 0.08)) {
            jitter = .zero
        }
    }
}

struct TVStaticOverlay: View {
    let isActive: Bool

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: Date.now, by: 0.1)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let seed = Int(t * 60) % 10

            ZStack {
                ForEach(0..<max(8, 12 + seed), id: \.self) { _ in
                    let w = CGFloat(Int.random(in: 6...18))
                    let h = CGFloat(Int.random(in: 1...3))
                    let x = CGFloat.random(in: -6...6)
                    let y = CGFloat.random(in: -10...10)
                    Rectangle()
                        .fill([.white.opacity(0.7), .black.opacity(0.6), .gray.opacity(0.5)].randomElement()!)
                        .frame(width: w, height: h)
                        .offset(x: x, y: y)
                        .blendMode(.screen)
                }

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.15), location: 0.48),
                        .init(color: .white.opacity(0.85), location: 0.5),
                        .init(color: .white.opacity(0.15), location: 0.52)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.6)
            }
            .opacity(isActive ? 1 : 0)
            .animation(.linear(duration: 0.08), value: seed)
        }
    }
}

// MARK: - Preview
#Preview("Simple Tab Preview") {
    SimpleMainTabPreview()
        .preferredColorScheme(.light)
}

#Preview("MainTabView - Preview Safe") {
    // Create a minimal version that definitely won't crash
    VStack {
        // Header
        HStack {
            Image("MyChannel")
                .resizable()
                .frame(width: 36, height: 36)
                .cornerRadius(18)
            
            VStack(alignment: .leading) {
                Text("MyChannel")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                
                Text("Video Streaming Platform")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        
        Spacer()
        
        // Center content
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("MyChannel Tab View")
                .font(AppTheme.Typography.title1)
                .fontWeight(.bold)
            
            Text("Professional video streaming interface")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        
        Spacer()
        
        // Bottom tab bar preview
        HStack {
            ForEach(TabItem.allCases.filter { $0 != .upload }, id: \.self) { tab in
                VStack(spacing: 4) {
                    Image(systemName: tab.iconName(isSelected: tab == .home))
                        .font(.title2)
                    Text(tab.title)
                        .font(.caption)
                }
                .foregroundColor(tab == .home ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                
                if tab == .flicks {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(24)
        .padding()
    }
    .background(AppTheme.Colors.background)
}

extension UIApplication {
    func endEditing(_ force: Bool = true) {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}