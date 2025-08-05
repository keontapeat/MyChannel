//
//  VideoDetailView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit
import Combine

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    
    // MARK: - Player States
    @State private var showPlayer = false
    @State private var isPlayerReady = false
    @State private var isBuffering = false
    @State private var playbackProgress: Double = 0.0
    @State private var videoDuration: Double = 0.0
    @State private var currentTime: Double = 0.0
    @State private var playbackRate: Float = 1.0
    @State private var isFullscreen = false
    @State private var showPlayerControls = true
    @State private var playerControlsTimer: Timer?
    @State private var isDraggingSeeker = false
    @State private var videoQuality: VideoQuality = .auto
    @State private var isViewVisible = true
    
    // MARK: - Interaction States
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var isSubscribed = false
    @State private var isWatchLater = false
    @State private var isNotificationEnabled = false
    @State private var showingCommentComposer = false
    @State private var showingShareSheet = false
    @State private var showingMoreOptions = false
    @State private var showingQualitySelector = false
    @State private var showingPlaybackSpeedSelector = false
    
    // MARK: - Content States
    @State private var recommendedVideos: [Video] = []
    @State private var comments: [VideoComment] = []
    @State private var expandedDescription = false
    @State private var commentSortOption: CommentSortOption = .topComments
    @State private var isLoadingComments = false
    @State private var isLoadingRecommendations = false
    
    // MARK: - UI States
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragValue: CGSize = .zero
    
    // MARK: - Performance Optimizations
    @State private var isViewAppeared = false
    @State private var shouldPreloadRecommendations = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                fullScreenView(geometry: geometry)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onAppear {
            isViewVisible = true
            if !isViewAppeared {
                setupVideoOptimized()
                loadInitialDataOptimized()
                isViewAppeared = true
            }
            
            // Set up global player to take over
            globalPlayer.playVideo(video, showFullscreen: true)
        }
        .onDisappear {
            isViewVisible = false
            cleanupVideoOptimized()
            
            // Handle navigation away - convert to mini player if video is still playing
            if globalPlayer.isPlaying && globalPlayer.currentVideo?.id == video.id {
                globalPlayer.minimizePlayer()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { comment in
                handleNewComment(comment)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.videoURL, video.title])
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMoreOptions) {
            VideoMoreOptionsSheet(video: video, isSubscribed: $isSubscribed, isWatchLater: $isWatchLater)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQualitySelector) {
            VideoQualitySelector(selectedQuality: $videoQuality) { quality in
                changeVideoQuality(quality)
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                changePlaybackSpeed(speed)
            }
            .presentationDetents([.fraction(0.4)])
        }
    }
    
    // MARK: - Full Screen View
    private func fullScreenView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    // Enhanced Video Player Section
                    enhancedVideoPlayerSection(geometry: geometry)
                        .id("videoPlayer")
                    
                    // Video Info Section with Enhanced Details
                    enhancedVideoInfoSection
                        .id("videoInfo")
                    
                    // Enhanced Action Buttons Section
                    enhancedActionButtonsSection
                        .id("actionButtons")
                    
                    // Enhanced Comments Section
                    if isViewAppeared {
                        enhancedCommentsSection
                            .id("comments")
                    }
                    
                    // Enhanced Recommended Videos Section
                    if shouldPreloadRecommendations {
                        enhancedRecommendedVideosSection
                            .id("recommendations")
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .coordinateSpace(name: "scroll")
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: VideoScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(VideoScrollOffsetPreferenceKey.self) { value in
                handleScrollOffsetOptimized(value)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if !shouldPreloadRecommendations {
                    shouldPreloadRecommendations = true
                }
            }
        }
    }
    
    // MARK: - Enhanced Video Player Section
    private func enhancedVideoPlayerSection(geometry: GeometryProxy) -> some View {
        ZStack {
            // Video Player Container with optimized aspect ratio calculation
            let aspectRatio: CGFloat = 16/9
            let playerHeight = min(geometry.size.width / aspectRatio, geometry.size.height * 0.4)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: playerHeight)
                .overlay(
                    Group {
                        if let player = globalPlayer.player, globalPlayer.showingFullscreen {
                            VideoPlayer(player: player)
                                .frame(height: playerHeight)
                                .clipped()
                        } else {
                            thumbnailViewOptimized
                                .frame(height: playerHeight)
                        }
                    }
                )
            
            // Enhanced Gesture and Control Logic
            if globalPlayer.showingFullscreen && globalPlayer.player != nil {
                // Single overlay for all gestures
                HStack(spacing: 0) {
                    // Left side for rewind
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            globalPlayer.seekBackward()
                        }
                        .onTapGesture(count: 1) {
                            togglePlayerControlsOptimized()
                        }

                    // Right side for fast-forward
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            globalPlayer.seekForward()
                        }
                        .onTapGesture(count: 1) {
                            togglePlayerControlsOptimized()
                        }
                }

                // Player controls overlay
                playerControlsOverlay
                
                // Buffering indicator
                bufferingIndicator
            }
            
            // Navigation Overlay - Always Visible
            VStack {
                HStack {
                    // Enhanced Back Button with mini player conversion
                    Button(action: { 
                        if globalPlayer.isPlaying {
                            // Convert to mini player instead of stopping
                            globalPlayer.minimizePlayer()
                        }
                        dismissWithAnimation() 
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Quality and More Options
                    if showPlayerControls || !globalPlayer.showingFullscreen {
                        HStack(spacing: 12) {
                            // Video Quality Button
                            Button(action: { showingQualitySelector = true }) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                    
                                    Text(videoQuality.displayName)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // More Options
                            Button(action: { showingMoreOptions = true }) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                
                Spacer()
            }
            .animation(.easeInOut(duration: 0.25), value: showPlayerControls)
        }
    }
    
    // MARK: - Optimized Thumbnail View
    private var thumbnailViewOptimized: some View {
        ZStack {
            // Optimized AsyncImage with caching
            CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            .scaleEffect(0.8)
                    )
            }
            
            // Enhanced Play Button with optimized animations
            Button(action: { playVideoWithAnimationOptimized() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 4) // Center the play icon
                }
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
            
            // Video Duration Badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(video.formattedDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8))
                        .cornerRadius(6)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                }
            }
        }
    }
    
    // MARK: - Optimized Player Controls Overlay
    private var playerControlsOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if showPlayerControls {
                VStack(spacing: 16) {
                    // Progress Bar with optimized gesture handling
                    VStack(spacing: 8) {
                        // Time Labels and Progress Bar
                        HStack {
                            Text(formatTimeOptimized(globalPlayer.currentTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Text(formatTimeOptimized(globalPlayer.duration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .monospacedDigit()
                        }
                        
                        // Enhanced Progress Slider with optimized performance
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background Track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                // Buffered Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: geometry.size.width * 0.3, height: 4) // Mock buffered progress
                                
                                // Playback Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geometry.size.width * CGFloat(globalPlayer.currentProgress), height: 4)
                                
                                // Optimized Thumb with better performance
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: isDraggingSeeker ? 16 : 12, height: isDraggingSeeker ? 16 : 12)
                                    .offset(x: geometry.size.width * CGFloat(globalPlayer.currentProgress) - (isDraggingSeeker ? 8 : 6))
                                    .animation(.easeOut(duration: 0.15), value: isDraggingSeeker)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if !isDraggingSeeker {
                                            isDraggingSeeker = true
                                            HapticManager.shared.impact(style: .light)
                                        }
                                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                        globalPlayer.seek(to: newProgress)
                                    }
                                    .onEnded { _ in
                                        isDraggingSeeker = false
                                        HapticManager.shared.impact(style: .medium)
                                    }
                            )
                        }
                        .frame(height: 20)
                    }
                    
                    // Optimized Control Buttons
                    HStack(spacing: 32) {
                        // Rewind Button
                        Button(action: { globalPlayer.seekBackward() }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                        
                        // Play/Pause Button
                        Button(action: { togglePlayPauseOptimized() }) {
                            Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                        
                        // Fast Forward Button
                        Button(action: { globalPlayer.seekForward() }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                        
                        Spacer()
                        
                        // Playback Speed
                        Button(action: { showingPlaybackSpeedSelector = true }) {
                            Text(String(format: "%.1fx", playbackRate))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                        
                        // Fullscreen Button
                        Button(action: { toggleFullscreenOptimized() }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .animation(.easeOut(duration: 0.25), value: showPlayerControls)
    }
    
    // MARK: - Optimized Buffering Indicator
    private var bufferingIndicator: some View {
        Group {
            if isBuffering {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
    }
    
    // MARK: - Enhanced Video Info Section
    private var enhancedVideoInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title and Stats with optimized text rendering
            VStack(alignment: .leading, spacing: 12) {
                Text(video.title)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Optimized Stats Row
                HStack(spacing: 8) {
                    Label(video.formattedViews, systemImage: "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .labelStyle(.titleAndIcon)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Label(video.timeAgo, systemImage: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .labelStyle(.titleAndIcon)
                    
                    Spacer()
                    
                    // Video Quality Indicator
                    HStack(spacing: 4) {
                        Image(systemName: "tv")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("HD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Optimized Creator Info Row
            HStack(spacing: 16) {
                // Creator Avatar with caching
                CachedAsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(video.creator.displayName.prefix(2)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                
                // Creator Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(video.creator.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text("\(video.creator.subscriberCount.formatted()) subscribers")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Optimized Subscribe Button
                Button(action: { toggleSubscriptionWithAnimationOptimized() }) {
                    HStack(spacing: 8) {
                        if !isSubscribed {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                        }
                        
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(isSubscribed ? AppTheme.Colors.textSecondary : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                    )
                }
                .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSubscribed)
            }
            
            // Optimized Description
            VStack(alignment: .leading, spacing: 12) {
                Text(video.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(expandedDescription ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                if video.description.count > 150 {
                    Button(action: { toggleDescriptionOptimized() }) {
                        HStack(spacing: 4) {
                            Text(expandedDescription ? "Show less" : "Show more")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Image(systemName: expandedDescription ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
            .background(AppTheme.Colors.surface.opacity(0.5))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    // MARK: - Enhanced Action Buttons Section
    private var enhancedActionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary Actions Row with optimized ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    // Like Button
                    EnhancedVideoActionButton(
                        icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                        text: video.likeCount.formatted(),
                        isSelected: isLiked,
                        color: AppTheme.Colors.primary
                    ) {
                        toggleLikeWithAnimationOptimized()
                    }
                    
                    // Dislike Button
                    EnhancedVideoActionButton(
                        icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                        text: "Dislike",
                        isSelected: isDisliked,
                        color: AppTheme.Colors.secondary
                    ) {
                        toggleDislikeWithAnimationOptimized()
                    }
                    
                    // Share Button
                    EnhancedVideoActionButton(
                        icon: "square.and.arrow.up",
                        text: "Share",
                        color: AppTheme.Colors.accent
                    ) {
                        shareVideoOptimized()
                    }
                    
                    // Save Button
                    EnhancedVideoActionButton(
                        icon: isWatchLater ? "bookmark.fill" : "bookmark",
                        text: "Save",
                        isSelected: isWatchLater,
                        color: AppTheme.Colors.success
                    ) {
                        toggleWatchLaterWithAnimationOptimized()
                    }
                    
                    // Download Button
                    EnhancedVideoActionButton(
                        icon: "arrow.down.circle",
                        text: "Download",
                        color: AppTheme.Colors.accent
                    ) {
                        downloadVideoOptimized()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Enhanced Comments Section
    private var enhancedCommentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Comments Header
            VStack(spacing: 16) {
                HStack {
                    Text("Comments")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("•")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(video.commentCount.formatted())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
                
                // Add Comment row
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("Y")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Button(action: { showingCommentComposer = true }) {
                        HStack {
                            Text("Add a comment...")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(24)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            
            // Optimized Sample Comments with LazyVStack
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(getSampleCommentsOptimized()) { comment in
                    VideoCommentRowView(comment: comment)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Enhanced Recommended Videos Section
    private var enhancedRecommendedVideosSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Up next")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 16) {
                ForEach(Video.sampleVideos.prefix(5)) { video in
                    NavigationLink(destination: VideoDetailView(video: video)) {
                        VideoRecommendedVideoRow(video: video)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Optimized Helper Methods
    
    private func setupVideoOptimized() {
        loadUserPreferencesOptimized()
    }
    
    private func loadInitialDataOptimized() {
        Task {
            await loadCommentsOptimized()
        }
        
        // Delay recommendations loading to improve initial render performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                await loadRecommendationsOptimized()
            }
        }
    }
    
    private func loadUserPreferencesOptimized() {
        // Batch state updates for better performance
        DispatchQueue.main.async {
            isLiked = false
            isSubscribed = false
            isWatchLater = false
            isNotificationEnabled = false
        }
    }
    
    private func playVideoWithAnimationOptimized() {
        withAnimation(.easeOut(duration: 0.4)) {
            showPlayer = true
            showPlayerControls = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            globalPlayer.playVideo(video, showFullscreen: true)
            isPlayerReady = true
            resetPlayerControlsTimerOptimized()
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func togglePlayPauseOptimized() {
        globalPlayer.togglePlayPause()
        
        // Show controls when pausing, manage timer when playing
        if globalPlayer.isPlaying {
            resetPlayerControlsTimerOptimized()
        } else {
            playerControlsTimer?.invalidate()
            withAnimation(.easeOut(duration: 0.25)) {
                showPlayerControls = true
            }
        }
    }
    
    private func togglePlayerControlsOptimized() {
        withAnimation(.easeOut(duration: 0.25)) {
            showPlayerControls.toggle()
        }

        if showPlayerControls && globalPlayer.isPlaying {
            resetPlayerControlsTimerOptimized()
        }
    }
    
    private func resetPlayerControlsTimerOptimized() {
        playerControlsTimer?.invalidate()
        if globalPlayer.isPlaying {
            playerControlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    showPlayerControls = false
                }
            }
        }
    }
    
    private func changeVideoQuality(_ quality: VideoQuality) {
        videoQuality = quality
        HapticManager.shared.impact(style: .light)
    }
    
    private func changePlaybackSpeed(_ speed: Float) {
        playbackRate = speed
        globalPlayer.player?.rate = speed
        HapticManager.shared.impact(style: .light)
    }
    
    private func toggleFullscreenOptimized() {
        withAnimation(.easeOut(duration: 0.25)) {
            isFullscreen.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleLikeWithAnimationOptimized() {
        if isDisliked {
            isDisliked = false
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleDislikeWithAnimationOptimized() {
        if isLiked {
            isLiked = false
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isDisliked.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleSubscriptionWithAnimationOptimized() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSubscribed.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleWatchLaterWithAnimationOptimized() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isWatchLater.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleDescriptionOptimized() {
        withAnimation(.easeOut(duration: 0.25)) {
            expandedDescription.toggle()
        }
        HapticManager.shared.impact(style: .light)
    }
    
    private func shareVideoOptimized() {
        showingShareSheet = true
        HapticManager.shared.impact(style: .light)
    }
    
    private func downloadVideoOptimized() {
        HapticManager.shared.impact(style: .light)
        // Add download implementation
    }
    
    @MainActor
    private func loadCommentsOptimized() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        comments = getSampleCommentsOptimized()
    }
    
    @MainActor
    private func loadRecommendationsOptimized() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
        recommendedVideos = Array(Video.sampleVideos.prefix(5))
    }
    
    private func handleNewComment(_ comment: VideoComment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            comments.insert(comment, at: 0)
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func handleScrollOffsetOptimized(_ offset: CGFloat) {
        if abs(offset - scrollOffset) > 5 {
            scrollOffset = offset
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            globalPlayer.togglePlayPause()
        case .active:
            break
        @unknown default:
            break
        }
    }
    
    private func dismissWithAnimation() {
        // Enhanced cleanup before dismissal
        playerControlsTimer?.invalidate()
        
        // Reset all state
        showPlayer = false
        isPlayerReady = false
        showPlayerControls = false
        
        // Dismiss with proper animation
        withAnimation(.easeOut(duration: 0.3)) {
            dismiss()
        }
    }
    
    private func cleanupVideoOptimized() {
        // More thorough cleanup
        playerControlsTimer?.invalidate()
        playerControlsTimer = nil
        
        // Reset states (but don't stop global player)
        showPlayer = false
        isPlayerReady = false
        showPlayerControls = false
        isBuffering = false
    }
    
    private func formatTimeOptimized(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    private func getSampleCommentsOptimized() -> [VideoComment] {
        return [
            VideoComment(
                id: "1",
                author: User.sampleUsers[1],
                text: "Amazing video! Really loved the content and production quality.",
                likeCount: 42,
                replyCount: 5,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            VideoComment(
                id: "2",
                author: User.sampleUsers[2],
                text: "This was so helpful, thank you for sharing!",
                likeCount: 18,
                replyCount: 2,
                createdAt: Date().addingTimeInterval(-7200)
            )
        ]
    }
}

// MARK: - Enhanced Action Button Component (VideoDetail specific)
struct EnhancedVideoActionButton: View {
    let icon: String
    let text: String
    var isSelected: Bool = false
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.2) : AppTheme.Colors.surface)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? color : AppTheme.Colors.textSecondary)
                }
                
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
    }
}

// MARK: - Optimized Comment Row View (VideoDetail specific)
struct VideoCommentRowView: View {
    let comment: VideoComment
    @State private var isLiked = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Commenter Avatar with optimized caching
            CachedAsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.7))
                    .overlay(
                        Text(String(comment.author.displayName.prefix(1)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                // Comment Header
                HStack(spacing: 8) {
                    Text(comment.author.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(comment.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Spacer()
                }
                
                // Comment Text
                Text(comment.text)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Comment Actions
                HStack(spacing: 20) {
                    Button(action: { toggleLikeOptimized() }) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 16))
                                .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                            
                            if comment.likeCount > 0 {
                                Text(comment.likeCount.formatted())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                    
                    Button(action: { }) {
                        Text("Reply")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .buttonStyle(VideoDetailOptimizedScaleButtonStyle())
                    
                    Spacer()
                }
            }
        }
    }
    
    private func toggleLikeOptimized() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Optimized Recommended Video Row (VideoDetail specific)
struct VideoRecommendedVideoRow: View {
    let video: Video
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with optimized caching
            CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 140, height: 78)
            .cornerRadius(12)
            .clipped()
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(video.formattedDuration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.8))
                            .cornerRadius(4)
                            .padding(.trailing, 6)
                            .padding(.bottom, 6)
                    }
                }
            )
            
            // Video Info
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(video.creator.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 4) {
                    Text(video.formattedViews)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Optimized Button Style (VideoDetail specific)
struct VideoDetailOptimizedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Video Scroll Offset Preference Key
struct VideoScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        VideoDetailView(video: Video.sampleVideos[0])
    }
    .preferredColorScheme(.light)
}