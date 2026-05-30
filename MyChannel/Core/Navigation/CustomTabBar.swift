// ⚡ PERFORMANCE: Extracted from MainTabView.swift — independent compilation unit.
// CustomTabBar + all tab button components. 634 lines compile in parallel
// with MainTabView.swift instead of as one 1807-line unit.
import SwiftUI

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



