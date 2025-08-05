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

struct MainTabView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var selectedTab: TabItem = .home
    @State private var previousTab: TabItem = .home

    @State private var notificationBadges: [TabItem: Int] = [
        .home: 0,
        .flicks: 2,
        .upload: 0,
        .search: 0,
        .profile: 3
    ]

    @State private var showingUpload: Bool = false
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .flicks:
                    FlicksView()
                case .search:
                    SearchView()
                case .profile:
                    ProfileView()
                case .upload:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .transition(.identity)

            CustomTabBar(
                selectedTab: $selectedTab,
                notificationBadges: notificationBadges,
                isHidden: false,
                onUploadTap: {
                    showingUpload = true
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .environmentObject(appState)
        .environmentObject(authManager)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .upload {
                selectedTab = oldValue
                return
            }

            // 👇 Scroll to top if Profile is tapped twice
            if newValue == .profile && previousTab == .profile {
                NotificationCenter.default.post(name: .scrollToTopProfile, object: nil)
            }

            // Update state
            previousTab = newValue
            notificationBadges[newValue] = 0
            HapticManager.shared.impact(style: .light)

            Task {
                await AnalyticsService.shared.trackScreenView(newValue.title)
            }
        }
        .fullScreenCover(isPresented: $showingUpload) {
            UploadView()
        }
        .onAppear {
            if let user = authManager.currentUser {
                appState.currentUser = user
            }
        }
        .onChange(of: authManager.currentUser) { _, newValue in
            if let user = newValue {
                appState.currentUser = user
            }
        }
    }
}

// MARK: - App State
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
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases.filter { $0 != .upload }, id: \.self) { tab in
                CustomTabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: notificationBadges[tab] ?? 0,
                    action: {
                        selectedTab = tab
                    }
                )
                .frame(maxWidth: .infinity)
                
                if tab == .flicks {
                    // Special upload button sits in the middle
                    UploadTabButton(action: onUploadTap)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Frosted glass effect
                VisualEffectBlur(blurStyle: .systemMaterial)
                    .cornerRadius(24)
                
                // Gradient border
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
                    // Background indicator
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Icon with badge
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
                
                // Tab title
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

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(AuthenticationManager.shared)
        .preferredColorScheme(.light)
}