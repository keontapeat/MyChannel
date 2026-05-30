// ⚡ PERFORMANCE: Extracted from ProfileView.swift — independent compilation unit.
// Helper sections, wrapper views, notifications, and preview compile separately.
import SwiftUI

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

struct ProfileContentSection: View {
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

extension View {
    
    func applyLifecycleModifiers(
        onAppearAction: @escaping () -> Void,
        onDisappearAction: @escaping () -> Void
    ) -> some View {
        self
            .onAppear {
                onAppearAction()
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
