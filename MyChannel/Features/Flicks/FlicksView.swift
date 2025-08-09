//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit

// MARK: - Flicks Components (Wrappers for quick access in this file)
struct FlicksCommentsSheet: View {
    let video: Video
    var body: some View {
        ProfessionalCommentsSheet(video: video)
    }
}

struct FlicksShareSheet: View {
    let video: Video
    var body: some View {
        ProfessionalShareSheet(video: video)
    }
}

struct FlicksCreatorProfileView: View {
    let creator: User
    var body: some View {
        ProfessionalCreatorProfileView(creator: creator)
    }
}

struct FlicksSettingsPanel: View {
    var body: some View {
        ProfessionalFlicksSettingsPanel()
    }
}

// MARK: - Component Previews
#Preview("Flicks Comments Sheet") {
    FlicksCommentsSheet(video: Video.sampleVideos.first ?? Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Share Sheet") {
    FlicksShareSheet(video: Video.sampleVideos.first ?? Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Creator Profile") {
    FlicksCreatorProfileView(creator: User.sampleUsers.first ?? User.sampleUsers[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Settings Panel") {
    FlicksSettingsPanel()
        .preferredColorScheme(.dark)
}

// MARK: - Main Flicks View

struct FlicksView: View {
    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var selectedCreator: User?
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var showingFlicksSettings = false

    @State private var commentsVideo: Video?
    @State private var shareVideo: Video?

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else {
                        verticalVideoFeed(geometry: geometry)
                    }
                    
                    topOverlay
                        .zIndex(2)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden()
            .task {
                if videos.isEmpty { loadFlicksContent() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FlicksResetToFirst"))) { _ in
                resetToFirstVideo()
            }
            .sheet(item: $commentsVideo) { video in
                FlicksCommentsSheet(video: video)
                    .presentationDetents([.height(200), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $shareVideo) { video in
                FlicksShareSheet(video: video)
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedCreator) { creator in
                FlicksCreatorProfileView(creator: creator)
            }
            .sheet(isPresented: $showingFlicksSettings) {
                FlicksSettingsPanel()
                    .presentationDetents([.height(600), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.8),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                    
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.3),
                            value: UUID()
                        )
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                
                VStack(spacing: 12) {
                    Text("Flicks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("Loading amazing content...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: UUID()
                            )
                    }
                }
            }
        }
    }
    
    private var topOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .accessibilityLabel("Home")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Flicks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchBar"), object: nil)
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .accessibilityLabel("Search")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingFlicksSettings = true
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .accessibilityLabel("Flicks Settings")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }
    
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
                ProfessionalVideoPlayer(
                    video: videos[index],
                    isCurrentVideo: index == currentIndex,
                    isLiked: likedVideos.contains(videos[index].id),
                    isFollowing: followedCreators.contains(videos[index].creator.id),
                    subscriberCount: subscriberCounts[videos[index].creator.id] ?? videos[index].creator.subscriberCount,
                    onLike: {
                        toggleLike(for: videos[index])
                    },
                    onFollow: {
                        toggleFollow(for: videos[index].creator)
                    },
                    onComment: {
                        commentsVideo = videos[index]
                    },
                    onShare: {
                        shareVideo = videos[index]
                    },
                    onProfileTap: {
                        selectedCreator = videos[index].creator
                    }
                )
                .id(videos[index].id)
                .tag(index)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(AppTheme.AnimationPresets.spring, value: currentIndex)
        .onChange(of: currentIndex) { _, newValue in
            impactFeedback.impactOccurred()
            preloadNextVideos(currentIndex: newValue)
        }
    }
    
    private func loadFlicksContent() {
        Task {
            isLoading = true
            try? await Task.sleep(nanoseconds: 750_000_000)
            videos = Video.sampleVideos.shuffled()
            isLoading = false
        }
    }
    
    private func resetToFirstVideo() {
        guard !videos.isEmpty && currentIndex != 0 else { return }
        withAnimation(AppTheme.AnimationPresets.spring) {
            currentIndex = 0
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleLike(for video: Video) {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
            } else {
                likedVideos.insert(video.id)
            }
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleFollow(for creator: User) {
        withAnimation(AppTheme.AnimationPresets.spring) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
            } else {
                followedCreators.insert(creator.id)
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
            }
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func preloadNextVideos(currentIndex: Int) {
        if currentIndex >= videos.count - 3 {
            Task {
                let more = Array(Video.sampleVideos.shuffled().prefix(6))
                videos.append(contentsOf: more)
            }
        }
    }
}

// MARK: - Previews

#Preview("FlicksView") {
    FlicksView()
        .preferredColorScheme(.dark)
}