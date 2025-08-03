//
//  MainTabView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var selectedTab: TabItem = .home
    @State private var tabBarOffset: CGFloat = 0
    @State private var isTabBarHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var notificationBadges: [TabItem: Int] = [
        .home: 0,
        .stories: 2,
        .upload: 0,
        .search: 0,
        .profile: 3 // Sample notification count
    ]
    
    // App-wide state
    @State private var showingUpload: Bool = false
    @StateObject private var appState = AppState()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main content
                TabView(selection: $selectedTab) {
                    LazyTabContent(tab: .home) {
                        HomeView()
                            .onScrollOffsetChange { offset in
                                handleScrollOffset(offset, geometry: geometry)
                            }
                    }
                    .tag(TabItem.home)
                    
                    LazyTabContent(tab: .stories) {
                        StoriesView()
                    }
                    .tag(TabItem.stories)
                    
                    LazyTabContent(tab: .upload) {
                        UploadPlaceholderView()
                    }
                    .tag(TabItem.upload)
                    
                    LazyTabContent(tab: .search) {
                        SearchView()
                    }
                    .tag(TabItem.search)
                    
                    LazyTabContent(tab: .profile) {
                        ProfileView()
                    }
                    .tag(TabItem.profile)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea(.keyboard)
                .background(AppTheme.Colors.background)
                
                // Custom Tab Bar
                CustomTabBar(
                    selectedTab: $selectedTab,
                    notificationBadges: notificationBadges,
                    isHidden: isTabBarHidden,
                    onUploadTap: {
                        showingUpload = true
                    }
                )
                .offset(y: tabBarOffset)
                .animation(.easeInOut(duration: 0.3), value: tabBarOffset)
                .animation(.easeInOut(duration: 0.3), value: isTabBarHidden)
            }
        }
        .ignoresSafeArea(.keyboard)
        .environmentObject(appState)
        .environmentObject(authManager)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear notification badge for selected tab
            notificationBadges[newValue] = 0
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Track screen view
            Task {
                await AnalyticsService.shared.trackScreenView(newValue.title)
            }
        }
        .fullScreenCover(isPresented: $showingUpload) {
            UploadView()
        }
        .onAppear {
            // Set current user in app state
            if let user = authManager.currentUser {
                appState.currentUser = user
            }
        }
        .onChange(of: authManager.currentUser) { oldValue, newValue in
            if let user = newValue {
                appState.currentUser = user
            }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat, geometry: GeometryProxy) {
        let threshold: CGFloat = 20
        let diff = offset - lastScrollOffset
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if diff > threshold && !isTabBarHidden {
                // Scrolling down, hide tab bar
                isTabBarHidden = true
                tabBarOffset = 100
            } else if diff < -threshold && isTabBarHidden {
                // Scrolling up, show tab bar
                isTabBarHidden = false
                tabBarOffset = 0
            }
        }
        
        lastScrollOffset = offset
    }
}

// MARK: - App State Management
@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User = User.sampleUsers[0]
    @Published var isLoggedIn: Bool = true
    @Published var watchLaterVideos: Set<String> = []
    @Published var likedVideos: Set<String> = []
    @Published var followedCreators: Set<String> = []
    @Published var notifications: [AppNotification] = []
    
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

// MARK: - App Notification Model
struct AppNotification: Identifiable {
    let id: String = UUID().uuidString
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

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let isHidden: Bool
    let onUploadTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                if tab == .upload {
                    // Special upload button
                    UploadTabButton(action: onUploadTap)
                        .frame(maxWidth: .infinity)
                } else {
                    CustomTabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        badgeCount: notificationBadges[tab] ?? 0,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            ZStack {
                // Frosted glass effect
                VisualEffectBlur(blurStyle: .systemMaterial)
                    .cornerRadius(AppTheme.CornerRadius.xl)
                
                // Gradient border
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
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
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.1),
            radius: 20,
            x: 0,
            y: -5
        )
        .opacity(isHidden ? 0 : 1)
        .scaleEffect(isHidden ? 0.9 : 1.0)
    }
}

// MARK: - Upload Tab Button
struct UploadTabButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Gradient background
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 50, height: 50)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel("Create content")
        .accessibilityHint("Double tap to create new content")
    }
}

// MARK: - Upload Placeholder View
struct UploadPlaceholderView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 16) {
                Text("Create Amazing Content")
                    .font(AppTheme.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Tap the + button to start creating videos, shorts, or live streams")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.background)
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
                    // Background indicator
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                    }
                    
                    // Icon with badge
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: tab.iconName(isSelected: isSelected))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(
                                isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                            )
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        
                        // Notification badge
                        if badgeCount > 0 {
                            NotificationBadge(count: badgeCount)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // Tab title
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                    )
                    .opacity(isSelected ? 1.0 : 0.8)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0.1) {
            // Long press action (could show context menu)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
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
        .scaleEffect(count > 0 ? 1.0 : 0.0)
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

// MARK: - Lazy Tab Content
struct LazyTabContent<Content: View>: View {
    let tab: TabItem
    let content: () -> Content
    
    @State private var hasAppeared: Bool = false
    
    var body: some View {
        Group {
            if hasAppeared {
                content()
            } else {
                // Enhanced loading placeholder
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Animated logo or icon
                    Image(systemName: tab.iconName(isSelected: true))
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.primary)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                    
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            .scaleEffect(1.2)
                        
                        Text("Loading \(tab.title)...")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .onAppear {
            // Delay loading to improve performance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Enhanced Tab Item Enum
enum TabItem: String, CaseIterable {
    case home = "home"
    case stories = "stories"
    case upload = "upload"
    case search = "search"
    case profile = "profile"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .stories: return "Stories"
        case .upload: return "Create"
        case .search: return "Search"
        case .profile: return "You"
        }
    }
    
    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .stories:
            return isSelected ? "circle.fill" : "circle"
        case .upload:
            return isSelected ? "plus.circle.fill" : "plus.circle"
        case .search:
            return isSelected ? "magnifyingglass.circle.fill" : "magnifyingglass"
        case .profile:
            return isSelected ? "person.circle.fill" : "person.circle"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .home: return "Home tab"
        case .stories: return "Stories tab"
        case .upload: return "Create content tab"
        case .search: return "Search tab"
        case .profile: return "Profile tab"
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.light)
}