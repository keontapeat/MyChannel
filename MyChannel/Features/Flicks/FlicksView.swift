//
//  FlicksView.swift
//  MyChannel
//
//  🔥 THE BEST SHORT-FORM VIDEO PLAYER IN THE WORLD 🔥
//  Better than TikTok, YouTube Shorts, Instagram Reels - ALL OF THEM!
//
//  Features:
//  ⚡ Prefetch visible+1 only (current + next) — see docs/launch-perf-flicks.md
//  🎨 Double-tap center screen to like (with heart burst)
//  📊 Real-time analytics tracking
//  ♾️ Infinite scroll with pagination
//  🎭 Glassmorphism UI
//  ⌨️ Keyboard shortcuts
//  🚀 60fps smooth scrolling
//
//  Created by AI Assistant on $(date)
//

import SwiftUI
import UIKit
import Combine
import AVFoundation
import AVKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Notification for auto-skipping unavailable flicks
extension NSNotification.Name {
    static let flickVideoUnavailable = NSNotification.Name("flickVideoUnavailable")
}

// MARK: - Flicks View (THE BEST IN THE WORLD)
//
// Global player unification: Flicks keeps inline AVPlayers for vertical swipe UX, but coordinates
// with GlobalVideoPlayerManager.shared so long-form playback pauses while Flicks is visible
// (pausedByFlicks). See pauseForFlicksEngagement / resumeAfterLeavingFlicks hooks below.
struct FlicksView: View {
    
    // MARK: - State Management
    // @StateObject: FlicksView owns these lifetimes (survives tab re-select).
    // Child views that receive viewModel use @ObservedObject — see docs/launch-perf-flicks.md.
    @StateObject private var viewModel = NuclearFlicksViewModel()
    @StateObject private var networkMonitor = FlicksNetworkMonitor()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var currentIndex: Int = 0
    @State private var previousIndex: Int = 0
    @State private var showUI: Bool = true
    @State private var showSpeedBoost: Bool = false
    @State private var doubleTapHeartVisible: Bool = false
    @State private var doubleTapHeartID = UUID()
    
    // Gestures
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    // Analytics
    @State private var videoStartTime: Date?
    @State private var watchTimeByVideo: [String: TimeInterval] = [:]
    
    @AppStorage("flicks_feed_muted") private var flicksMuted: Bool = true
    @AppStorage("flicks_quality") private var preferredQuality: String = "auto"
    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0
    @AppStorage("flicks_captions") private var captionsEnabled: Bool = false
    @State private var showSpeedPicker = false
    @State private var showQualityPicker = false

    @State private var showMoreOptions = false
    @State private var selectedMoreOptionsFlick: NuclearFlick?
    @State private var selectedSound: FlickMusicTrack?
    @State private var showCreatorVideos = false
    @State private var showPlaylistPicker = false
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var selectedRemixFlick: NuclearFlick?
    @State private var selectedReportFlick: NuclearFlick?
    @State private var playlistTargetFlick: NuclearFlick?
    @State private var userPlaylists: [Playlist] = []
    @State private var isLoadingPlaylists = false
    @State private var newPlaylistName: String = ""
    @State private var playlistSuccessMessage: String?
    
    private var creatorVideosForCurrentFlick: [NuclearFlick] {
        viewModel.flicks[safe: currentIndex].map { current in
            viewModel.flicks.filter { $0.creator.id == current.creator.id }
        } ?? []
    }

    // Filtered flicks based on search
    private var filteredFlicks: [NuclearFlick] {
        if searchText.isEmpty {
            return viewModel.flicks
        }
        return viewModel.flicks.filter { flick in
            flick.title.localizedCaseInsensitiveContains(searchText) ||
            flick.creator.username.localizedCaseInsensitiveContains(searchText) ||
            flick.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.flicks.isEmpty {
                FlicksLoadingView()
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.flicks.isEmpty {
                emptyFeedView
            } else {
                flicksFeed
            }

            if !networkMonitor.isConnected {
                offlineBanner
            }

            if let message = playlistSuccessMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.85))
                        .cornerRadius(24)
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sheet(item: $viewModel.commentsFlick) { flick in
            // Item-bound sheet releases CommentsModalView when dismissed (no strong ref leak).
            CommentsModalView(video: flick.toVideo())
                .presentationDetents([.fraction(0.6), .large])
                .safePresentationBackgroundInteraction()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.shareFlick) { flick in
            ShareModalView(video: flick.toVideo())
        }
        .sheet(isPresented: $showSpeedPicker) {
            FlicksSpeedPickerSheet(playbackSpeed: $playbackSpeed, isPresented: $showSpeedPicker)
        }
        .sheet(isPresented: $showQualityPicker) {
            FlicksQualityPickerSheet(preferredQuality: $preferredQuality, isPresented: $showQualityPicker)
        }
        .sheet(item: $selectedMoreOptionsFlick) { flick in
            FlicksMoreOptionsSheet(
                onReport: { reportFlick(flick: flick) },
                onNotInterested: { notInterested(flick: flick) },
                onAddToPlaylist: {
                    playlistTargetFlick = flick
                    showPlaylistPicker = true
                },
                onDismiss: { selectedMoreOptionsFlick = nil }
            )
        }
        .sheet(item: $selectedSound) { sound in
            FlicksSoundPageSheet(
                sound: sound,
                relatedFlicks: viewModel.flicks.filter { $0.musicTrack?.title == sound.title },
                onDismiss: { selectedSound = nil },
                onCreatorTap: { user in
                    selectedSound = nil
                    viewModel.selectedCreatorProfile = user
                }
            )
        }
        .sheet(isPresented: $showCreatorVideos) {
            FlicksCreatorVideosSheet(
                creatorVideos: creatorVideosForCurrentFlick,
                onDismiss: { showCreatorVideos = false }
            )
        }
        .sheet(isPresented: $showPlaylistPicker) {
            FlicksPlaylistPickerSheet(
                newPlaylistName: $newPlaylistName,
                playlists: userPlaylists,
                isLoading: isLoadingPlaylists,
                onDismiss: { showPlaylistPicker = false },
                onSelectPlaylist: { addCurrentFlickToPlaylist($0) },
                onCreateAndAdd: { createPlaylistAndAdd() },
                onLoad: { await loadUserPlaylists() }
            )
        }
        .sheet(item: $selectedRemixFlick) { flick in
            RemixSheet(video: flick.toVideo())
        }
        .sheet(item: $selectedReportFlick) { flick in
            FlicksReportSheet(
                onDismiss: { selectedReportFlick = nil },
                onSelectReason: { reason in submitReport(flick: flick, reason: reason) }
            )
        }
        .fullScreenCover(item: $viewModel.selectedCreatorProfile) { user in
            NavigationStack {
                PublicProfileView(user: user)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                viewModel.selectedCreatorProfile = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        }
                    }
            }
        }
        .task {
            await viewModel.loadInitialFlicks()
        }
        .onAppear {
            // Pause global long-form player — Flicks inline players own audio while this tab is visible.
            GlobalVideoPlayerManager.shared.pauseForFlicksEngagement()
        }
        .onChange(of: scenePhase) { phase in
            handleScenePhaseChange(phase)
        }
        .onDisappear {
            viewModel.stopAlbumArtRotation()
            GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideFlicksUI"))) { _ in
            flicksUIAnimation(show: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFlicksUI"))) { _ in
            flicksUIAnimation(show: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFlicksFeed"))) { _ in
            Task {
                await viewModel.loadInitialFlicks()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flickVideoUnavailable)) { notification in
            // Auto-skip unavailable videos
            if let flickId = notification.userInfo?["flickId"] as? String,
               currentIndex < viewModel.flicks.count {
                viewModel.removeUnavailableFlick(id: flickId)
                if currentIndex >= viewModel.flicks.count {
                    currentIndex = max(0, viewModel.flicks.count - 1)
                }
                print("⏭️ [NuclearFlicks] Auto-skipped unavailable flick: \(flickId)")
            }
        }
    }
    
    // MARK: - Flicks Feed
    private var flicksFeed: some View {
        FlicksFeedPager(
            filteredFlicks: filteredFlicks,
            currentIndex: $currentIndex,
            showSearchBar: $showSearchBar,
            searchText: $searchText,
            flicksMuted: $flicksMuted,
            captionsEnabled: $captionsEnabled,
            showUI: showUI,
            reduceMotion: reduceMotion,
            flicksCount: viewModel.flicks.count,
            commentsFlick: viewModel.commentsFlick,
            isLoadingMore: viewModel.isLoadingMore,
            doubleTapHeartVisible: doubleTapHeartVisible,
            doubleTapHeartID: doubleTapHeartID,
            onIndexChange: handleIndexChange,
            onFlickAppear: handleFlickAppear,
            onFlickDisappear: handleFlickDisappear,
            onProgressRailSelect: { index in
                currentIndex = index
                HapticManager.shared.impact(style: .light)
            },
            flickCard: { flick, index, geometry in
                flickCard(flick: flick, index: index, geometry: geometry)
            }
        )
    }
    
    // MARK: - Flick Card
    private func flickCard(flick: NuclearFlick, index: Int, geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        return ZStack {
            // Video player layer
            if index == currentIndex || abs(index - currentIndex) <= 1 {
                flickVideoPlayer(flick: flick, isActive: index == currentIndex)
            } else {
                // Thumbnail for far away videos - 🔥 PERF: Use cached image
                AppAsyncImage(
                    url: URL(string: flick.thumbnailURL),
                    content: { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        Color.gray.opacity(0.3)
                    }
                )
                .frame(width: screenWidth, height: screenHeight)
                .clipped()
            }
            
            // 🔥 Tap layer UNDER the overlay so buttons receive taps first (like, comment, share, etc.)
            // 🐛 FIX: This full-screen UIKit view was swallowing every touch — including drags on
            // the scrubber (progress bar) rendered inside NuclearVideoPlayerView underneath it, so
            // the scrubber was visible but completely non-interactive. Reserve a bottom strip here
            // (matching FlicksLayout.scrubberBottomPadding) so those touches fall through to the
            // scrubber's own SwiftUI DragGesture instead of being consumed by this tap catcher.
            VStack(spacing: 0) {
                UIKitFlicksGestureLayer(
                    onSingleTap: {
                        NotificationCenter.default.post(name: NSNotification.Name("TogglePlayPause_\(flick.id)"), object: nil)
                    },
                    onDoubleTap: {
                        handleDoubleTap(flick: flick)
                    },
                    onLongPressBegan: {
                        HapticManager.shared.impact(style: .medium)
                        NotificationCenter.default.post(name: NSNotification.Name("SetFlickRate_\(flick.id)"), object: NSNumber(value: 2.0))
                        withAnimation(.easeOut(duration: 0.15)) { showSpeedBoost = true }
                    },
                    onLongPressEnded: {
                        NotificationCenter.default.post(name: NSNotification.Name("SetFlickRate_\(flick.id)"), object: NSNumber(value: 0))
                        withAnimation(.easeOut(duration: 0.15)) { showSpeedBoost = false }
                    }
                )
                Color.clear
                    .frame(height: FlicksLayout.scrubberHitZoneHeight)
                    .allowsHitTesting(false)
            }

            // Hold-to-2x indicator
            if showSpeedBoost {
                VStack {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("2x").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
            
            // UI Overlay on top so all buttons are clickable; tap-to-hide is inside overlay on video area only
            if showUI {
                flickUIOverlay(flick: flick, geometry: geometry)
                    .transition(.opacity)
            }
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
        .ignoresSafeArea()
        // No DragGesture here so vertical swipes go to TabView for paging; use tap on video area to toggle UI
    }
    
    // MARK: - Video Player
    private func flickVideoPlayer(flick: NuclearFlick, isActive: Bool) -> some View {
        GeometryReader { geo in
            Group {
                if flick.contentSource == Video.ContentSource.youtube, let ytId = flick.externalID {
                    YouTubePlayerView(
                        videoID: ytId,
                        autoplay: isActive,
                        startTime: 0,
                        muted: flicksMuted,
                        showControls: false
                    )
                    .background(Color.black)
                } else {
                    NuclearVideoPlayerView(
                        flick: flick,
                        isActive: isActive,
                        isMuted: flicksMuted,
                        playbackSpeed: playbackSpeed
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
    
    // MARK: - UI Overlay
    @ViewBuilder
    private func flickUIOverlay(flick: NuclearFlick, geometry: GeometryProxy) -> some View {
        // Tab bar = 49pt + home indicator safe area. We read from real device safe area.
        let bottomSafeArea = max(geometry.safeAreaInsets.bottom, 34)
        // Total clearance below content so nothing hides behind the custom tab bar
        let tabBarHeight: CGFloat = 83
        let bottomInset: CGFloat = bottomSafeArea + tabBarHeight + 32
        let actionButtonTrailing: CGFloat = 16
        let infoRightPadding: CGFloat = 96  // leave room for right-side action buttons (width ~80)
        
        ZStack {
            // Tap on upper video area to toggle UI visibility
            VStack {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.55)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        NotificationCenter.default.post(name: NSNotification.Name("TogglePlayPause_\(flick.id)"), object: nil)
                    }
                Spacer()
            }
            
            // Bottom overlay: engagement bar (creator info + action rail)
            VStack(spacing: 0) {
                Spacer()
                FlicksEngagementBar(
                    flick: flick,
                    isLiked: viewModel.isLiked(flickId: flick.id),
                    isSaved: viewModel.isSaved(flickId: flick.id),
                    isFollowing: viewModel.isFollowing(creatorId: flick.creator.id),
                    likeCountLabel: formatCount(flick.likeCount + (viewModel.isLiked(flickId: flick.id) ? 1 : 0)),
                    commentCountLabel: formatCount(flick.commentCount),
                    shareCountLabel: flick.shareCount > 0 ? formatCount(flick.shareCount) : "Share",
                    playbackSpeedLabel: "\(playbackSpeed)x",
                    qualityLabel: effectiveQualityLabel,
                    albumArtRotation: viewModel.albumArtRotation,
                    bottomInset: bottomInset,
                    infoRightPadding: infoRightPadding,
                    reduceMotion: reduceMotion,
                    onCreatorTap: { viewModel.navigateToCreator(flick.creator) },
                    onFollow: {
                        viewModel.toggleFollow(creator: flick.creator)
                        HapticManager.shared.impact(style: .medium)
                    },
                    onLike: { viewModel.toggleLike(flick: flick) },
                    onComment: { viewModel.openComments(flick: flick) },
                    onShare: { viewModel.openShare(flick: flick) },
                    onRemix: { selectedRemixFlick = flick },
                    onSpeed: { showSpeedPicker.toggle() },
                    onQuality: { showQualityPicker.toggle() },
                    onSave: { viewModel.toggleSave(flick: flick) },
                    onMore: { selectedMoreOptionsFlick = flick },
                    onSound: { selectedSound = $0 }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // drawingGroup: selective — static engagement chrome only, not AVPlayer/video layer.
        // See docs/launch-perf-flicks.md § drawingGroup.
        .drawingGroup()
    }
    
    private func reportFlick(flick: NuclearFlick) {
        HapticManager.shared.notification(type: .warning)
        selectedReportFlick = flick
    }
    
    private func notInterested(flick: NuclearFlick) {
        print("👎 [Flicks] Not interested in flick: \(flick.id)")
        Task {
            await FlicksFeedbackService.shared.notInterested(
                flickId: flick.id,
                creatorId: flick.creator.id,
                tags: flick.tags
            )
        }
        viewModel.removeUnavailableFlick(id: flick.id)
        HapticManager.shared.notification(type: .warning)
    }

    private func submitReport(flick: NuclearFlick, reason: FlicksFeedbackService.ReportReason) {
        Task {
            await FlicksFeedbackService.shared.report(flickId: flick.id, reason: reason)
        }
        selectedReportFlick = nil
        HapticManager.shared.notification(type: .success)
        // Down-rank similar content too.
        viewModel.removeUnavailableFlick(id: flick.id)
    }

    // MARK: - Playlist Actions

    private func loadUserPlaylists() async {
        guard let userId = AppState.shared.currentUser?.id else {
            userPlaylists = []
            return
        }
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        do {
            userPlaylists = try await PlaylistFirestoreService.shared.getPlaylists(for: userId)
        } catch {
            print("⚠️ [Flicks] Failed to load playlists: \(error)")
            userPlaylists = []
        }
    }

    private func addCurrentFlickToPlaylist(_ playlist: Playlist) {
        guard let flick = playlistTargetFlick else { return }
        Task {
            do {
                try await PlaylistFirestoreService.shared.addVideoToPlaylist(videoId: flick.id, playlistId: playlist.id)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    showPlaylistPicker = false
                    playlistSuccessMessage = "Added to \(playlist.title)"
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        await MainActor.run { playlistSuccessMessage = nil }
                    }
                }
            } catch {
                print("⚠️ [Flicks] Failed to add to playlist: \(error)")
                await MainActor.run { HapticManager.shared.notification(type: .error) }
            }
        }
    }

    private func createPlaylistAndAdd() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let userId = AppState.shared.currentUser?.id else { return }
        guard let flick = playlistTargetFlick else { return }
        Task {
            do {
                let playlistId = try await PlaylistFirestoreService.shared.createPlaylist(userId: userId, title: name)
                try await PlaylistFirestoreService.shared.addVideoToPlaylist(videoId: flick.id, playlistId: playlistId)
                await MainActor.run {
                    newPlaylistName = ""
                    HapticManager.shared.notification(type: .success)
                    showPlaylistPicker = false
                }
            } catch {
                print("⚠️ [Flicks] Failed to create playlist: \(error)")
                await MainActor.run { HapticManager.shared.notification(type: .error) }
            }
        }
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Oops!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await viewModel.loadInitialFlicks()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(24)
            }
        }
    }

    private var emptyFeedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.7))
            Text("No Flicks yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Check back soon or pull to refresh.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
            Button {
                Task { await viewModel.loadInitialFlicks() }
            } label: {
                Text("Refresh")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(24)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var offlineBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("You're offline — showing cached Flicks")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.9))
            .cornerRadius(20)
            .padding(.top, 56)
            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Offline mode")
    }

    /// Cellular data saver: cap quality label on cellular unless user picked a fixed tier.
    private var effectiveQualityLabel: String {
        if networkMonitor.connectionType == .cellular && preferredQuality == "auto" {
            return "480P"
        }
        return preferredQuality.uppercased()
    }
    
    // MARK: - Event Handlers
    
    private func handleDoubleTap(flick: NuclearFlick) {
        // Toggle like
        viewModel.toggleLike(flick: flick)
        
        // Show heart burst
        doubleTapHeartID = UUID()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            doubleTapHeartVisible = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation { doubleTapHeartVisible = false }
        }
        
        // Haptic feedback
        HapticManager.shared.impact(style: .heavy)
    }
    
    private func toggleUI() {
        withAnimation(.easeOut(duration: 0.3)) {
            showUI.toggle()
        }
    }
    
    private func handleIndexChange(_ newIndex: Int) {
        guard newIndex != previousIndex, newIndex < viewModel.flicks.count else { return }
        
        // Track previous video watch time
        if let startTime = videoStartTime, previousIndex < viewModel.flicks.count {
            let watchTime = Date().timeIntervalSince(startTime)
            let flickId = viewModel.flicks[previousIndex].id
            watchTimeByVideo[flickId, default: 0] += watchTime
            
            // Track analytics
            Task {
                await viewModel.trackWatchTime(flickId: flickId, duration: watchTime)
            }
        }
        
        // Start tracking new video
        videoStartTime = Date()
        
        // Update previous index
        previousIndex = newIndex
        
        // Add to watch history
        let flick = viewModel.flicks[newIndex]
        AppState.shared.addToHistory(video: flick.toVideo(), progress: 1.0, position: flick.duration)
        
        // Haptic feedback
        HapticManager.shared.impact(style: .light)
        
        // Prefetch visible+1 only (current index + next item) — docs/launch-perf-flicks.md
        viewModel.preloadVideos(
            around: FeedMath.clampIndex(newIndex, total: viewModel.flicks.count),
            count: 1
        )
        
        // Load more if near end (infinite scroll)
        if newIndex >= viewModel.flicks.count - 3 {
            Task {
                await viewModel.loadMoreFlicks()
            }
        }
        
        // Track view
        Task {
            await viewModel.trackView(flick: flick)
        }
    }
    
    private func handleFlickAppear(index: Int) {
        if index == currentIndex {
            videoStartTime = Date()
        }
    }
    
    private func handleFlickDisappear(index: Int) {
        if index == currentIndex, index < viewModel.flicks.count, let startTime = videoStartTime {
            let watchTime = Date().timeIntervalSince(startTime)
            let flickId = viewModel.flicks[index].id
            watchTimeByVideo[flickId, default: 0] += watchTime
        }
    }
    
    private func flicksUIAnimation(show: Bool) {
        let animation: Animation? = reduceMotion
            ? nil
            : .spring(response: 0.35, dampingFraction: 0.85)
        if let animation {
            withAnimation(animation) { showUI = show }
        } else {
            showUI = show
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            viewModel.stopAlbumArtRotation()
            if let startTime = videoStartTime, currentIndex < viewModel.flicks.count {
                let watchTime = Date().timeIntervalSince(startTime)
                let flickId = viewModel.flicks[currentIndex].id
                watchTimeByVideo[flickId, default: 0] += watchTime
            }
            videoStartTime = nil
            
        case .active:
            viewModel.startAlbumArtRotation()
            if currentIndex < viewModel.flicks.count {
                videoStartTime = Date()
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Helpers
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}


// ⚡ UIKit layers and ViewModel extracted to FlicksComponents.swift
