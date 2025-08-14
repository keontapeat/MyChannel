//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation
import Network

struct FlicksCommentsSheet: View {
    let video: Video
    var body: some View { ProfessionalCommentsSheet(video: video) }
}

struct FlicksShareSheet: View {
    let video: Video
    var body: some View { ProfessionalShareSheet(video: video) }
}

struct FlicksCreatorProfileView: View {
    let creator: User
    var body: some View { ProfessionalCreatorProfileView(creator: creator) }
}

struct FlicksSettingsPanel: View {
    var body: some View { ProfessionalFlicksSettingsPanel() }
}

// MARK: - Senior Level FlicksView (Clean Fullscreen, YouTube Shorts powered)
struct FlicksView: View {
    var isEmbeddedInTab: Bool = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var commentsVideo: Video?
    @State private var shareVideo: Video?
    @State private var selectedCreator: User?

    // Performance & lifecycle
    @State private var preloadedIndices: Set<Int> = []
    @State private var videoViewTimes: [String: TimeInterval] = [:]
    @State private var viewTimeTimer: Timer?
    @State private var didEngageWithFeed = false

    @AppStorage("flicks_feed_muted") private var flicksMuted: Bool = true

    // Network/Perf monitors
    @StateObject private var networkMonitor = FlicksNetworkMonitor()
    @StateObject private var performanceMonitor = FlicksPerformanceMonitor()

    // Haptics
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // Loading state
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var showLikeBurst = false
    @State private var likeBurstID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Flicks…")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if let loadError {
                    ContentUnavailableView("Flicks Unavailable", systemImage: "wifi.slash", description: Text(loadError))
                        .foregroundColor(.white)
                } else {
                    feed
                        .transition(.opacity)
                }
            }
            .statusBarHidden()
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await loadFlicksContent() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                if currentIndex < videos.count {
                    stopViewTimeTracking(for: videos[currentIndex])
                }
            case .active:
                if currentIndex < videos.count, viewTimeTimer == nil {
                    startViewTimeTracking(for: videos[currentIndex])
                }
            @unknown default: break
            }
        }
        .onAppear {
            didEngageWithFeed = false
        }
        .onDisappear {
            GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
        }
    }

    // MARK: - Fullscreen feed
    private var feed: some View {
        GeometryReader { geo in
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(videos.indices, id: \.self) { index in
                        ZStack {
                            if videos[index].contentSource == .youtube, let ytId = videos[index].externalID {
                                YouTubePlayerView(videoID: ytId, autoplay: true, startTime: 0, muted: flicksMuted, showControls: false)
                                    .background(Color.black)
                                    .ignoresSafeArea()
                            } else {
                                ProfessionalVideoPlayer(
                                    video: videos[index],
                                    isCurrentVideo: index == currentIndex,
                                    isLiked: likedVideos.contains(videos[index].id),
                                    isFollowing: followedCreators.contains(videos[index].creator.id),
                                    subscriberCount: subscriberCounts[videos[index].creator.id] ?? videos[index].creator.subscriberCount,
                                    onLike: {
                                        toggleLikeWithAnimation(for: videos[index])
                                        triggerLikeBurst()
                                    },
                                    onFollow: { toggleFollowWithAnimation(for: videos[index].creator) },
                                    onComment: { commentsVideo = videos[index] },
                                    onShare: { shareVideo = videos[index] },
                                    onProfileTap: { selectedCreator = videos[index].creator },
                                    overlayStyle: .minimal
                                )
                            }
                        }
                        .tag(index)
                        .onAppear {
                            preloadVideoIfNeeded(at: index)
                            startViewTimeTracking(for: videos[index])
                        }
                        .onDisappear {
                            stopViewTimeTracking(for: videos[index])
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
                .onChange(of: currentIndex) { old, new in
                    engageIfNeeded()
                    impactFeedback.impactOccurred()
                    if old < videos.count { trackVideoCompletion(for: videos[old]) }
                    preloadNextVideos(currentIndex: new)
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button {
                        flicksMuted.toggle()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.35))
                            Image(systemName: flicksMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, 44)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(true)

                Group {
                    if showLikeBurst {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 96, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8)
                            .transition(.scale.combined(with: .opacity))
                            .id(likeBurstID)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: showLikeBurst)
            }
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    if currentIndex < videos.count {
                        toggleLikeWithAnimation(for: videos[currentIndex])
                        triggerLikeBurst()
                    }
                }
            )
        }
    }

    // MARK: - Data loading (YouTube API)
    private func loadFlicksContent() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        if !AppSecrets.youtubeAPIKey.isEmpty {
            do {
                // Fetch multiple themed lanes to diversify
                async let a = YouTubeAPIService.shared.fetchShorts(query: "funny pets", maxResults: 20)
                async let b = YouTubeAPIService.shared.fetchShorts(query: "sports highlights", maxResults: 20)
                async let c = YouTubeAPIService.shared.fetchShorts(query: "tech tips", maxResults: 20)
                let results = (try await a) + (try await b) + (try await c)
                let dedup = Array(Dictionary(grouping: results, by: { $0.id }).values.compactMap { $0.first })
                let sorted = dedup.shuffled()
                if sorted.isEmpty {
                    videos = Video.sampleVideos
                } else {
                    videos = sorted
                }
            } catch {
                loadError = "Could not load YouTube shorts. Showing samples."
                videos = Video.sampleVideos
            }
        } else {
            videos = Video.sampleVideos
        }
    }

    // MARK: - Tracking
    private func startViewTimeTracking(for video: Video) {
        videoViewTimes[video.id] = Date().timeIntervalSince1970
        viewTimeTimer?.invalidate()
        viewTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in }
    }

    private func stopViewTimeTracking(for video: Video) {
        viewTimeTimer?.invalidate()
        viewTimeTimer = nil
        if let start = videoViewTimes[video.id] {
            let watchDuration = Date().timeIntervalSince1970 - start
            let _ = watchDuration
        }
    }

    private func trackVideoCompletion(for video: Video) {}

    // MARK: - Interactions
    private func toggleLikeWithAnimation(for video: Video) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
                notificationFeedback.notificationOccurred(.warning)
            } else {
                likedVideos.insert(video.id)
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }

    private func toggleFollowWithAnimation(for creator: User) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
                notificationFeedback.notificationOccurred(.warning)
            } else {
                followedCreators.insert(creator.id)
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }

    // MARK: - Preload
    private func preloadVideoIfNeeded(at index: Int) {
        guard !preloadedIndices.contains(index), networkMonitor.isConnected else { return }
        preloadedIndices.insert(index)
        let ahead = max(2, performanceMonitor.getRecommendedPreloadCount())
        let range = max(0, index - 1)...min(videos.count - 1, index + ahead)
        Task {
            for i in range {
                await preloadVideo(at: i)
            }
        }
    }

    private func preloadVideo(at index: Int) async {
        guard index < videos.count else { return }
        if videos[index].contentSource != .youtube {
            await MainActor.run {
                VideoPlayerManager.prewarm(urlString: videos[index].videoURL)
            }
        }
    }

    private func preloadNextVideos(currentIndex: Int) {
        guard performanceMonitor.shouldPreloadVideos(), networkMonitor.isConnected else { return }
        if currentIndex >= videos.count - 3 {
            // No-op for now; YouTube feed is large enough
        }
    }

    private func triggerLikeBurst() {
        likeBurstID = UUID()
        withAnimation {
            showLikeBurst = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showLikeBurst = false
            }
        }
    }

    private func engageIfNeeded() {
        if !didEngageWithFeed {
            GlobalVideoPlayerManager.shared.pauseForFlicksEngagement()
            didEngageWithFeed = true
        }
    }
}

extension Notification.Name {
    static let flicksPeekUpdate = Notification.Name("flicksPeekUpdate")
}

// MARK: - Preview
#Preview("FlicksView - Clean Fullscreen") {
    FlicksView(isEmbeddedInTab: true)
        .preferredColorScheme(.dark)
}