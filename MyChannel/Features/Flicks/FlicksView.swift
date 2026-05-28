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
            GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
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
                onSingleTap: {},
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
                        toggleUI()
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
                                    
                                    if flick.creator.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text("@\(flick.creator.username)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            
                            // Follow button
                            Button {
                                viewModel.toggleFollow(creator: flick.creator)
                                impactMedium.impactOccurred()
                            } label: {
                                Text(viewModel.isFollowing(creatorId: flick.creator.id) ? "Following" : "Follow")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                            }
                            
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
                count: "Share",
                color: .white
            ) {
                viewModel.openShare(flick: flick)
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
                Spacer()
                
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
        print("🚨 [Flicks] Reported flick: \(flick.id)")
        notificationFeedback.notificationOccurred(.error)
        // TODO: Send to backend
    }
    
    private func notInterested(flick: NuclearFlick) {
        print("👎 [Flicks] Not interested in flick: \(flick.id)")
        viewModel.removeUnavailableFlick(id: flick.id)
        notificationFeedback.notificationOccurred(.warning)
        // TODO: Send to backend for recommendation tuning
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
                    
                    Text("Add to Playlist")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // Create new playlist
                        notificationFeedback.notificationOccurred(.success)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Playlists
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(["Watch Later", "Favorites", "My Mix", "Workout", "Chill Vibes"], id: \.self) { playlist in
                            Button {
                                showPlaylistPicker = false
                                notificationFeedback.notificationOccurred(.success)
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 40)
                                    
                                    Text(playlist)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .opacity(0)
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
                
                // Create new playlist input
                VStack(spacing: 12) {
                    TextField("New playlist name", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    
                    Button("Create") {
                        showPlaylistPicker = false
                        notificationFeedback.notificationOccurred(.success)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
            if let startTime = videoStartTime, currentIndex < viewModel.flicks.count {
                let watchTime = Date().timeIntervalSince(startTime)
                let flickId = viewModel.flicks[currentIndex].id
                watchTimeByVideo[flickId, default: 0] += watchTime
            }
            videoStartTime = nil
            
        case .active:
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

// MARK: - Nuclear Flick Model
struct NuclearFlick: Identifiable, Hashable {
    let id: String
    let videoURL: String
    let thumbnailURL: String
    let title: String
    let description: String
    let duration: TimeInterval
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: Date
    let creator: FlickCreator
    let tags: [String]
    let musicTrack: FlickMusicTrack?
    let contentSource: Video.ContentSource
    let externalID: String?
    
    func toVideo() -> Video {
        Video(
            id: id,
            title: title,
            description: description,
            thumbnailURL: thumbnailURL,
            videoURL: videoURL,
            duration: duration,
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            createdAt: createdAt,
            creator: User(
                username: creator.username,
                displayName: creator.displayName,
                email: "",
                profileImageURL: creator.profileImageURL,
                bannerImageURL: nil,
                bio: nil,
                subscriberCount: 0,
                videoCount: 0,
                isVerified: creator.isVerified,
                isCreator: true
            ),
            category: .shorts,
            tags: tags,
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .portrait,
            isLiveStream: false,
            contentSource: contentSource,
            externalID: externalID,
            isVerified: false
        )
    }
}

struct FlickCreator: Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String
    let isVerified: Bool
}

struct FlickMusicTrack: Identifiable, Hashable {
    var id: String { "\(title)|\(artist)|\(albumArt)" }
    let title: String
    let artist: String
    let albumArt: String
}

// MARK: - Nuclear Video Player View
struct NuclearVideoPlayerView: View {
    let flick: NuclearFlick
    let isActive: Bool
    let isMuted: Bool
    let playbackSpeed: Double
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var hasSetup = false
    @State private var loadingTimedOut = false
    
    private var videoUnavailable: Bool {
        playerManager.hasError || loadingTimedOut
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                
                // Thumbnail while player is loading or not ready (prevents black screen)
                AppAsyncImage(
                    url: URL(string: flick.thumbnailURL),
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        Color.gray.opacity(0.3)
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .opacity(playerManager.isPlaying ? 0 : 1)
                
                // Video layer - fill entire screen
                if !videoUnavailable, let player = playerManager.player {
                    FlicksPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                
                // Video unavailable state (deleted/broken video) — auto-skip after brief display
                if videoUnavailable {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Video unavailable")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Skipping...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            NotificationCenter.default.post(
                                name: .flickVideoUnavailable,
                                object: nil,
                                userInfo: ["flickId": flick.id]
                            )
                        }
                    }
                }
                
                // Loading: white spinner only while actively loading (with timeout)
                if playerManager.isLoading && !videoUnavailable && !playerManager.isPlaying {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if isActive && !hasSetup {
                setupPlayer()
            }
        }
        .onDisappear {
            playerManager.pause()
        }
        .onChange(of: isActive) { active in
            if active {
                if !hasSetup {
                    setupPlayer()
                } else if !videoUnavailable {
                    playerManager.play()
                }
            } else {
                playerManager.pause()
            }
        }
        .onChange(of: isMuted) { muted in
            playerManager.player?.isMuted = muted
        }
        .onChange(of: playbackSpeed) { speed in
            playerManager.player?.rate = Float(speed)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pauseFlicksPlayback)) { _ in
            playerManager.pause()
        }
    }
    
    private func setupPlayer() {
        hasSetup = true
        loadingTimedOut = false
        let video = flick.toVideo()
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true)
        playerManager.player?.isMuted = isMuted
        playerManager.player?.rate = Float(playbackSpeed)
        
        if isActive {
            playerManager.play()
        }
        
        Task { @MainActor [self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if playerManager.isLoading && !playerManager.isPlaying {
                loadingTimedOut = true
                print("⏰ [NuclearFlicks] Loading timed out for flick: \(flick.id) — video likely deleted")
            }
        }
    }
}

private struct UIKitFlicksGestureLayer: UIViewRepresentable {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPressBegan: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTap))
        singleTap.numberOfTapsRequired = 1
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap))
        doubleTap.numberOfTapsRequired = 2
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
        longPress.minimumPressDuration = 0.35
        
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(longPress)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject {
        var parent: UIKitFlicksGestureLayer
        
        init(parent: UIKitFlicksGestureLayer) {
            self.parent = parent
        }
        
        @objc func singleTap() {
            parent.onSingleTap()
        }
        
        @objc func doubleTap() {
            parent.onDoubleTap()
        }
        
        @objc func longPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            parent.onLongPressBegan()
        }
    }
}

private struct UIKitFlicksProgressRail: UIViewRepresentable {
    let count: Int
    @Binding var currentIndex: Int
    let reduceMotion: Bool
    let onSelect: (Int) -> Void
    
    func makeUIView(context: Context) -> FlicksProgressRailView {
        let view = FlicksProgressRailView()
        view.onSelect = { index in
            onSelect(index)
        }
        return view
    }
    
    func updateUIView(_ uiView: FlicksProgressRailView, context: Context) {
        uiView.configure(count: count, currentIndex: currentIndex, reduceMotion: reduceMotion)
        uiView.onSelect = { index in
            onSelect(index)
        }
    }
}

private final class FlicksProgressRailView: UIView {
    var onSelect: ((Int) -> Void)?
    
    private var count: Int = 0
    private var currentIndex: Int = 0
    private var reduceMotion: Bool = false
    private var segmentLayers: [CALayer] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(count: Int, currentIndex: Int, reduceMotion: Bool) {
        self.count = count
        self.currentIndex = min(max(currentIndex, 0), max(count - 1, 0))
        self.reduceMotion = reduceMotion
        rebuildLayersIfNeeded()
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard count > 0 else { return }
        let maxVisible = min(count, 18)
        let spacing: CGFloat = 6
        let segmentHeight: CGFloat = 10
        let selectedHeight: CGFloat = 22
        let totalHeight = CGFloat(maxVisible - 1) * (segmentHeight + spacing) + selectedHeight
        var y = (bounds.height - totalHeight) / 2
        let start = visibleStart(maxVisible: maxVisible)
        for visibleIndex in 0..<maxVisible {
            let index = start + visibleIndex
            let selected = index == currentIndex
            let height = selected ? selectedHeight : segmentHeight
            let width: CGFloat = selected ? 4 : 3
            let layer = segmentLayers[visibleIndex]
            let frame = CGRect(x: bounds.midX - width / 2, y: y, width: width, height: height)
            if reduceMotion {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.frame = frame
                layer.backgroundColor = UIColor.white.withAlphaComponent(selected ? 1 : 0.35).cgColor
                CATransaction.commit()
            } else {
                layer.frame = frame
                layer.backgroundColor = UIColor.white.withAlphaComponent(selected ? 1 : 0.35).cgColor
            }
            layer.cornerRadius = width / 2
            y += height + spacing
        }
    }
    
    private func rebuildLayersIfNeeded() {
        let targetCount = min(count, 18)
        guard segmentLayers.count != targetCount else { return }
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers = (0..<targetCount).map { _ in
            let layer = CALayer()
            layer.shadowColor = UIColor.white.cgColor
            layer.shadowOpacity = 0.25
            layer.shadowRadius = 4
            self.layer.addSublayer(layer)
            return layer
        }
    }
    
    private func visibleStart(maxVisible: Int) -> Int {
        guard count > maxVisible else { return 0 }
        let half = maxVisible / 2
        return min(max(currentIndex - half, 0), count - maxVisible)
    }
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard count > 0 else { return }
        let maxVisible = min(count, 18)
        let start = visibleStart(maxVisible: maxVisible)
        let location = recognizer.location(in: self)
        let segmentHeight = bounds.height / CGFloat(maxVisible)
        let visibleIndex = min(max(Int(location.y / max(segmentHeight, 1)), 0), maxVisible - 1)
        let index = min(start + visibleIndex, count - 1)
        onSelect?(index)
    }
}

// MARK: - Nuclear Flicks ViewModel
@MainActor
class NuclearFlicksViewModel: ObservableObject {
    
    // 🔥 STRONGER: App-wide warmup on launch
    static func warmupOnLaunch() {
        Task { @MainActor in
            print("🔥 [NuclearFlicks] App-wide warmup started")
            let viewModel = NuclearFlicksViewModel()
            await viewModel.loadInitialFlicks()
            // Pre-warm player pool
            _ = PlayerPoolManager.shared.getPoolStats()
            print("✅ [NuclearFlicks] App-wide warmup complete")
        }
    }
    @Published var flicks: [NuclearFlick] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    
    @Published var likedFlickIds: Set<String> = []
    @Published var followedCreatorIds: Set<String> = []
    
    @Published var commentsFlick: NuclearFlick?
    @Published var shareFlick: NuclearFlick?
    @Published var selectedCreatorProfile: User?
    
    @Published var albumArtRotation: Double = 0
    
    private var lastDocument: DocumentSnapshot?
    private var preloadedIndices: Set<Int> = []
    private var rotationTimer: Timer?
    private var recommendationsEnabled = false
    private var servedRecommendationIDs: Set<String> = []
    private var validatedURLs: Set<String> = []
    private var invalidURLs: Set<String> = []
    private let blacklistKey = "NuclearFlicks_DeadURLBlacklist"
    private var persistentBlacklist: Set<String> {
        get { UserDefaults.standard.stringArray(forKey: blacklistKey).map { Set($0) } ?? [] }
        set { UserDefaults.standard.set(Array(newValue), forKey: blacklistKey) }
    }
    
    init() {
        startAlbumArtRotation()
        // Load persistent blacklist on init
        invalidURLs = persistentBlacklist
    }
    
    deinit {
        rotationTimer?.invalidate()
    }
    
    // MARK: - Data Loading
    
    func loadInitialFlicks() async {
        isLoading = true
        error = nil
        recommendationsEnabled = false
        servedRecommendationIDs.removeAll()
        defer { isLoading = false }
        
        if await loadRecommendedFeedIfAvailable(limit: 20) {
            print("✅ [NuclearFlicks] Loaded Vertex AI recommendations")
            preloadVideos(around: 0, count: 5)  // 🔥 STRONGER: 5 instead of 3
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Try shorts collection first
            let query = db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
            
            let snapshot = try await query.getDocuments()
            
            var mainVideoBackfill = await loadPublicVideoFlicks(limit: 60)
            
            if !snapshot.documents.isEmpty {
                lastDocument = snapshot.documents.last
                var parsed = snapshot.documents.compactMap { doc in
                    parseFlickFromDocument(doc)
                }
                parsed = await validateFlicks(parsed)
                parsed = mergePlayableFlicks(primary: parsed, fallback: mainVideoBackfill, minimumCount: 20)
                if parsed.count < 10 {
                    let demoBackfill = makeDemoFlicks()
                    parsed = mergePlayableFlicks(primary: parsed, fallback: demoBackfill, minimumCount: 20)
                    print("📺 [NuclearFlicks] Supplemented Flicks with playable catalog content")
                }
                flicks = parsed
                print("✅ [NuclearFlicks] Loaded \(flicks.count) playable Flicks")
                preloadVideos(around: 0, count: 5)  // 🔥 STRONGER: 5 instead of 3
            } else if !mainVideoBackfill.isEmpty {
                flicks = mergePlayableFlicks(primary: mainVideoBackfill, fallback: makeDemoFlicks(), minimumCount: 20)
                print("✅ [NuclearFlicks] Loaded \(flicks.count) playable videos from public videos")
                preloadVideos(around: 0, count: 5)  // 🔥 STRONGER: 5 instead of 3
            } else {
                // Silently fallback to demo data (no error - this is expected when starting)
                flicks = makeDemoFlicks()
                print("📺 [NuclearFlicks] No Flicks in Firestore yet. Showing \(flicks.count) demo Flicks.")
                preloadVideos(around: 0, count: 5)  // 🔥 STRONGER: 5 instead of 3
            }
        } catch {
            // Only show error for actual failures (network issues, permissions, etc.)
            print("🚨 [NuclearFlicks] Error loading from Firestore: \(error.localizedDescription)")
            
            // Don't show error to user - just fallback gracefully to demo content
            flicks = makeDemoFlicks()
            print("📺 [NuclearFlicks] Fallback to \(flicks.count) demo Flicks due to error")
        }
        #else
        flicks = makeDemoFlicks()
        print("📺 [NuclearFlicks] Firebase not available. Showing \(flicks.count) demo Flicks.")
        #endif
    }
    
    private func loadRecommendedFeedIfAvailable(limit: Int) async -> Bool {
        guard let userId = AppState.shared.currentUser?.id else { return false }
        do {
            let sessionHistory = Array(AppState.shared.watchHistory.prefix(25).map { $0.contentId })
            let ids = try await AgentAPIService.shared.getRecommendations(
                userId: userId,
                sessionHistory: sessionHistory,
                limit: limit
            )
            let freshIds = ids.filter { !servedRecommendationIDs.contains($0) }
            let flickResults = await fetchFlicks(for: freshIds)
            guard !flickResults.isEmpty else { return false }
            flicks = flickResults
            servedRecommendationIDs.formUnion(flickResults.map { $0.id })
            recommendationsEnabled = true
            lastDocument = nil
            return true
        } catch {
            print("⚠️ [NuclearFlicks] Recommendation load failed: \(error)")
            return false
        }
    }

    func loadMoreFlicks() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        if recommendationsEnabled {
            let appended = await appendAdditionalRecommendations(limit: 10)
            if appended { return }
        }
        
        #if canImport(FirebaseFirestore)
        guard let lastDoc = lastDocument else { return }
        
        do {
            let db = Firestore.firestore()
            let query = db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: 10)
            
            let snapshot = try await query.getDocuments()
            
            if !snapshot.documents.isEmpty {
                lastDocument = snapshot.documents.last
                var newFlicks = snapshot.documents.compactMap { doc in
                    parseFlickFromDocument(doc)
                }
                newFlicks = await validateFlicks(newFlicks)
                flicks = mergePlayableFlicks(primary: flicks, fallback: newFlicks, minimumCount: flicks.count + newFlicks.count)
            } else {
                let publicVideos = await loadPublicVideoFlicks(limit: 20)
                flicks = mergePlayableFlicks(primary: flicks, fallback: publicVideos, minimumCount: flicks.count + min(publicVideos.count, 10))
            }
        } catch {
            print("🚨 [NuclearFlicks] Error loading more: \(error)")
        }
        #endif
    }
    
    // MARK: - Actions
    
    func toggleLike(flick: NuclearFlick) {
        if likedFlickIds.contains(flick.id) {
            likedFlickIds.remove(flick.id)
        } else {
            likedFlickIds.insert(flick.id)
            
            // Track like analytics
            Task {
                await trackLike(flickId: flick.id)
            }
        }
    }
    
    func isLiked(flickId: String) -> Bool {
        likedFlickIds.contains(flickId)
    }
    
    func toggleFollow(creator: FlickCreator) {
        if followedCreatorIds.contains(creator.id) {
            followedCreatorIds.remove(creator.id)
        } else {
            followedCreatorIds.insert(creator.id)
        }
    }
    
    func isFollowing(creatorId: String) -> Bool {
        followedCreatorIds.contains(creatorId)
    }
    
    func openComments(flick: NuclearFlick) {
        commentsFlick = flick
    }
    
    func openShare(flick: NuclearFlick) {
        shareFlick = flick
    }
    
    func removeUnavailableFlick(id: String) {
        let baseId = id.components(separatedBy: "_loop_").first ?? id
        flicks.removeAll { flick in
            flick.id == id || flick.id == baseId || flick.id.hasPrefix("\(baseId)_loop_")
        }
        if flicks.count < 8 {
            let backfill = mergePlayableFlicks(primary: flicks, fallback: makeDemoFlicks(), minimumCount: 20)
            flicks = backfill
        }
    }
    
    func navigateToCreator(_ creator: FlickCreator) {
        // Convert FlickCreator to User and navigate to profile
        let user = User(
            id: creator.id,
            username: creator.username,
            displayName: creator.displayName,
            email: "",
            profileImageURL: creator.profileImageURL,
            isVerified: creator.isVerified
        )
        selectedCreatorProfile = user
    }
    
    // MARK: - Preloading
    
    func preloadVideos(around index: Int, count: Int) {
        let start = max(0, index - 1)
        let end = min(flicks.count - 1, index + count)  // 🔥 STRONGER: More aggressive range
        
        for i in start...end {
            if !preloadedIndices.contains(i) {
                preloadedIndices.insert(i)
                Task {
                    await preloadVideo(at: i)
                }
            }
        }
    }
    
    private func preloadVideo(at index: Int) async {
        guard index < flicks.count else { return }
        let flick = flicks[index]
        guard isPlayableFlick(flick) else { return }
        
        if flick.contentSource != Video.ContentSource.youtube {
            VideoPlayerManager.prewarm(urlString: flick.videoURL)
            PlayerPoolManager.shared.preloadAsset(for: flick.videoURL)
            if let thumbURL = URL(string: flick.thumbnailURL) {
                ImagePrefetcher.shared.prefetch(url: thumbURL)
            }
            let alive = await isURLAlive(flick.videoURL)
            if !alive {
                removeUnavailableFlick(id: flick.id)
            }
        }
    }
    
    // MARK: - Analytics
    
    func trackView(flick: NuclearFlick) async {
        // Track view count
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            try await db.collection("shorts").document(flick.id).updateData([
                "viewCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("🚨 [NuclearFlicks] Error tracking view: \(error)")
        }
        #endif
        
        // Track with RealtimeViewTracker
        if let userId = AppState.shared.currentUser?.id {
            await RealtimeViewTracker.shared.startViewSession(videoId: flick.id, userId: userId)
        }
    }
    
    func trackWatchTime(flickId: String, duration: TimeInterval) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            try await db.collection("analytics").document("watch_time").setData([
                "flicks": [
                    flickId: [
                        "totalWatchTime": FieldValue.increment(Int64(duration)),
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]
                ]
            ], merge: true)
        } catch {
            print("🚨 [NuclearFlicks] Error tracking watch time: \(error)")
        }
        #endif
    }
    
    func trackLike(flickId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            try await db.collection("shorts").document(flickId).updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("🚨 [NuclearFlicks] Error tracking like: \(error)")
        }
        #endif
    }
    
    // MARK: - Album Art Rotation
    
    private func startAlbumArtRotation() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.albumArtRotation += 1
                if self?.albumArtRotation ?? 0 >= 360 {
                    self?.albumArtRotation = 0
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func parseFlickFromDocument(_ doc: DocumentSnapshot) -> NuclearFlick? {
        let data = doc.data() ?? [:]
        
        guard let title = data["title"] as? String,
              let videoURL = data["videoUrl"] as? String ?? data["videoURL"] as? String ?? data["downloadURL"] as? String ?? data["downloadUrl"] as? String else {
            return nil
        }
        
        let creator = FlickCreator(
            id: data["creatorId"] as? String ?? "unknown",
            username: data["creatorUsername"] as? String ?? "creator",
            displayName: data["creatorDisplayName"] as? String ?? "Creator",
            profileImageURL: data["creatorProfileImage"] as? String ?? "",
            isVerified: data["creatorIsVerified"] as? Bool ?? false
        )
        
        var musicTrack: FlickMusicTrack?
        if let musicData = data["musicTrack"] as? [String: Any],
           let musicTitle = musicData["title"] as? String,
           let musicArtist = musicData["artist"] as? String,
           let albumArt = musicData["albumArt"] as? String {
            musicTrack = FlickMusicTrack(title: musicTitle, artist: musicArtist, albumArt: albumArt)
        }
        
        let flick = NuclearFlick(
            id: doc.documentID,
            videoURL: videoURL,
            thumbnailURL: data["thumbnailUrl"] as? String ?? data["thumbnailURL"] as? String ?? "",
            title: title,
            description: data["description"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 30,
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            creator: creator,
            tags: data["tags"] as? [String] ?? [],
            musicTrack: musicTrack,
            contentSource: (data["contentSource"] as? String).flatMap { Video.ContentSource(rawValue: $0) } ?? Video.ContentSource.userUploaded,
            externalID: data["externalID"] as? String
        )
        
        guard isPlayableFlick(flick) else { return nil }
        return flick
    }
    
    private func makeDemoFlicks() -> [NuclearFlick] {
        let freeVideos = SeedCatalogService.shared.freeCatalogVideos
        let seedVideos = SeedCatalogService.shared.seedVideos
        let combined = (freeVideos + seedVideos)
            .filter { isPlayableVideo($0) && isKnownReliableURLString($0.videoURL) }
            .shuffled()
        if !combined.isEmpty {
            return combined.prefix(60).map { video in
                videoToFlick(video)
            }
        }
        let demoCreator = FlickCreator(
            id: "demo1",
            username: "demo_creator",
            displayName: "Demo Creator",
            profileImageURL: "https://i.pravatar.cc/200?u=demo_creator",
            isVerified: true
        )
        return (1...10).map { i in
            NuclearFlick(
                id: "demo_\(i)",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                thumbnailURL: "https://picsum.photos/seed/flick\(i)/1080/1920",
                title: "Amazing Flick #\(i) 🔥",
                description: "This is an amazing short video! Check it out!",
                duration: 30,
                viewCount: Int.random(in: 10_000...1_000_000),
                likeCount: Int.random(in: 1_000...100_000),
                commentCount: Int.random(in: 100...10_000),
                shareCount: Int.random(in: 50...5_000),
                createdAt: Date(),
                creator: demoCreator,
                tags: ["trending", "viral", "fyp"],
                musicTrack: FlickMusicTrack(
                    title: "Original Audio",
                    artist: "Demo Creator",
                    albumArt: "https://picsum.photos/seed/music\(i)/300/300"
                ),
                contentSource: Video.ContentSource.userUploaded,
                externalID: nil as String?
            )
        }
    }

    private func fetchFlicks(for videoIds: [String]) async -> [NuclearFlick] {
        guard !videoIds.isEmpty else { return [] }
        do {
            let videos = try await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: videoIds)
            guard !videos.isEmpty else { return [] }
            // Filter out videos with empty/invalid URLs (e.g. deleted videos)
            let validVideos = videos.filter { isPlayableVideo($0) }
            let flickMap = Dictionary(validVideos.map { ($0.id, videoToFlick($0)) }, uniquingKeysWith: { _, last in last })
            return videoIds.compactMap { flickMap[$0] }
        } catch {
            print("⚠️ [NuclearFlicks] Failed to hydrate recommended IDs: \(error)")
            return []
        }
    }
    
    private func appendAdditionalRecommendations(limit: Int) async -> Bool {
        guard let userId = AppState.shared.currentUser?.id else { return false }
        do {
            let sessionHistory = Array(AppState.shared.watchHistory.prefix(30).map { $0.contentId })
            let ids = try await AgentAPIService.shared.getRecommendations(
                userId: userId,
                sessionHistory: sessionHistory,
                limit: limit
            )
            let newIds = ids.filter { !servedRecommendationIDs.contains($0) }
            let flickResults = await fetchFlicks(for: newIds)
            guard !flickResults.isEmpty else { return false }
            flicks.append(contentsOf: flickResults)
            servedRecommendationIDs.formUnion(flickResults.map { $0.id })
            return true
        } catch {
            print("⚠️ [NuclearFlicks] Failed to append recommendations: \(error)")
            return false
        }
    }
    
    private func loadPublicVideoFlicks(limit: Int) async -> [NuclearFlick] {
        let videos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: limit)
        return videos
            .filter { isPlayableVideo($0) }
            .map { videoToFlick($0) }
    }
    
    private func mergePlayableFlicks(primary: [NuclearFlick], fallback: [NuclearFlick], minimumCount: Int) -> [NuclearFlick] {
        var seen = Set<String>()
        var merged: [NuclearFlick] = []
        
        for flick in primary + fallback {
            guard isPlayableFlick(flick), !seen.contains(flick.id) else { continue }
            seen.insert(flick.id)
            merged.append(flick)
        }
        
        if merged.count < minimumCount {
            let reusableFallback = fallback.filter { isPlayableFlick($0) }
            while merged.count < minimumCount, !reusableFallback.isEmpty {
                for original in reusableFallback {
                    guard merged.count < minimumCount else { break }
                    let copy = NuclearFlick(
                        id: "\(original.id)_loop_\(merged.count)",
                        videoURL: original.videoURL,
                        thumbnailURL: original.thumbnailURL,
                        title: original.title,
                        description: original.description,
                        duration: original.duration,
                        viewCount: original.viewCount,
                        likeCount: original.likeCount,
                        commentCount: original.commentCount,
                        shareCount: original.shareCount,
                        createdAt: original.createdAt,
                        creator: original.creator,
                        tags: original.tags,
                        musicTrack: original.musicTrack,
                        contentSource: original.contentSource,
                        externalID: original.externalID
                    )
                    merged.append(copy)
                }
            }
        }
        
        return merged
    }
    
    // MARK: - URL Reachability Validation

    /// Checks if a video URL actually resolves (live file, not 404/deleted).
    /// Skips known-reliable hosts and uses a session-level cache so each URL is checked at most once.
    private func isURLAlive(_ urlString: String) async -> Bool {
        if isKnownReliableURLString(urlString) { return true }
        if validatedURLs.contains(urlString) { return true }
        if invalidURLs.contains(urlString) { return false }
        guard let url = URL(string: urlString) else {
            invalidURLs.insert(urlString)
            persistentBlacklist = invalidURLs
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0  // 🔥 FASTER FAIL: 2s instead of 3s
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let alive = (response as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
            if alive { validatedURLs.insert(urlString) } else { 
                invalidURLs.insert(urlString)
                persistentBlacklist = invalidURLs
            }
            return alive
        } catch {
            invalidURLs.insert(urlString)
            persistentBlacklist = invalidURLs
            return false
        }
    }

    /// Validates a batch of flicks concurrently via HEAD requests.
    /// Filters out any with dead/unreachable URLs before they reach the feed.
    /// Known-reliable URLs and YouTube flicks are passed through without a network round-trip.
    private func validateFlicks(_ flicks: [NuclearFlick]) async -> [NuclearFlick] {
        guard !flicks.isEmpty else { return [] }
        let currentValidated = validatedURLs
        let currentInvalid = invalidURLs
        let results: [(index: Int, alive: Bool)] = await withTaskGroup(of: (index: Int, alive: Bool).self) { group in
            for (i, flick) in flicks.enumerated() {
                let urlString = flick.videoURL
                let thumbURL = flick.thumbnailURL
                let isYT = flick.contentSource == .youtube
                let isReliable = isKnownReliableURLString(urlString)
                let inValid = currentValidated.contains(urlString)
                let inInvalid = currentInvalid.contains(urlString)
                group.addTask {
                    if isYT || isReliable || inValid { return (index: i, alive: true) }
                    if inInvalid { return (index: i, alive: false) }
                    guard let url = URL(string: urlString) else { return (index: i, alive: false) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 2.0  // 🔥 FASTER FAIL
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let videoAlive = (response as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
                        // 🔥 ALSO VALIDATE THUMBNAIL
                        var thumbAlive = true
                        if let thumb = URL(string: thumbURL), !thumbURL.isEmpty {
                            var thumbReq = URLRequest(url: thumb)
                            thumbReq.httpMethod = "HEAD"
                            thumbReq.timeoutInterval = 2.0
                            thumbReq.cachePolicy = .reloadIgnoringLocalCacheData
                            let (_, thumbResp) = try await URLSession.shared.data(for: thumbReq)
                            thumbAlive = (thumbResp as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
                        }
                        return (index: i, alive: videoAlive && thumbAlive)
                    } catch {
                        return (index: i, alive: false)
                    }
                }
            }
            var collected: [(index: Int, alive: Bool)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        var valid: [NuclearFlick] = []
        for result in results.sorted(by: { $0.index < $1.index }) {
            if result.alive {
                validatedURLs.insert(flicks[result.index].videoURL)
                valid.append(flicks[result.index])
            } else {
                invalidURLs.insert(flicks[result.index].videoURL)
                persistentBlacklist = invalidURLs
                print("🚫 [NuclearFlicks] Filtered dead URL: \(flicks[result.index].videoURL.prefix(80))")
            }
        }
        return valid
    }

    private func isPlayableVideo(_ video: Video) -> Bool {
        if video.contentSource == .youtube {
            return !(video.externalID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if video.isLiveStream { return false }
        if video.duration <= 0 { return false }
        return isPlayableURLString(video.videoURL)
    }
    
    private func isPlayableFlick(_ flick: NuclearFlick) -> Bool {
        if flick.contentSource == .youtube {
            return !(flick.externalID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if flick.duration <= 0 { return false }
        if flick.thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return isPlayableURLString(flick.videoURL)
    }
    
    private func isPlayableURLString(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "file"
    }
    
    private func isKnownReliableURLString(_ value: String) -> Bool {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isPlayableURLString(lowercased) else { return false }
        return lowercased.contains("firebasestorage.googleapis.com")
            || lowercased.contains("storage.googleapis.com")
            || lowercased.contains("commondatastorage.googleapis.com")
            || lowercased.hasSuffix(".mp4")
            || lowercased.hasSuffix(".m3u8")
            || lowercased.hasPrefix("file://")
    }

    private func videoToFlick(_ video: Video) -> NuclearFlick {
        let creator = FlickCreator(
            id: video.creator.id,
            username: video.creator.username,
            displayName: video.creator.displayName,
            profileImageURL: video.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(video.id)",
            isVerified: video.creator.isVerified
        )
        return NuclearFlick(
            id: video.id,
            videoURL: video.videoURL,
            thumbnailURL: video.thumbnailURL,
            title: video.title,
            description: video.description,
            duration: video.duration,
            viewCount: video.viewCount,
            likeCount: video.likeCount,
            commentCount: video.commentCount,
            shareCount: max(1, video.viewCount / 1000),
            createdAt: video.createdAt,
            creator: creator,
            tags: video.tags.isEmpty ? ["free", "watch"] : video.tags,
            musicTrack: FlickMusicTrack(
                title: "Original Audio",
                artist: video.creator.displayName,
                albumArt: video.creator.profileImageURL ?? "https://picsum.photos/seed/\(video.id)/300/300"
            ),
            contentSource: video.contentSource ?? .userUploaded,
            externalID: video.externalID
        )
    }
}

// MARK: - Comments Modal
struct CommentsModalView: View {
    let video: Video
    
    var body: some View {
        ProfessionalCommentsSheet(video: video)
    }
}

// MARK: - Share Modal
struct ShareModalView: View {
    let video: Video
    
    var body: some View {
        ProfessionalShareSheet(video: video)
    }
}

// MARK: - Preview
#Preview("Flicks View") {
    FlicksView()
        .preferredColorScheme(.dark)
}

