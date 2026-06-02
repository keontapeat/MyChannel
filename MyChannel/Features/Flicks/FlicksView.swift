//
//  FlicksView.swift
//  MyChannel
//
//  🔥 THE BEST SHORT-FORM VIDEO PLAYER IN THE WORLD 🔥
//  Better than TikTok, YouTube Shorts, Instagram Reels - ALL OF THEM!
//
//  Features:
//  ⚡ Aggressive preloading (+5 videos ahead)
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
struct FlicksView: View {
    
    // MARK: - State Management
    @StateObject private var viewModel = NuclearFlicksViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var currentIndex: Int = 0
    @State private var previousIndex: Int = 0
    @State private var showUI: Bool = true
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
    @State private var savedVideoIds: Set<String> = UserDefaults.standard.stringArray(forKey: "saved_videos").map { Set($0) } ?? []
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
    
    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.flicks.isEmpty {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else {
                flicksFeed
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sheet(item: $viewModel.commentsFlick) { flick in
            CommentsModalView(video: flick.toVideo())
                .presentationDetents([.fraction(0.6), .large])
                .safePresentationBackgroundInteraction()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.shareFlick) { flick in
            ShareModalView(video: flick.toVideo())
        }
        .sheet(isPresented: $showSpeedPicker) {
            speedPickerSheet
        }
        .sheet(isPresented: $showQualityPicker) {
            qualityPickerSheet
        }
        .sheet(item: $selectedMoreOptionsFlick) { flick in
            moreOptionsSheet(flick: flick)
        }
        .sheet(item: $selectedSound) { sound in
            soundPage(sound: sound)
        }
        .sheet(isPresented: $showCreatorVideos) {
            creatorVideosSheet
        }
        .sheet(isPresented: $showPlaylistPicker) {
            playlistPickerSheet
        }
        .sheet(item: $selectedRemixFlick) { flick in
            RemixSheet(video: flick.toVideo())
        }
        .sheet(item: $selectedReportFlick) { flick in
            reportSheet(flick: flick)
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
        .onChange(of: scenePhase) { phase in
            handleScenePhaseChange(phase)
        }
        .onDisappear {
            viewModel.stopAlbumArtRotation()
            GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideFlicksUI"))) { _ in
            withAnimation(.easeOut(duration: 0.3)) { showUI = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFlicksUI"))) { _ in
            withAnimation(.easeOut(duration: 0.3)) { showUI = true }
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
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            ZStack {
                // Vertical paging via TabView with .page style - direct vertical scroll, no rotation trick
                TabView(selection: $currentIndex) {
                    ForEach(Array(filteredFlicks.enumerated()), id: \.element.id) { index, flick in
                        flickCard(flick: flick, index: index, geometry: geometry)
                            .frame(width: screenWidth, height: screenHeight)
                            .ignoresSafeArea()
                            .tag(index)
                            .onAppear {
                                handleFlickAppear(index: index)
                            }
                            .onDisappear {
                                handleFlickDisappear(index: index)
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: screenWidth, height: screenHeight)
                .ignoresSafeArea()
                .scaleEffect(viewModel.commentsFlick != nil ? 0.93 : 1.0, anchor: .top)
                .offset(y: viewModel.commentsFlick != nil ? geometry.safeAreaInsets.top : 0)
                .cornerRadius(viewModel.commentsFlick != nil ? 16 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.commentsFlick != nil)
                .onChange(of: currentIndex) { newIndex in
                    handleIndexChange(newIndex)
                }
                .ignoresSafeArea()
                
                // 🔥 DOUBLE-TAP CENTER HEART BURST (TikTok style)
                if doubleTapHeartVisible {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 20)
                        .scaleEffect(doubleTapHeartVisible ? 1.2 : 0.5)
                        .opacity(doubleTapHeartVisible ? 1 : 0)
                        .transition(.scale.combined(with: .opacity))
                        .id(doubleTapHeartID)
                        .allowsHitTesting(false)
                }
                
                // Top mute button (glassmorphism)
                topControls
                
                UIKitFlicksProgressRail(
                    count: viewModel.flicks.count,
                    currentIndex: $currentIndex,
                    reduceMotion: reduceMotion,
                    onSelect: { index in
                        currentIndex = index
                        impactLight.impactOccurred()
                    }
                )
                .frame(width: 24)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(showUI)
                .opacity(showUI ? 1 : 0)
                
                // Loading more indicator
                if viewModel.isLoadingMore {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Loading more...")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding()
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
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
            UIKitFlicksGestureLayer(
                onSingleTap: {
                    NotificationCenter.default.post(name: NSNotification.Name("TogglePlayPause_\(flick.id)"), object: nil)
                },
                onDoubleTap: {
                    handleDoubleTap(flick: flick)
                },
                onLongPressBegan: {
                    impactMedium.impactOccurred()
                }
            )
            
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
            
            // Bottom overlay: left info + right action buttons
            VStack(spacing: 0) {
                Spacer()
                
                HStack(alignment: .bottom, spacing: 0) {
                    // Left side - Video info (title, creator, tags)
                    VStack(alignment: .leading, spacing: 10) {
                        // Creator row
                        HStack(spacing: 10) {
                            Button {
                                viewModel.navigateToCreator(flick.creator)
                            } label: {
                                AppAsyncImage(
                                    url: URL(string: flick.creator.profileImageURL),
                                    content: { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Circle().fill(Color.white.opacity(0.3))
                                    }
                                )
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(flick.creator.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if flick.creator.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                            .fixedSize()
                                    }
                                }
                                
                                Text("@\(flick.creator.username)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                            
                            // Follow button
                            Button {
                                viewModel.toggleFollow(creator: flick.creator)
                                impactMedium.impactOccurred()
                            } label: {
                                Text(viewModel.isFollowing(creatorId: flick.creator.id) ? "Following" : "Follow")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                            
                            // Creator's other videos button
                            Button {
                                showCreatorVideos = true
                                impactLight.impactOccurred()
                            } label: {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .fixedSize()
                            .layoutPriority(1)
                        }
                        
                        // Video title
                        Text(flick.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // Tags
                        if !flick.tags.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(flick.tags.prefix(4), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Music track
                        if let musicTrack = flick.musicTrack {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                
                                Text("\(musicTrack.title) • \(musicTrack.artist)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, infoRightPadding)
                    
                    // Right side action buttons column
                    actionButtons(
                        flick: flick,
                        bottomSafeArea: 0,
                        trailingPadding: 0,
                        tabBarReserved: 0
                    )
                    .frame(width: 72, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, bottomInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Action Buttons (Glassmorphism)
    private func actionButtons(
        flick: NuclearFlick,
        bottomSafeArea: CGFloat,
        trailingPadding: CGFloat,
        tabBarReserved: CGFloat = 0
    ) -> some View {
        VStack(spacing: 20) {
            // Like button
            actionButton(
                icon: viewModel.isLiked(flickId: flick.id) ? "heart.fill" : "heart",
                count: formatCount(flick.likeCount + (viewModel.isLiked(flickId: flick.id) ? 1 : 0)),
                color: viewModel.isLiked(flickId: flick.id) ? .red : .white,
                scale: viewModel.isLiked(flickId: flick.id) ? 1.1 : 1.0
            ) {
                viewModel.toggleLike(flick: flick)
                impactMedium.impactOccurred()
            }
            
            // Comment button
            actionButton(
                icon: "bubble.right.fill",
                count: formatCount(flick.commentCount),
                color: .white
            ) {
                viewModel.openComments(flick: flick)
                impactLight.impactOccurred()
            }
            
            // Share button
            actionButton(
                icon: "arrowshape.turn.up.right.fill",
                count: flick.shareCount > 0 ? formatCount(flick.shareCount) : "Share",
                color: .white
            ) {
                viewModel.openShare(flick: flick)
                impactLight.impactOccurred()
            }
            
            // Remix button
            actionButton(
                icon: "arrow.triangle.2.circlepath",
                count: "Remix",
                color: .white
            ) {
                selectedRemixFlick = flick
                impactLight.impactOccurred()
            }
            
            // Speed button
            actionButton(
                icon: "gauge.with.dots.needle.67percent",
                count: "\(playbackSpeed)x",
                color: .white
            ) {
                showSpeedPicker.toggle()
                impactLight.impactOccurred()
            }
            
            // Quality button
            actionButton(
                icon: "gearshape.fill",
                count: preferredQuality.uppercased(),
                color: .white
            ) {
                showQualityPicker.toggle()
                impactLight.impactOccurred()
            }
            
            // Save button
            actionButton(
                icon: savedVideoIds.contains(flick.id) ? "bookmark.fill" : "bookmark",
                count: "Save",
                color: savedVideoIds.contains(flick.id) ? .yellow : .white
            ) {
                toggleSave(flick: flick)
                impactMedium.impactOccurred()
            }
            
            // More button
            actionButton(
                icon: "ellipsis",
                count: "",
                color: .white
            ) {
                selectedMoreOptionsFlick = flick
                impactLight.impactOccurred()
            }
            
            // Music album art (spinning) - 🔥 PERF: Use cached image
            if let musicTrack = flick.musicTrack {
                Button {
                    selectedSound = musicTrack
                    impactLight.impactOccurred()
                } label: {
                    AppAsyncImage(
                        url: URL(string: musicTrack.albumArt),
                        content: { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Circle().fill(Color.white.opacity(0.3))
                        }
                    )
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .rotationEffect(.degrees(viewModel.albumArtRotation))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.trailing, trailingPadding)
        .padding(.bottom, tabBarReserved)
    }
    
    private func actionButton(icon: String, count: String, color: Color, scale: CGFloat = 1.0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                        .scaleEffect(scale)
                }
                
                if !count.isEmpty {
                    Text(count)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        VStack {
            HStack {
                // Search button
                Button {
                    showSearchBar.toggle()
                    impactLight.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Mute button (glassmorphism)
                Button {
                    flicksMuted.toggle()
                    impactLight.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: flicksMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                // Captions (CC) toggle button
                Button {
                    captionsEnabled.toggle()
                    impactLight.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(captionsEnabled ? Color.white.opacity(0.9) : Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "captions.bubble.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(captionsEnabled ? .black : .white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()
            }
            .padding(.top, 56)
            .padding(.trailing, 24)
            .padding(.leading, 20)
            
            // Search bar
            if showSearchBar {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Search Flicks...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            impactLight.impactOccurred()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.55))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .opacity(showUI ? 1 : 0)
        .allowsHitTesting(showUI)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            
            Text("Loading Flicks...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Quality Picker Sheet
    private var qualityPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Video Quality")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                VStack(spacing: 12) {
                    ForEach(["auto", "360p", "480p", "720p", "1080p"], id: \.self) { quality in
                        Button {
                            preferredQuality = quality
                            showQualityPicker = false
                            impactMedium.impactOccurred()
                        } label: {
                            HStack {
                                Text(quality.uppercased())
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if preferredQuality == quality {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(preferredQuality == quality ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func moreOptionsSheet(flick: NuclearFlick) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("More Options")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        selectedMoreOptionsFlick = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Options
                VStack(spacing: 0) {
                    Button {
                        reportFlick(flick: flick)
                        selectedMoreOptionsFlick = nil
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                            Text("Report")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    Button {
                        notInterested(flick: flick)
                        selectedMoreOptionsFlick = nil
                    } label: {
                        HStack {
                            Image(systemName: "hand.thumbsdown")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text("Not Interested")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    Button {
                        selectedMoreOptionsFlick = nil
                        playlistTargetFlick = flick
                        showPlaylistPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Add to Playlist")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                
                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
    
    private func reportFlick(flick: NuclearFlick) {
        notificationFeedback.notificationOccurred(.warning)
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
        notificationFeedback.notificationOccurred(.warning)
    }
    
    private func soundPage(sound: FlickMusicTrack) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        selectedSound = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Sound")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // Share sound
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Sound info
                VStack(spacing: 16) {
                    AppAsyncImage(
                        url: URL(string: sound.albumArt),
                        content: { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    
                    VStack(spacing: 8) {
                        Text(sound.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(sound.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 32)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Videos using this sound
                ScrollView {
                    let videosWithSound = viewModel.flicks.filter { $0.musicTrack?.title == sound.title }
                    LazyVStack(spacing: 12) {
                        ForEach(videosWithSound) { flick in
                            HStack(spacing: 12) {
                                AppAsyncImage(
                                    url: URL(string: flick.thumbnailURL),
                                    content: { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                )
                                .frame(width: 80, height: 142)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(flick.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    
                                    Text("@\(flick.creator.username)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private var playlistPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        showPlaylistPicker = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Save to Playlist")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                if isLoadingPlaylists {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else {
                    // Playlists
                    ScrollView {
                        VStack(spacing: 0) {
                            if userPlaylists.isEmpty {
                                Text("No playlists yet. Create one below.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.vertical, 24)
                            }
                            ForEach(userPlaylists) { playlist in
                                Button {
                                    addCurrentFlickToPlaylist(playlist)
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: 40)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.title)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                            Text("\(playlist.videoCount) videos")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.primary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .background(Color.gray.opacity(0.2))
                            }
                        }
                    }
                }
                
                // Create new playlist input
                VStack(spacing: 12) {
                    TextField("New playlist name", text: $newPlaylistName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    
                    Button("Create & Add") {
                        createPlaylistAndAdd()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : AppTheme.Colors.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 20)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadUserPlaylists()
        }
    }

    // MARK: - Report Sheet
    private func reportSheet(flick: NuclearFlick) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Report")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        selectedReportFlick = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Text("Why are you reporting this?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                Divider().background(Color.gray.opacity(0.3))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(FlicksFeedbackService.ReportReason.allCases) { reason in
                            Button {
                                submitReport(flick: flick, reason: reason)
                            } label: {
                                HStack {
                                    Text(reason.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.gray.opacity(0.2))
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func submitReport(flick: NuclearFlick, reason: FlicksFeedbackService.ReportReason) {
        Task {
            await FlicksFeedbackService.shared.report(flickId: flick.id, reason: reason)
        }
        selectedReportFlick = nil
        notificationFeedback.notificationOccurred(.success)
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
                    notificationFeedback.notificationOccurred(.success)
                    showPlaylistPicker = false
                }
            } catch {
                print("⚠️ [Flicks] Failed to add to playlist: \(error)")
                await MainActor.run { notificationFeedback.notificationOccurred(.error) }
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
                    notificationFeedback.notificationOccurred(.success)
                    showPlaylistPicker = false
                }
            } catch {
                print("⚠️ [Flicks] Failed to create playlist: \(error)")
                await MainActor.run { notificationFeedback.notificationOccurred(.error) }
            }
        }
    }
    
    private var creatorVideosSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        showCreatorVideos = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Creator's Videos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Creator videos
                ScrollView {
                    let creatorVideos = viewModel.flicks.filter { $0.creator.id == viewModel.flicks[currentIndex].creator.id }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(creatorVideos) { flick in
                            VStack(spacing: 8) {
                                AppAsyncImage(
                                    url: URL(string: flick.thumbnailURL),
                                    content: { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                )
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(flick.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    
                                    Text("\(formatCount(flick.viewCount)) views")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func toggleSave(flick: NuclearFlick) {
        if savedVideoIds.contains(flick.id) {
            savedVideoIds.remove(flick.id)
        } else {
            savedVideoIds.insert(flick.id)
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // MARK: - Speed Picker Sheet
    private var speedPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Playback Speed")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                VStack(spacing: 12) {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button {
                            playbackSpeed = speed
                            showSpeedPicker = false
                            impactMedium.impactOccurred()
                        } label: {
                            HStack {
                                Text("\(speed)x")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(playbackSpeed == speed ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
        impactHeavy.impactOccurred()
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
        impactLight.impactOccurred()
        
        // 🔥 STRONGER: Aggressive preloading (+7 ahead)
        viewModel.preloadVideos(around: newIndex, count: 7)
        
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
        if index == currentIndex, let startTime = videoStartTime {
            let watchTime = Date().timeIntervalSince(startTime)
            let flickId = viewModel.flicks[index].id
            watchTimeByVideo[flickId, default: 0] += watchTime
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
