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
    @State private var historyLiveTVToOpen: LiveTVChannel? = nil
    @State private var historyCreatorToOpen: User? = nil
    @State private var showAuthGate: Bool = false
    
    // Creator Studio (for video analytics)
    @State private var showingCreatorStudio: Bool = false
    @State private var videoIdForStudio: String?

    // MARK: - Body (split into small @ViewBuilder vars to avoid stack overflow)
    // The Swift compiler builds a single stack frame per @ViewBuilder getter.
    // A monolithic body with 20+ chained modifiers produces a frame > 512KB on
    // arm64, hitting the main-thread stack guard page → EXC_BAD_ACCESS crash.
    // Splitting into sub-views keeps each frame well under the limit.

    var body: some View {
        rootZStack
            .modifier(LifecycleModifiers(
                onAppearAction: { setupInitialState(); deferredInboxFetch() },
                onDisappearAction: cleanup,
                authUser: authManager.currentUser,
                onAuthUserChange: handleAuthUserChange,
                unreadCount: inbox.unreadCount,
                onUnreadChange: updateProfileBadge
            ))
            .modifier(TabNavigationReceivers(
                selectedTab: $selectedTab,
                showingUpload: $showingUpload,
                historyVideoToOpen: $historyVideoToOpen,
                globalPlayer: globalPlayer
            ))
            .ignoresSafeArea(.keyboard)
            .modifier(AccountAndHistoryReceivers(
                presentAccountSwitcher: $presentAccountSwitcher,
                presentGoogleAccount: $presentGoogleAccount,
                presentSignInSheet: $presentSignInSheet,
                presentFullHistory: $presentFullHistory,
                presentHistoryManagement: $presentHistoryManagement,
                historyVideoToOpen: $historyVideoToOpen,
                historyLiveTVToOpen: $historyLiveTVToOpen,
                historyCreatorToOpen: $historyCreatorToOpen,
                appState: appState
            ))
            .modifier(DeepNavigationReceivers(
                historyVideoToOpen: $historyVideoToOpen,
                presentGlobalNowPlaying: $presentGlobalNowPlaying,
                presentNotificationsInbox: $presentNotificationsInbox,
                showingCreatorStudio: $showingCreatorStudio,
                videoIdForStudio: $videoIdForStudio
            ))
            .modifier(PresentationModifiers(
                showingCreatorStudio: $showingCreatorStudio,
                videoIdForStudio: videoIdForStudio,
                presentAccountSwitcher: $presentAccountSwitcher,
                presentGoogleAccount: $presentGoogleAccount,
                presentSignInSheet: $presentSignInSheet,
                presentFullHistory: $presentFullHistory,
                presentHistoryManagement: $presentHistoryManagement,
                presentGlobalNowPlaying: $presentGlobalNowPlaying,
                presentNotificationsInbox: $presentNotificationsInbox,
                historyVideoToOpen: $historyVideoToOpen,
                historyLiveTVToOpen: $historyLiveTVToOpen,
                historyCreatorToOpen: $historyCreatorToOpen,
                showAuthGate: $showAuthGate,
                selectedTab: $selectedTab,
                authManager: authManager,
                appState: appState
            ))
            .onChange(of: authManager.isAuthenticated) { isAuth in
                if isAuth {
                    if showAuthGate { showAuthGate = false }
                    if presentSignInSheet { presentSignInSheet = false }
                }
            }
            .onChange(of: selectedTab) { newTab in
                handleSelectedTabChange(newTab)
            }
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
    }

    // MARK: - Root ZStack (content selection)

    @ViewBuilder
    private var rootZStack: some View {
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
            }
        }
    }

    // MARK: - Deferred Inbox Fetch

    private func deferredInboxFetch() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let uid = authManager.currentUser?.id {
                try? await inbox.fetchNotifications(userId: uid)
                print("📨 [MainTabView] Started inbox listener for user: \(uid)")
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

                    // 🔥 MINI PLAYER: Custom YouTube-style PiP mini player (ONLY mini player allowed).
                    // FloatingMiniPlayer is free-floating and manages its own zIndex/positioning —
                    // never swap this for VideoMiniPlayerBar (the long rectangular bar variant).
                    FloatingMiniPlayer()
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
                            VStack(spacing: 0) {
                                // Show audio bar when not in fullscreen (PiP doesn't affect layout)
                                if !globalPlayer.showingFullscreen {
                                    GlobalNowPlayingBar()
                                }
                                // Reserve tab bar space
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

                // 🔥 MINI PLAYER: Custom YouTube-style PiP mini player (ONLY mini player allowed).
                // Appears when a video is playing but VideoDetailView is dismissed.
                // Free-floating, draggable, swipe to dismiss/expand — never swap this for
                // VideoMiniPlayerBar (the long rectangular bar variant); see file-safety notes.
                FloatingMiniPlayer()
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
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

// MARK: - Tab Bar Item Definition
// NOTE: TabItem moved to CustomTabBar.swift — keep this note for navigation

struct AccountBlockedView: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(iconColor)
            Text(title)
                .font(.title2)
                .bold()
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct iPadSidebar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let onUploadTap: () -> Void
    let onTabSelected: (TabItem) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach([TabItem.home, .flicks, .upload, .subscriptions, .search, .profile], id: \.self) { tab in
                Button {
                    if tab == .upload {
                        onUploadTap()
                    } else {
                        onTabSelected(tab)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName(isSelected: selectedTab == tab))
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        Text(tab.title)
                            .font(.system(size: 10))
                            .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Spacer()
        }
        .padding(.top, 32)
    }
}
