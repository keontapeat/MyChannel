//
//  MainTabView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import FirebaseAuth

// MARK: - Preview-Safe Main Tab View
struct MainTabView: View {
    // Simple environment object access without complex initialization
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var globalPlayer: GlobalVideoPlayerManager
    @StateObject private var inbox: NotificationsInboxService = {
        let service = NotificationsInboxService.shared
        print("📨 [MainTabView] Inbox service initialized")
        return service
    }()
    
    @State private var selectedTab: TabItem = .home
    @State private var previousTab: TabItem = .home
    @State private var showingUpload: Bool = false
    @State private var showingCreatePicker: Bool = false
    @State private var showingFlickUpload: Bool = false
    @State private var showingGoLive: Bool = false
    @State private var showingCreatePost: Bool = false
    @State private var isInitialized: Bool = false
    @State private var presentGlobalNowPlaying: Bool = false
    @State private var presentNotificationsInbox: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var notificationBadges: [TabItem: Int] = [:]
    private let tabBarReservedBottomInset: CGFloat = 72
    
    // Error handling state
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""

    @State private var presentAccountSwitcher: Bool = false
    @State private var presentGoogleAccount: Bool = false
    @State private var presentSignInSheet: Bool = false
    @State private var presentFullHistory: Bool = false
    @State private var presentHistoryManagement: Bool = false
    @State private var historyVideoToOpen: Video? = nil
    @State private var showAuthGate: Bool = false
    
    // Creator Studio (for video analytics)
    @State private var showingCreatorStudio: Bool = false
    @State private var videoIdForStudio: String?

    var body: some View {
        ZStack {
            if authManager.authState == .banned {
                AccountBlockedView(
                    title: "Account Permanently Removed",
                    message: "Your account has been permanently banned from MyChannel for violating our Community Guidelines. This decision is final.",
                    icon: "xmark.octagon.fill",
                    iconColor: .red
                )
            } else if authManager.authState == .suspended {
                AccountBlockedView(
                    title: "Account Suspended",
                    message: authManager.suspendedUntil.map {
                        "Your account has been suspended until \($0.formatted(date: .long, time: .omitted)). Please review our Community Guidelines before returning."
                    } ?? "Your account has been temporarily suspended. Please review our Community Guidelines.",
                    icon: "pause.circle.fill",
                    iconColor: .orange
                )
            } else if hasError {
                errorView
            } else {
                mainContent
                    // 🔥 Native iOS PiP ONLY: Custom mini player removed, using native PiP everywhere
            }
        }
        .onAppear {
            setupInitialState()
            
            // Delay inbox fetch slightly to avoid blocking launch
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let uid = authManager.currentUser?.id {
                    try? await inbox.fetchNotifications(userId: uid)
                    print("📨 [MainTabView] Started inbox listener for user: \(uid)")
                }
            }
        }
        .onChange(of: authManager.currentUser) { newValue in
            handleAuthUserChange(newValue)
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: inbox.unreadCount) { unread in
            updateProfileBadge(unread)
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
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopProfile)) { _ in
            // Handle scroll to top for profile
        }
        // 🔥 Native PiP: User tapped PiP window - expand to fullscreen
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentVideoDetail"))) { notification in
            print("📺 [MainTabView] Received PresentVideoDetail - opening fullscreen")
            if let video = notification.object as? Video {
                historyVideoToOpen = video
            } else if let video = globalPlayer.currentVideo {
                historyVideoToOpen = video
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenHistoryManagement"))) { _ in
            if appState.requireAuthentication(hint: "Sign in to manage your watch history.") {
                presentHistoryManagement = true
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
        .sheet(isPresented: $presentHistoryManagement) {
            HistoryManagementView()
                .environmentObject(appState)
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
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
            if showAuthGate { showAuthGate = false }
            if presentSignInSheet { presentSignInSheet = false }
        }
        // 🔥 FIX 2.1(a): Dismiss ALL auth UI when sign-in succeeds (belt-and-suspenders)
        .onChange(of: authManager.isAuthenticated) { isAuth in
            if isAuth {
                if showAuthGate { showAuthGate = false }
                if presentSignInSheet { presentSignInSheet = false }
            }
        }
        // Ensure mini-player pauses on Flicks, resumes otherwise (covers programmatic tab changes too)
        .onChange(of: selectedTab) { newTab in
            handleSelectedTabChange(newTab)
        }
        // 🔥 AUTO PiP logging: GlobalVideoPlayerManager handles the transitions
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        ErrorView(message: errorMessage) {
            hasError = false
            errorMessage = ""
        }
    }
    
    private var shouldShowiPadSidebar: Bool {
        // Show sidebar on iPad with regular size class (full-screen iPad)
        // Falls back to bottom tab bar in Slide Over / Stage Manager compact mode
        iPadLayout.isIPad && horizontalSizeClass == .regular
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if shouldShowiPadSidebar {
            HStack(spacing: 0) {
                // Left Sidebar (YouTube iPad parity)
                iPadSidebar(
                    selectedTab: $selectedTab,
                    notificationBadges: notificationBadges,
                    onUploadTap: {
                        if appState.requireAuthentication(hint: "Sign in to create content.") {
                            showingUpload = true
                        }
                    },
                    onTabSelected: handleTabSelection
                )
                .frame(width: 80)
                .background(Color(.systemBackground).ignoresSafeArea())
                
                Divider().ignoresSafeArea()

                ZStack(alignment: .bottom) {
                    // Main Content
                    SafeContentView(selectedTab: selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(selectedTab == .flicks ? Color.black : AppTheme.Colors.background)
                        .zIndex(5)
                        .allowsHitTesting(true)
                    
                    if selectedTab != .flicks && !globalPlayer.showingFullscreen {
                        VStack(spacing: 0) {
                            Spacer()
                            GlobalNowPlayingBar()
                        }
                        .zIndex(999)
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .fullScreenCover(isPresented: $showingUpload) {
                SafeUploadView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showingFlickUpload) {
                FlickUploadSheet { _ in showingFlickUpload = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PresentUploadEditorForVideo"))) { note in
                if let video = note.object as? Video {
                    showingUpload = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        NotificationCenter.default.post(name: Notification.Name("StartUploadEditorWithExistingVideo"), object: video)
                    }
                }
            }
        } else {
            ZStack(alignment: .bottom) {
                // Main Content
                SafeContentView(selectedTab: selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(selectedTab == .flicks ? Color.black : AppTheme.Colors.background)
                    .zIndex(5)
                    .allowsHitTesting(true)
                    .safeAreaInset(edge: .bottom) {
                        // Flicks tab is fullscreen - no inset needed, overlay handles its own bottom clearance
                        if selectedTab != .flicks {
                            VStack(spacing: 8) {
                                // Show audio bar when not in fullscreen (PiP doesn't affect layout)
                                if !globalPlayer.showingFullscreen {
                                    GlobalNowPlayingBar()
                                }
                                // Reserve tab bar space (no mini player padding needed - native PiP floats)
                                Color.clear.frame(height: tabBarReservedBottomInset)
                            }
                        }
                    }
                
                // Tab bar fixed at bottom
                VStack {
                    Spacer()
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        notificationBadges: notificationBadges,
                        isHidden: false,
                        onUploadTap: {
                            if appState.requireAuthentication(hint: "Sign in to create content.") {
                                showingUpload = true
                            }
                        },
                        onTabSelected: handleTabSelection
                    )
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(999)
                .allowsHitTesting(true)

                // Native iOS PiP replaces the custom mini player bar.
                // When user swipes down or backgrounds the app, the system PiP
                // floating window appears automatically — no custom overlay needed.
            }
            .ignoresSafeArea(.keyboard)
            .fullScreenCover(isPresented: $showingUpload) {
                SafeUploadView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showingFlickUpload) {
                FlickUploadSheet { _ in showingFlickUpload = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PresentUploadEditorForVideo"))) { note in
                if let video = note.object as? Video {
                    showingUpload = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        NotificationCenter.default.post(name: Notification.Name("StartUploadEditorWithExistingVideo"), object: video)
                    }
                }
            }
        }
    }
    
    // MARK: - Safe Methods
    private func setupInitialState() {
        guard !isInitialized else { return }
        
        print("🔄 [MainTabView] setupInitialState - Starting (lightweight)...")
        
        // Initialize notification badges immediately (lightweight)
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
        
        print("✅ [MainTabView] setupInitialState completed (lightweight ops only)")
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Clear fullscreen state on app launch
            print("🔄 [MainTabView] Delayed init - Clearing fullscreen state")
            globalPlayer.showingFullscreen = false
            
            // 🔥 CRITICAL FIX: If there's a video but no active player, clear the video too
            if globalPlayer.currentVideo != nil && globalPlayer.player == nil {
                print("⚠️ [MainTabView] Found stale video with no player - clearing")
                globalPlayer.currentVideo = nil
            }
            
            // Ensure correct initial preview state
            if selectedTab == .home {
                NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
            }
        }
    }
    
    private func safeUserStateSync(_ newUser: User?) {
        Task { @MainActor in
            print("🔄 MainTabView: Setting appState.currentUser to profileImageURL: \(newUser?.profileImageURL ?? "nil")")
            appState.currentUser = newUser
        }
    }

    private func handleAuthUserChange(_ newUser: User?) {
        print("🔄 MainTabView: authManager.currentUser changed to profileImageURL: \(newUser?.profileImageURL ?? "nil")")
        safeUserStateSync(newUser)
    }

    private func updateProfileBadge(_ unread: Int) {
        notificationBadges[.profile] = unread
    }
    
    private func handleTabSelection(_ tab: TabItem) {
        guard tab != .upload else { return }
        
        // Immediately drop any keyboard/search focus before switching
        NotificationCenter.default.post(name: NSNotification.Name("SearchLoseFocus"), object: nil)
        UIApplication.shared.endEditing()
        
        let targetTab = tab
        let wasSameTab = (targetTab == selectedTab)
        previousTab = selectedTab

        // Pause mini-player when entering Flicks; resume when leaving
        if targetTab == .flicks {
            globalPlayer.pauseForFlicksEngagement()
        } else {
            globalPlayer.resumeAfterLeavingFlicks()
            // Stop Flicks in-feed video/audio when leaving tab (so audio doesn't keep playing)
            if selectedTab == .flicks {
                NotificationCenter.default.post(name: Notification.Name.pauseFlicksPlayback, object: nil)
            }
        }

        // Switch tabs on the next runloop tick so the focus change doesn't eat the tap
        Task { @MainActor in
            var tx = SwiftUI.Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                selectedTab = targetTab
            }
            
            // If switching TO search, explicitly focus the field after selection
            if targetTab == .search {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    NotificationCenter.default.post(name: NSNotification.Name("FocusSearchBar"), object: nil)
                }
            }
        }

        // Handle reselection behaviors without blocking the switch
        if wasSameTab {
            handleTabReselection(targetTab)
        }
        
        notificationBadges[targetTab] = 0
        
        Task { @MainActor in
            await AnalyticsService.shared.trackScreenView(targetTab.title)
        }
    }

    private func handleSelectedTabChange(_ tab: TabItem) {
        if tab == .flicks {
            globalPlayer.pauseForFlicksEngagement()
        } else {
            globalPlayer.resumeAfterLeavingFlicks()
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background {
            print("🎬 [MainTabView] Scene moved to background - Global player decides between PiP or audio fallback")
        } else if phase == .active {
            print("🎬 [MainTabView] Scene became active - restoring inline player if needed")
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
        Task { @MainActor in
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
            case .search:
                SafeSearchView()
            case .profile:
                NavigationStack {
                    ProfileView()
                        .navigationBarHidden(true)
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
            YouTubeStyleUploadFlow()
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

// MARK: - iPad Sidebar Navigation
struct iPadSidebar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let onUploadTap: () -> Void
    let onTabSelected: (TabItem) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Top padding
            Color.clear.frame(height: 20)
            
            // Home
            SidebarButton(
                tab: .home,
                isSelected: selectedTab == .home,
                badgeCount: notificationBadges[.home] ?? 0,
                action: { onTabSelected(.home) }
            )
            
            // Shorts (Flicks)
            SidebarButton(
                tab: .flicks,
                isSelected: selectedTab == .flicks,
                badgeCount: notificationBadges[.flicks] ?? 0,
                action: { onTabSelected(.flicks) }
            )
            
            // Upload (Create)
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onUploadTap()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.primary)
                    Text("Create")
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)
            
            // Subscriptions
            SidebarButton(
                tab: .subscriptions,
                isSelected: selectedTab == .subscriptions,
                badgeCount: notificationBadges[.subscriptions] ?? 0,
                action: { onTabSelected(.subscriptions) }
            )
            
            // Search
            SidebarButton(
                tab: .search,
                isSelected: selectedTab == .search,
                badgeCount: notificationBadges[.search] ?? 0,
                action: { onTabSelected(.search) }
            )
            
            Spacer()
            
            // Profile (You) at bottom
            SidebarButton(
                tab: .profile,
                isSelected: selectedTab == .profile,
                badgeCount: notificationBadges[.profile] ?? 0,
                action: { onTabSelected(.profile) }
            )
            .padding(.bottom, 32)
        }
    }
}

struct SidebarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.iconName(isSelected: isSelected))
                        .font(.system(size: 24, weight: isSelected ? .semibold : .light))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
                
                Text(tab == .profile ? "You" : tab.title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let isHidden: Bool
    let onUploadTap: () -> Void
    let onTabSelected: (TabItem) -> Void
    
    // 🔥 YOUTUBE PARITY: Tab order matches YouTube mobile exactly:
    // Home · Flicks · (+) · Subscriptions · Profile
    // Search lives in the header (MinimalNavigationHeader), not the tab bar.
    // Separate tabs into main group and profile. When Home is selected, show it as a separated button on the left.
    private var mainTabs: [TabItem] {
        if selectedTab == .home {
            return [.flicks, .subscriptions]
        } else {
            return [.home, .flicks, .subscriptions]
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
                
                // Add profile button always (unless profile tab is separated out)
                if selectedTab != .profile {
                    ConnectedProfileButton(
                        isSelected: selectedTab == .profile,
                        badgeCount: notificationBadges[.profile] ?? 0,
                        action: {
                            onTabSelected(.profile)
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    Capsule()
                        .fill(Color.white)
                    Capsule()
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
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
            .frame(maxWidth: iPadLayout.tabBarMaxWidth)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
            .onAppear {
                print("📱 [CustomTabBar] Tab bar rendered with selected tab: \(selectedTab.title)")
            }
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

#Preview("Custom Tab Bar - Home Selected") {
    CustomTabBarPreview(selectedTab: .home)
}

#Preview("Custom Tab Bar - Profile Selected") {
    CustomTabBarPreview(selectedTab: .profile)
}

#Preview("Custom Tab Bar - Search Selected") {
    CustomTabBarPreview(selectedTab: .search)
}

// MARK: - Preview Helper View
private struct CustomTabBarPreview: View {
    @State var selectedTab: TabItem
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area
            VStack {
                // Header
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("MyChannel")
                        .font(AppTheme.Typography.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                    Image(systemName: "bell")
                        .font(.title3)
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
                .padding()
                
                // Content placeholder
                VStack(spacing: 16) {
                    Image(systemName: selectedTab.iconName(isSelected: true))
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text(selectedTab.title)
                        .font(AppTheme.Typography.title1)
                        .fontWeight(.bold)
                    
                    Text("Tab bar preview - tap tabs to switch")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppTheme.Colors.background)
            
            // Actual CustomTabBar component
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: $selectedTab,
                    notificationBadges: [.flicks: 2, .profile: 3],
                    isHidden: false,
                    onUploadTap: { print("Upload tapped") },
                    onTabSelected: { tab in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                )
                .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Account Blocked Screen

struct AccountBlockedView: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color

    @EnvironmentObject private var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundColor(iconColor)
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .black))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            VStack(spacing: 12) {
                Link("MyChannel Community Guidelines",
                     destination: URL(string: "https://mychannel.live/guidelines")!)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                Button("Sign Out") {
                    try? FirebaseAuth.Auth.auth().signOut()
                    authManager.authState = .unauthenticated
                    authManager.isAuthenticated = false
                    authManager.isBanned = false
                    authManager.isSuspended = false
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// SafeFloatingMiniPlayer removed — native iOS PiP replaces the custom mini-player.
// Kept as empty stub in case any other file references it.
struct SafeFloatingMiniPlayer: View {
    var body: some View {
        EmptyView()
    }
}

// MARK: - Go Live Placeholder
struct GoLivePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                Text("Go Live")
                    .font(.system(size: 28, weight: .bold))
                Text("Live streaming is coming soon.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .navigationTitle("Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Create Post Placeholder
struct CreatePostPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "doc.text")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("Create Post")
                    .font(.system(size: 28, weight: .bold))
                Text("Community posts are coming soon.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension UIApplication {
    func endEditing(_ force: Bool = true) {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}