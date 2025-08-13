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
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    
    @State private var selectedTab: TabItem = .home
    @State private var previousTab: TabItem = .home
    @State private var showingUpload: Bool = false
    @State private var isInitialized: Bool = false
    @State private var presentMiniPlayerDetail: Bool = false
    
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
                    .environmentObject(globalPlayer)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSearchTab"))) { _ in
            selectedTab = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfileTab"))) { _ in
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentVideoDetailFromMiniPlayer"))) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                presentMiniPlayerDetail = true
            }
        }
        // Present video detail only when triggered by mini player event
        .fullScreenCover(isPresented: $presentMiniPlayerDetail) {
            if let video = globalPlayer.currentVideo {
                VideoDetailView(video: video)
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
                .zIndex(1)

            // Floating Mini Player - Above content, below tab bar (suppress on Flicks for minimal UI)
            if selectedTab != .flicks {
                SafeFloatingMiniPlayer()
                    .environmentObject(globalPlayer)
                    .zIndex(998)
            }

            // Custom Tab Bar - Keep visible for all tabs (including Flicks)
            if true {
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
            appState.currentUser = newUser
        }
    }
    
    private func handleTabSelection(_ tab: TabItem) {
        guard tab != .upload else { return }
        
        do {
            if tab == selectedTab {
                handleTabReselection(tab)
            } else {
                previousTab = selectedTab
                selectedTab = tab
                if tab == .home {
                    NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
                }
            }
            
            notificationBadges[tab] = 0
            
            if tab != .profile {
                HapticManager.shared.impact(style: .light)
            }
            
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
    
    private func handleTabReselection(_ tab: TabItem) {
        switch tab {
        case .home:
            NotificationCenter.default.post(name: NSNotification.Name("HomeScrollToTop"), object: nil)
        case .flicks:
            NotificationCenter.default.post(name: NSNotification.Name("FlicksResetToFirst"), object: nil)
        case .search:
            NotificationCenter.default.post(name: NSNotification.Name("SearchClearAndReset"), object: nil)
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
            case .flicks:
                // Embed Flicks inside the tab with embedded flag on
                ErrorBoundary {
                    FlicksView(isEmbeddedInTab: true)
                } fallback: {
                    ContentUnavailableView(
                        "Flicks Unavailable",
                        systemImage: "play.slash",
                        description: Text("Please try again later")
                    )
                }
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
    
    // Separate tabs into main group and profile. When Home is selected, show it as a separated button on the left.
    private var mainTabs: [TabItem] {
        if selectedTab == .home {
            return [.flicks, .search]
        } else {
            return [.home, .flicks, .search]
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
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Solid white background (non-translucent)
                    Capsule()
                        .fill(Color.white)
                    // Light border for definition
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
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
        .padding(.bottom, 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Connected Profile Button (when in main tab bar)
struct ConnectedProfileButton: View {
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: TabItem.profile.iconName(isSelected: isSelected))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        
                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 10, y: -6)
                        }
                    }
                }
                .frame(height: 32)
            }
            .frame(height: 48)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
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
        .accessibilityLabel(TabItem.profile.accessibilityLabel)
        .accessibilityHint("Double tap to select profile")
    }
}

// MARK: - Separated Profile Button
struct SeparatedProfileButton: View {
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
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
                                Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                    )
                
                ZStack(alignment: .topTrailing) {
                    Image(systemName: TabItem.profile.iconName(isSelected: isSelected))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(
                            isSelected ? .white : AppTheme.Colors.textSecondary
                        )
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    if badgeCount > 0 {
                        NotificationBadge(count: badgeCount)
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .shadow(
            color: Color.black.opacity(isSelected ? 0.2 : 0.1),
            radius: isSelected ? 12 : 8,
            x: 0,
            y: isSelected ? 6 : 4
        )
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
        .accessibilityLabel(TabItem.profile.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Separated Home Button (mirrors profile style, left-aligned)
struct SeparatedHomeButton: View {
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    Circle().fill(AppTheme.Colors.primary)
                }
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                
                Image(systemName: TabItem.home.iconName(isSelected: isSelected))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TabItem.home.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        
                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 10, y: -6)
                        }
                    }
                }
                .frame(height: 32)
            }
            .frame(height: 48)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
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