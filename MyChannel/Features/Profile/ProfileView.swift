//
//  ProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//



import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ProfileTab = .videos
    @State private var showingSettings: Bool = false
    @State private var showingEditProfile: Bool = false
    @State private var user: User = User.defaultUser
    @State private var isFollowing: Bool = false
    @State private var userVideos: [Video] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""

    private var currentUser: User {
        if let appUser = appState.currentUser {
            return appUser
        } else if let authUser = authManager.currentUser {
            return authUser
        } else {
            return User.defaultUser
        }
    }

    var body: some View {
        Group {
            if hasError {
                profileErrorView
            } else if isLoading {
                profileLoadingView
            } else {
                profileContent
            }
        }
        .onAppear {
            loadProfileSafely()
        }
        .onChange(of: authManager.currentUser) { _, newUser in
            handleUserChange(newUser)
        }
        .onChange(of: appState.currentUser) { _, newUser in
            handleUserChange(newUser)
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopProfile)) { _ in
            handleScrollToTop()
        }
    }

    // MARK: - Main Profile Content

    @ViewBuilder
    private var profileContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                AppTheme.Colors.background
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    SafeProfileHeaderView(
                        user: user,
                        scrollOffset: scrollOffset,
                        isFollowing: $isFollowing,
                        showingEditProfile: $showingEditProfile,
                        showingSettings: $showingSettings
                    )
                    .ignoresSafeArea(edges: .top)

                    ProfileTabNavigation(
                        selectedTab: $selectedTab,
                        user: user
                    )

                    ScrollView {
                        VStack(spacing: 0) {
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: ProfileScrollOffsetPreferenceKey.self,
                                                value: proxy.frame(in: .named("scroll")).minY)
                            }
                            .frame(height: 0)

                            SafeProfileContentView(
                                selectedTab: selectedTab,
                                user: user,
                                videos: userVideos
                            )
                            .padding(.top, 0)
                            .background(AppTheme.Colors.background)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ProfileScrollOffsetPreferenceKey.self) { value in
                        withAnimation(.easeOut(duration: 0.1)) {
                            scrollOffset = value
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            NavigationStack {
                EditProfileView(user: $user)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SafeProfileSettingsView()
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var profileLoadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.Colors.primary)

            Text("Loading Profile...")
                .font(.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationBarHidden(true)
    }

    // MARK: - Error View

    @ViewBuilder
    private var profileErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)

            VStack(spacing: 8) {
                Text("Profile Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(errorMessage.isEmpty ? "Unable to load profile" : errorMessage)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Try Again") {
                retryLoadProfile()
            }
            .buttonStyle(ProfileRetryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationBarHidden(true)
    }

    // MARK: - Helpers

    private func loadProfileSafely() {
        isLoading = true
        hasError = false
        errorMessage = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                user = currentUser

                if Video.sampleVideos.isEmpty {
                    userVideos = createFallbackVideos()
                } else {
                    userVideos = Array(Video.sampleVideos.prefix(20))
                }

                isLoading = false
                hasError = false

                print("✅ Profile loaded successfully for user: \(user.displayName)")
            } catch {
                handleError("Failed to load profile: \(error.localizedDescription)")
            }
        }
    }

    private func createFallbackVideos() -> [Video] {
        return [
            Video(
                title: "Welcome to MyChannel!",
                description: "Getting started with content creation",
                thumbnailURL: "https://picsum.photos/1280/720?random=1",
                videoURL: "https://example.com/video1.mp4",
                duration: 180,
                viewCount: 1234,
                likeCount: 89,
                commentCount: 23,
                creator: user,
                category: .entertainment,
                tags: ["Welcome", "Getting Started"]
            ),
            Video(
                title: "Behind the Scenes",
                description: "A look at how content is made",
                thumbnailURL: "https://picsum.photos/1280/720?random=2",
                videoURL: "https://example.com/video2.mp4",
                duration: 300,
                viewCount: 856,
                likeCount: 45,
                commentCount: 12,
                creator: user,
                category: .entertainment,
                tags: ["Behind the Scenes"]
            )
        ]
    }

    private func handleUserChange(_ newUser: User?) {
        DispatchQueue.main.async {
            if let newUser = newUser {
                user = newUser
                userVideos = Video.sampleVideos.isEmpty ? createFallbackVideos() : Array(Video.sampleVideos.prefix(20))
            } else {
                user = User.defaultUser
                userVideos = createFallbackVideos()
            }
        }
    }

    private func handleScrollToTop() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.8)) {
                HapticManager.shared.impact(style: .light)
                // implement scroll to top logic if needed
            }
        }
    }

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            hasError = true
            isLoading = false

            print("❌ Profile error: \(message)")
        }
    }

    private func retryLoadProfile() {
        hasError = false
        errorMessage = ""
        loadProfileSafely()
    }
}

// MARK: - SafeProfileHeaderView (Updated – No selectedTab)

struct SafeProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool

    var body: some View {
        SafeViewWrapper {
            ProfileHeaderView(
                user: user,
                scrollOffset: scrollOffset,
                isFollowing: $isFollowing,
                showingEditProfile: $showingEditProfile,
                showingSettings: $showingSettings
            )
        } fallback: {
            VStack {
                Rectangle()
                    .fill(AppTheme.Colors.primary.opacity(0.3))
                    .frame(height: 365)

                Text("Header unavailable")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding()
            }
        }
    }
}


#Preview {
    NavigationView {
        ProfileView()
            .environmentObject({
                let authManager = AuthenticationManager.shared
                authManager.currentUser = User.sampleUsers.isEmpty ? User.defaultUser : User.sampleUsers[0]
                return authManager
            }())
            .environmentObject({
                let appState = AppState()
                appState.currentUser = User.sampleUsers.isEmpty ? User.defaultUser : User.sampleUsers[0]
                return appState
            }())
            .environmentObject(GlobalVideoPlayerManager.shared)
    }
}