//
//  MainTabView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var tabBarOffset: CGFloat = 0
    @State private var isTabBarHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var notificationBadges: [TabItem: Int] = [
        .home: 0,
        .shorts: 0,
        .upload: 0,
        .search: 0,
        .profile: 3 // Sample notification count
    ]
    
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
                    
                    LazyTabContent(tab: .shorts) {
                        ShortsView()
                    }
                    .tag(TabItem.shorts)
                    
                    LazyTabContent(tab: .upload) {
                        UploadView()
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
                    isHidden: isTabBarHidden
                )
                .offset(y: tabBarOffset)
                .animation(.easeInOut(duration: 0.3), value: tabBarOffset)
                .animation(.easeInOut(duration: 0.3), value: isTabBarHidden)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear notification badge for selected tab
            notificationBadges[newValue] = 0
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
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

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let notificationBadges: [TabItem: Int]
    let isHidden: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
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
                // Placeholder while loading
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        .scaleEffect(1.2)
                    Spacer()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .onAppear {
            // Delay loading to improve performance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Enhanced Tab Item Enum
enum TabItem: String, CaseIterable {
    case home = "home"
    case shorts = "shorts"
    case upload = "upload"
    case search = "search"
    case profile = "profile"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .shorts: return "Shorts"
        case .upload: return "Create"
        case .search: return "Search"
        case .profile: return "You"
        }
    }
    
    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .shorts:
            return isSelected ? "bolt.fill" : "bolt"
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
        case .shorts: return "Shorts tab"
        case .upload: return "Create content tab"
        case .search: return "Search tab"
        case .profile: return "Profile tab"
        }
    }
}

// MARK: - View Extensions
extension View {
    func onScrollOffsetChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .global).minY)
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: action)
    }
    
    func onPressGesture(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    MainTabView()
}