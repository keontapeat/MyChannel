//
//  MainTabView+Modifiers.swift
//  MyChannel
//
//  Split from MainTabView to prevent stack overflow (EXC_BAD_ACCESS code=2).
//  Each ViewModifier produces its own small @ViewBuilder getter, keeping the
//  per-function stack frame well under the 512KB main-thread limit.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Lifecycle Modifiers

struct LifecycleModifiers: ViewModifier {
    let onAppearAction: () -> Void
    let onDisappearAction: () -> Void
    let authUser: User?
    let onAuthUserChange: (User?) -> Void
    let unreadCount: Int
    let onUnreadChange: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { onAppearAction() }
            .onDisappear { onDisappearAction() }
            .onChange(of: authUser) { newValue in onAuthUserChange(newValue) }
            .onChange(of: unreadCount) { unread in onUnreadChange(unread) }
    }
}

// MARK: - Tab Navigation Receivers

struct TabNavigationReceivers: ViewModifier {
    @Binding var selectedTab: TabItem
    @Binding var showingUpload: Bool
    @Binding var historyVideoToOpen: Video?
    let globalPlayer: GlobalVideoPlayerManager

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
                selectedTab = .home
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSearchTab"))) { _ in
                selectedTab = .search
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfileTab"))) { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentVideoDetail"))) { notification in
                print("📺 [MainTabView] Received PresentVideoDetail - opening fullscreen")
                if let video = notification.object as? Video {
                    historyVideoToOpen = video
                } else if let video = globalPlayer.currentVideo {
                    historyVideoToOpen = video
                }
            }
    }
}

// MARK: - Account & History Receivers

struct AccountAndHistoryReceivers: ViewModifier {
    @Binding var presentAccountSwitcher: Bool
    @Binding var presentGoogleAccount: Bool
    @Binding var presentSignInSheet: Bool
    @Binding var presentFullHistory: Bool
    @Binding var presentHistoryManagement: Bool
    @Binding var historyVideoToOpen: Video?
    @Binding var historyLiveTVToOpen: LiveTVChannel?
    @Binding var historyCreatorToOpen: User?
    let appState: AppState

    func body(content: Content) -> some View {
        content
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
                    NotificationCenter.default.post(name: Notification.Name("PresentUploadEditorForVideo"), object: video)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openVideoFromHistory)) { note in
                if let video = note.object as? Video {
                    historyVideoToOpen = video
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openLiveTVFromHistory)) { note in
                guard let item = note.object as? WatchHistoryItem else { return }
                let channels = LiveTVManager.shared.channels.isEmpty ? LiveTVChannel.sampleChannels : LiveTVManager.shared.channels
                if let channel = channels.first(where: { $0.id == item.contentId }) {
                    historyLiveTVToOpen = channel
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openStoryFromHistory)) { note in
                guard let item = note.object as? WatchHistoryItem else { return }
                Task {
                    let creator = try? await UserFirestoreService.shared.fetchUser(id: item.creatorId)
                    await MainActor.run {
                        if let creator { historyCreatorToOpen = creator }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("openPostFromHistory"))) { note in
                guard let item = note.object as? WatchHistoryItem else { return }
                Task {
                    let creator = try? await UserFirestoreService.shared.fetchUser(id: item.creatorId)
                    await MainActor.run {
                        if let creator { historyCreatorToOpen = creator }
                    }
                }
            }
    }
}

// MARK: - Deep Navigation Receivers

struct DeepNavigationReceivers: ViewModifier {
    @Binding var historyVideoToOpen: Video?
    @Binding var presentGlobalNowPlaying: Bool
    @Binding var presentNotificationsInbox: Bool
    @Binding var showingCreatorStudio: Bool
    @Binding var videoIdForStudio: String?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideo"))) { notification in
                if let video = notification.object as? Video {
                    historyVideoToOpen = video
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideoId"))) { notification in
                guard let videoId = notification.object as? String, !videoId.isEmpty else { return }
                Task { @MainActor in
                    if let video = await Self.fetchVideo(videoId: videoId) {
                        historyVideoToOpen = video
                    }
                }
            }
            // Deep links: mychannel://video/{id}?t=90 → open the video (start time
            // is applied by the player once its duration is known).
            .onReceive(DeepLinkService.shared.$pendingLink) { target in
                guard let target, target.type == .video, !target.targetId.isEmpty else { return }
                let videoId = target.targetId
                DeepLinkService.shared.clearPending()
                Task { @MainActor in
                    if let video = await Self.fetchVideo(videoId: videoId) {
                        historyVideoToOpen = video
                    }
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
                    videoIdForStudio = video.id
                    showingCreatorStudio = true
                }
            }
    }

    /// Fetch a single video doc and map it to a `Video`. Extracted out of `body`
    /// with explicit types so the SwiftUI view builder type-checks quickly.
    @MainActor
    private static func fetchVideo(videoId: String) async -> Video? {
        guard
            let snap = try? await Firestore.firestore().collection("videos").document(videoId).getDocument(),
            snap.exists,
            let data = snap.data(),
            let title = data["title"] as? String
        else { return nil }

        let creatorId: String = data["creatorId"] as? String ?? ""
        let creator = User(
            id: creatorId,
            username: "",
            displayName: data["channelName"] as? String ?? "Creator",
            email: "",
            profileImageURL: data["channelAvatarUrl"] as? String ?? "",
            subscriberCount: 0,
            videoCount: 0,
            isVerified: false,
            isCreator: false,
            createdAt: Date()
        )

        let videoURL: String = data["videoURL"] as? String ?? data["hlsURL"] as? String ?? ""
        let createdAt: Date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Video(
            id: snap.documentID,
            title: title,
            description: data["description"] as? String ?? "",
            thumbnailURL: data["thumbnailURL"] as? String ?? "",
            videoURL: videoURL,
            duration: (data["duration"] as? Double) ?? 0,
            viewCount: (data["viewCount"] as? Int) ?? 0,
            likeCount: (data["likeCount"] as? Int) ?? 0,
            commentCount: (data["commentCount"] as? Int) ?? 0,
            createdAt: createdAt,
            creator: creator,
            category: .entertainment,
            tags: data["tags"] as? [String] ?? [],
            isPublic: true,
            ageRestricted: data["ageRestricted"] as? Bool ?? false
        )
    }
}

// MARK: - Presentation Modifiers (sheets + fullScreenCovers)

struct PresentationModifiers: ViewModifier {
    @Binding var showingCreatorStudio: Bool
    let videoIdForStudio: String?
    @Binding var presentAccountSwitcher: Bool
    @Binding var presentGoogleAccount: Bool
    @Binding var presentSignInSheet: Bool
    @Binding var presentFullHistory: Bool
    @Binding var presentHistoryManagement: Bool
    @Binding var presentGlobalNowPlaying: Bool
    @Binding var presentNotificationsInbox: Bool
    @Binding var historyVideoToOpen: Video?
    @Binding var historyLiveTVToOpen: LiveTVChannel?
    @Binding var historyCreatorToOpen: User?
    @Binding var showAuthGate: Bool
    @Binding var selectedTab: TabItem
    let authManager: AuthenticationManager
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .modifier(SheetPresentations(
                showingCreatorStudio: $showingCreatorStudio,
                videoIdForStudio: videoIdForStudio,
                presentAccountSwitcher: $presentAccountSwitcher,
                presentGoogleAccount: $presentGoogleAccount,
                presentSignInSheet: $presentSignInSheet,
                presentFullHistory: $presentFullHistory,
                presentHistoryManagement: $presentHistoryManagement,
                presentGlobalNowPlaying: $presentGlobalNowPlaying,
                presentNotificationsInbox: $presentNotificationsInbox,
                authManager: authManager,
                appState: appState
            ))
            .modifier(FullScreenCoverPresentations(
                historyVideoToOpen: $historyVideoToOpen,
                historyLiveTVToOpen: $historyLiveTVToOpen,
                historyCreatorToOpen: $historyCreatorToOpen,
                showAuthGate: $showAuthGate,
                selectedTab: $selectedTab,
                presentSignInSheet: $presentSignInSheet,
                authManager: authManager,
                appState: appState
            ))
    }
}

// MARK: - Sheet Presentations (split further to keep frames small)

private struct SheetPresentations: ViewModifier {
    @Binding var showingCreatorStudio: Bool
    let videoIdForStudio: String?
    @Binding var presentAccountSwitcher: Bool
    @Binding var presentGoogleAccount: Bool
    @Binding var presentSignInSheet: Bool
    @Binding var presentFullHistory: Bool
    @Binding var presentHistoryManagement: Bool
    @Binding var presentGlobalNowPlaying: Bool
    @Binding var presentNotificationsInbox: Bool
    let authManager: AuthenticationManager
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showingCreatorStudio) {
                NavigationStack {
                    ComprehensiveCreatorStudioView(videoId: videoIdForStudio)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                }
            }
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
    }
}

// MARK: - Full Screen Cover Presentations

private struct FullScreenCoverPresentations: ViewModifier {
    @Binding var historyVideoToOpen: Video?
    @Binding var historyLiveTVToOpen: LiveTVChannel?
    @Binding var historyCreatorToOpen: User?
    @Binding var showAuthGate: Bool
    @Binding var selectedTab: TabItem
    @Binding var presentSignInSheet: Bool
    let authManager: AuthenticationManager
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $historyVideoToOpen) { video in
                VideoDetailView(video: video)
            }
            .fullScreenCover(item: $historyLiveTVToOpen) { channel in
                LiveTVPlayerView(channel: channel)
                    .environmentObject(appState)
            }
            .fullScreenCover(item: $historyCreatorToOpen) { creator in
                NavigationStack {
                    PublicProfileView(user: creator)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    historyCreatorToOpen = nil
                                } label: {
                                    Image(systemName: "xmark")
                                }
                            }
                        }
                }
            }
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
    }
}
