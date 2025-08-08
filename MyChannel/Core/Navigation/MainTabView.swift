//
//  MainTabView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - Scroll-To-Top Notification
extension Notification.Name {
    static let scrollToTopProfile = Notification.Name("scrollToTopProfile")
}

// MARK: - Preview-Safe Main Tab View
struct MainTabView: View {
    // Simple environment object access without complex initialization
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var globalPlayer: GlobalVideoPlayerManager
    
    @State private var selectedTab: TabItem = .home
    @State private var previousTab: TabItem = .home
    @State private var showingUpload: Bool = false
    @State private var isInitialized: Bool = false
    
    @State private var notificationBadges: [TabItem: Int] = [:]
    
    // Error handling state
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            if hasError {
                errorView
            } else {
                mainContent
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: authManager.currentUser) { _, newValue in
            safeUserStateSync(newValue)
        }
        .onDisappear {
            cleanup()
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
                .zIndex(1)

            // Floating Mini Player - Above content, below tab bar
            SafeFloatingMiniPlayer()
                .zIndex(998)

            // Custom Tab Bar - Always on top
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: $selectedTab,
                    notificationBadges: notificationBadges,
                    isHidden: false,
                    onUploadTap: {
                        showingUpload = true
                    },
                    onTabSelected: handleTabSelection
                )
            }
            .zIndex(999)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showingUpload) {
            SafeUploadView()
        }
    }
    
    // MARK: - Safe Methods
    private func setupInitialState() {
        guard !isInitialized else { return }
        
        do {
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
        } catch {
            handleError("Failed to initialize app state: \(error.localizedDescription)")
        }
    }
    
    private func safeUserStateSync(_ newUser: User?) {
        DispatchQueue.main.async {
            appState.currentUser = newUser
        }
    }
    
    private func handleTabSelection(_ tab: TabItem) {
        guard tab != .upload else { return }
        
        do {
            // Handle double-tap to scroll for profile
            if tab == .profile && previousTab == .profile {
                NotificationCenter.default.post(name: .scrollToTopProfile, object: nil)
            }
            
            // Update states safely
            previousTab = selectedTab
            selectedTab = tab
            
            // Clear badge for selected tab
            notificationBadges[tab] = 0
            
            // Haptic feedback
            HapticManager.shared.impact(style: .light)
            
            // Analytics tracking (safe async)
            Task { @MainActor in
                do {
                    await AnalyticsService.shared.trackScreenView(tab.title)
                } catch {
                    print("Analytics error: \(error)")
                }
            }
        } catch {
            handleError("Tab selection error: \(error.localizedDescription)")
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
            case .flicks:
                SafeFlicksView()
            case .search:
                SafeSearchView()
            case .profile:
                SafeProfileView()
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
            ContentUnavailableView(
                "Home Unavailable",
                systemImage: "house.slash",
                description: Text("Please try again later")
            )
        }
    }
}

struct SafeFlicksView: View {
    var body: some View {
        ErrorBoundary {
            FlicksView()
        } fallback: {
            ContentUnavailableView(
                "Flicks Unavailable",
                systemImage: "play.slash",
                description: Text("Please try again later")
            )
        }
    }
}

struct SafeSearchView: View {
    var body: some View {
        ErrorBoundary {
            SearchView()
        } fallback: {
            ContentUnavailableView(
                "Search Unavailable",
                systemImage: "magnifyingglass.circle.slash",
                description: Text("Please try again later")
            )
        }
    }
}

struct SafeProfileView: View {
    var body: some View {
        ErrorBoundary {
            ProfileView()
        } fallback: {
            ContentUnavailableView(
                "Profile Unavailable",
                systemImage: "person.slash",
                description: Text("Please try again later")
            )
        }
    }
}

struct SafeUploadView: View {
    var body: some View {
        ErrorBoundary {
            UploadView()
        } fallback: {
            ContentUnavailableView(
                "Upload Unavailable",
                systemImage: "plus.circle.slash",
                description: Text("Please try again later")
            )
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

// MARK: - App State (Thread-Safe)
@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = true
    @Published var watchLaterVideos: Set<String> = []
    @Published var likedVideos: Set<String> = []
    @Published var followedCreators: Set<String> = []
    @Published var notifications: [AppNotification] = []

    private let queue = DispatchQueue(label: "appstate.queue", qos: .userInitiated)

    init() {
        self.currentUser = nil
    }
    
    func toggleLike(videoId: String) {
        if likedVideos.contains(videoId) {
            likedVideos.remove(videoId)
        } else {
            likedVideos.insert(videoId)
        }
    }

    func toggleWatchLater(videoId: String) {
        if watchLaterVideos.contains(videoId) {
            watchLaterVideos.remove(videoId)
        } else {
            watchLaterVideos.insert(videoId)
        }
    }

    func followCreator(_ creatorId: String) {
        followedCreators.insert(creatorId)
    }

    func unfollowCreator(_ creatorId: String) {
        followedCreators.remove(creatorId)
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
    case home, flicks, upload, search, profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .flicks: return "Flicks"
        case .upload: return "Create"
        case .search: return "Search"
        case .profile: return "You"
        }
    }

    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home: return isSelected ? "house.fill" : "house"
        case .flicks: return isSelected ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle"
        case .upload: return "plus"
        case .search: return "magnifyingglass"
        case .profile: return isSelected ? "person.fill" : "person"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home: return "Home tab"
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
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases.filter { $0 != .upload }, id: \.self) { tab in
                CustomTabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: notificationBadges[tab] ?? 0,
                    action: {
                        onTabSelected(tab)
                    }
                )
                .frame(maxWidth: .infinity)
                
                if tab == .flicks {
                    UploadTabButton(action: onUploadTap)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                VisualEffectBlur(blurStyle: .systemMaterial)
                    .cornerRadius(24)
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.3),
                                AppTheme.Colors.secondary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.1),
            radius: 20,
            x: 0,
            y: -5
        )
    }
}

// MARK: - Upload Tab Button
struct UploadTabButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(style: .medium)
        }) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 50, height: 50)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel("Create content")
        .accessibilityHint("Double tap to create new content")
    }
}

// MARK: - Custom Tab Bar Button
struct CustomTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: tab.iconName(isSelected: isSelected))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(
                                isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                            )
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        
                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                    )
                    .opacity(isSelected ? 1.0 : 0.8)
            }
            .padding(.vertical, 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
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
        // Set a default user to prevent crashes
        manager.currentUser = User(
            username: "preview_user",
            displayName: "Preview User",
            email: "preview@mychannel.com",
            profileImageURL: "https://picsum.photos/200/200",
            bio: "Preview user for testing"
        )
        return manager
    }
    
    private func createSafeAppState() -> AppState {
        let state = AppState()
        // Set a safe default user
        state.currentUser = User(
            username: "preview_user",
            displayName: "Preview User",
            email: "preview@mychannel.com",
            profileImageURL: "https://picsum.photos/200/200",
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
                        .fontWeight(.medium)
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
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .padding()
    }
    .background(AppTheme.Colors.background)
}

#Preview("Full MainTabView - Advanced") {
    // Only show this if you want to test the full complexity
    PreviewSafeMainTabWrapper()
        .preferredColorScheme(.light)
        .onAppear {
            print("🎬 Advanced MainTabView preview loaded")
        }
}