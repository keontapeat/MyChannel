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
    @State private var user: User = User.sampleUsers[0]
    @State private var isFollowing: Bool = false
    @State private var userVideos: [Video] = Video.sampleVideos
    @State private var scrollOffset: CGFloat = 0

    var currentUser: User {
        authManager.currentUser ?? User.sampleUsers[0]
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Combined Header + Tabs (NO GAP POSSIBLE!)
                ProfileHeaderView(
                    user: currentUser,
                    scrollOffset: scrollOffset,
                    isFollowing: $isFollowing,
                    showingEditProfile: $showingEditProfile,
                    showingSettings: $showingSettings,
                    selectedTab: $selectedTab
                )
                .ignoresSafeArea(edges: .top)
                
                // Scrollable Content Area
                ScrollView {
                    VStack(spacing: 0) {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ProfileScrollOffsetPreferenceKey.self, 
                                          value: proxy.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)
                        
                        ProfileContentView(
                            selectedTab: selectedTab,
                            user: currentUser,
                            videos: userVideos
                        )
                        .padding(.top, 0)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ProfileScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(user: Binding(
                get: { currentUser },
                set: { newUser in
                    authManager.updateUser(newUser)
                }
            ))
        }
        .sheet(isPresented: $showingSettings) {
            ProfileSettingsView()
        }
        .onAppear {
            user = currentUser
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopProfile)) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                HapticManager.shared.impact(style: .light)
            }
        }
    }
}

// MARK: - Profile-specific ScrollOffset PreferenceKey
struct ProfileScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ProfileView()
        .environmentObject({
            let authManager = AuthenticationManager.shared
            authManager.currentUser = User.sampleUsers[0]
            return authManager
        }())
        .environmentObject({
            let appState = AppState()
            appState.currentUser = User.sampleUsers[0]
            return appState
        }())
        .environmentObject(GlobalVideoPlayerManager.shared)
}