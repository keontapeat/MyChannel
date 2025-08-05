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
    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var commentsManager = CommentsManager.shared
    @StateObject private var recommendationService = SmartRecommendationService.shared
    
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
    @State private var showMiniPlayer = false
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragValue: CGSize = .zero
    
    // MARK: - Analytics & Performance
    @State private var watchTime: TimeInterval = 0
    @State private var engagementTimer: Timer?
    @State private var viewCountIncremented = false
    
    private let analyticsManager = AnalyticsManager.shared
    private let hapticManager = HapticManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showMiniPlayer {
                    miniPlayerView
                        .offset(dragOffset)
                        .gesture(miniPlayerDragGesture)
                } else {
                    fullScreenView(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onAppear {
            setupVideo()
            loadInitialData()
            trackVideoView()
        }
        .onDisappear {
            cleanupVideo()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { comment in
                handleNewComment(comment)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.videoURL, video.title])
        }
        .sheet(isPresented: $showingMoreOptions) {
            VideoMoreOptionsSheet(video: video, isSubscribed: $isSubscribed, isWatchLater: $isWatchLater)
        }
        .sheet(isPresented: $showingQualitySelector) {
            VideoQualitySelector(selectedQuality: $videoQuality) { quality in
                changeVideoQuality(quality)
            }
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                changePlaybackSpeed(speed)
            }
        }
    }
    
    // MARK: - Full Screen View
    private func fullScreenView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Enhanced Video Player Section
                    enhancedVideoPlayerSection(geometry: geometry)
                    
                    // Video Info Section with Enhanced Details
                    enhancedVideoInfoSection
                    
                    // Enhanced Action Buttons Section
                    enhancedActionButtonsSection
                    
                    // Enhanced Comments Section
                    enhancedCommentsSection
                    
                    // Enhanced Recommended Videos Section
                    enhancedRecommendedVideosSection
                        .id("recommendations")
                }
            }
            .background(AppTheme.Colors.background)
            .coordinateSpace(name: "scroll")
            .onScrollOffsetChange { value in
                handleScrollOffset(value)
            }
        }
    }
    
    // MARK: - Enhanced Video Player Section
    private func enhancedVideoPlayerSection(geometry: GeometryProxy) -> some View {
        ZStack {
            // Video Player Container
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Group {
                        if showPlayer && isPlayerReady {
                            VideoPlayer(player: playerManager.player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .onTapGesture {
                                    togglePlayerControls()
                                }
                                .overlay(
                                    playerControlsOverlay,
                                    alignment: .bottom
                                )
                                .overlay(
                                    bufferingIndicator,
                                    alignment: .center
                                )
                        } else {
                            thumbnailView
                        }
                    }
                )
            
            // Player Gesture Overlays
            if showPlayer {
                HStack {
                    // Double tap left for rewind
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            rewindVideo()
                        }
                    
                    // Double tap right for fast forward
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            fastForwardVideo()
                        }
                }
            }
            
            // Navigation Overlay
            VStack {
                HStack {
                    // Enhanced Back Button
                    Button(action: { dismissWithAnimation() }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Quality and More Options
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
                }
                
                Spacer()
            }
            .opacity(showPlayer ? (showPlayerControls ? 1.0 : 0.0) : 1.0)
            .animation(.easeInOut(duration: 0.3), value: showPlayerControls)
        }
    }
    
    // MARK: - Enhanced Thumbnail View
    private var thumbnailView: some View {
        ZStack {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    )
            }
            
            // Enhanced Play Button
            Button(action: { playVideoWithAnimation() }) {
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
                .scaleEffect(1.0)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            
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
    
    // MARK: - Player Controls Overlay
    private var playerControlsOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if showPlayerControls {
                VStack(spacing: 16) {
                    // Progress Bar
                    VStack(spacing: 8) {
                        // Time Labels and Progress Bar
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Text(formatTime(videoDuration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .monospacedDigit()
                        }
                        
                        // Enhanced Progress Slider
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background Track
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                
                                // Buffered Progress
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: geometry.size.width * CGFloat(playerManager.bufferedProgress), height: 4)
                                    .cornerRadius(2)
                                
                                // Playback Progress
                                Rectangle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geometry.size.width * CGFloat(playbackProgress), height: 4)
                                    .cornerRadius(2)
                                
                                // Thumb
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: isDraggingSeeker ? 16 : 12, height: isDraggingSeeker ? 16 : 12)
                                    .offset(x: geometry.size.width * CGFloat(playbackProgress) - (isDraggingSeeker ? 8 : 6))
                                    .scaleEffect(isDraggingSeeker ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isDraggingSeeker)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDraggingSeeker = true
                                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                        playbackProgress = newProgress
                                        currentTime = newProgress * videoDuration
                                        hapticManager.impact(style: .medium)
                                    }
                                    .onEnded { _ in
                                        isDraggingSeeker = false
                                        playerManager.seek(to: playbackProgress)
                                        hapticManager.impact(style: .medium)
                                    }
                            )
                        }
                        .frame(height: 20)
                    }
                    
                    // Control Buttons
                    HStack(spacing: 32) {
                        // Rewind Button
                        Button(action: { rewindVideo() }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Play/Pause Button
                        Button(action: { togglePlayPause() }) {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Fast Forward Button
                        Button(action: { fastForwardVideo() }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Spacer()
                        
                        // Playback Speed
                        Button(action: { showingPlaybackSpeedSelector = true }) {
                            Text("\(playbackRate, specifier: "%.1f")x")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Fullscreen Button
                        Button(action: { toggleFullscreen() }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
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
        .animation(.easeInOut(duration: 0.3), value: showPlayerControls)
    }
    
    // MARK: - Buffering Indicator
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
            }
        }
    }
    
    // MARK: - Enhanced Video Info Section
    private var enhancedVideoInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title and Stats with Enhanced Typography
            VStack(alignment: .leading, spacing: 12) {
                Text(video.title)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                
                // Enhanced Stats Row
                HStack(spacing: 8) {
                    Label("\(video.formattedViews)", systemImage: "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Label(video.timeAgo, systemImage: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Video Quality Indicator
                    HStack(spacing: 4) {
                        Image(systemName: "tv")
                            .font(.system(size: 12))
                        Text("4K")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Enhanced Creator Info Row
            HStack(spacing: 16) {
                // Creator Avatar with Enhanced Design
                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
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
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.surface, lineWidth: 2)
                )
                
                // Creator Info with Enhanced Layout
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
                    
                    HStack(spacing: 8) {
                        Text("\(video.creator.subscriberCount.formatted()) subscribers")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if video.creator.videoCount > 0 {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(video.creator.videoCount) videos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Enhanced Subscribe Button
                VStack(spacing: 8) {
                    Button(action: { toggleSubscriptionWithAnimation() }) {
                        HStack(spacing: 8) {
                            if !isSubscribed {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .transition(.scale.combined(with: .opacity))
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSubscribed ? AppTheme.Colors.divider : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSubscribed)
                    
                    // Notification Bell (shown when subscribed)
                    if isSubscribed {
                        Button(action: { toggleNotifications() }) {
                            Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                                .font(.system(size: 16))
                                .foregroundColor(isNotificationEnabled ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            // Enhanced Description with Rich Text Support
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(expandedDescription ? nil : 3)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                    
                    if video.description.count > 150 {
                        Button(action: { toggleDescription() }) {
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
                
                // Video Tags/Categories (if available)
                if !video.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(video.tags.prefix(5), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.Colors.primary.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
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
            // Primary Actions Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Like Button with Count
                    EnhancedActionButton(
                        icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                        text: video.likeCount.formatted(),
                        isSelected: isLiked,
                        color: AppTheme.Colors.primary
                    ) {
                        toggleLikeWithAnimation()
                        hapticManager.impact(style: .medium)
                    }
                    
                    // Dislike Button
                    EnhancedActionButton(
                        icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                        text: "Dislike",
                        isSelected: isDisliked,
                        color: AppTheme.Colors.secondary
                    ) {
                        toggleDislikeWithAnimation()
                        hapticManager.impact(style: .medium)
                    }
                    
                    // Share Button
                    EnhancedActionButton(
                        icon: "square.and.arrow.up",
                        text: "Share",
                        color: AppTheme.Colors.accent
                    ) {
                        shareVideo()
                    }
                    
                    // Remix Button
                    EnhancedActionButton(
                        icon: "waveform",
                        text: "Remix",
                        color: AppTheme.Colors.warning
                    ) {
                        remixVideo()
                    }
                    
                    // Save Button
                    EnhancedActionButton(
                        icon: isWatchLater ? "bookmark.fill" : "bookmark",
                        text: "Save",
                        isSelected: isWatchLater,
                        color: AppTheme.Colors.success
                    ) {
                        toggleWatchLaterWithAnimation()
                    }
                    
                    // Download Button
                    EnhancedActionButton(
                        icon: "arrow.down.circle",
                        text: "Download",
                        color: AppTheme.Colors.accent
                    ) {
                        downloadVideo()
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Secondary Actions (Thanks, Report, etc.)
            HStack(spacing: 16) {
                Button(action: { showSuperThanks() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                        Text("Thanks")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(20)
                }
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                Button(action: { showingMoreOptions = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                        Text("More")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Enhanced Comments Section
    private var enhancedCommentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Enhanced Comments Header
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
                    
                    // Enhanced Sort Menu
                    Menu {
                        ForEach(CommentSortOption.allCases, id: \.self) { option in
                            Button(action: { changeCommentSort(option) }) {
                                HStack {
                                    Text(option.displayName)
                                    if commentSortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                            Text(commentSortOption.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
                
                // Enhanced Add Comment Row
                HStack(spacing: 12) {
                    // Current user avatar with online indicator
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // Online indicator
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.background, lineWidth: 2)
                            )
                    }
                    
                    Button(action: { showingCommentComposer = true }) {
                        HStack {
                            Text("Add a comment...")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Spacer()
                            
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textTertiary)
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
            
            // Loading State
            if isLoadingComments {
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        CommentSkeletonView()
                    }
                }
                .padding(.horizontal, 16)
            } else {
                // Enhanced Comments List
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(comments) { comment in
                        EnhancedCommentRowView(comment: comment)
                            .transition(.opacity.combined(with: .slide))
                    }
                }
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.3), value: comments.count)
            }
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
                
                // Autoplay Toggle
                HStack(spacing: 8) {
                    Text("Autoplay")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Toggle("", isOn: .constant(true))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            
            if isLoadingRecommendations {
                VStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        RecommendedVideoSkeletonView()
                    }
                }
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(recommendedVideos) { recommendedVideo in
                        NavigationLink(destination: VideoDetailView(video: recommendedVideo)) {
                            EnhancedRecommendedVideoRow(video: recommendedVideo)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.3), value: recommendedVideos.count)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Mini Player View
    private var miniPlayerView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 12) {
                // Mini video preview
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 80, height: 45)
                .cornerRadius(8)
                .overlay(
                    Button(action: { showMiniPlayer = false }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                )
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 16) {
                    Button(action: { togglePlayPause() }) {
                        Image(systemName: playerManager.isPlaying ? "pause" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Button(action: { dismissMiniPlayer() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Account for tab bar
        }
    }
    
    // MARK: - Gesture Handlers
    private var miniPlayerDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if value.translation.height > 100 {
                    dismissMiniPlayer()
                } else {
                    dragOffset = .zero
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func setupVideo() {
        playerManager.setupPlayer(with: video)
        loadUserPreferences()
        setupPlayerObservers()
    }
    
    private func loadInitialData() {
        loadComments()
        loadRecommendations()
    }
    
    private func loadUserPreferences() {
        isLiked = false
        isSubscribed = false
        isWatchLater = false
        isNotificationEnabled = false
    }
    
    private func setupPlayerObservers() {
    }
    
    private func updatePlaybackProgress(_ time: CMTime) {
        guard !isDraggingSeeker else { return }
        
        let currentSeconds = CMTimeGetSeconds(time)
        let durationSeconds = CMTimeGetSeconds(playerManager.player?.currentItem?.duration ?? CMTime.zero)
        
        currentTime = currentSeconds
        videoDuration = durationSeconds
        
        if durationSeconds > 0 {
            playbackProgress = currentSeconds / durationSeconds
        }
        
        watchTime = currentSeconds
        
        if !viewCountIncremented && currentSeconds >= 30 {
            viewCountIncremented = true
            analyticsManager.trackVideoView(video)
        }
    }
    
    private func playVideoWithAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showPlayer = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playerManager.play()
            isPlayerReady = true
            resetPlayerControlsTimer()
        }
        
        hapticManager.impact(style: .medium)
    }
    
    private func togglePlayPause() {
        playerManager.togglePlayPause()
        hapticManager.impact(style: .medium)
        resetPlayerControlsTimer()
    }
    
    private func togglePlayerControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showPlayerControls.toggle()
        }
        
        if showPlayerControls {
            resetPlayerControlsTimer()
        }
    }
    
    private func resetPlayerControlsTimer() {
        playerControlsTimer?.invalidate()
        playerControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showPlayerControls = false
            }
        }
    }
    
    private func rewindVideo() {
        let currentTime = CMTimeGetSeconds(playerManager.player?.currentTime() ?? CMTime.zero)
        let newTime = max(0, currentTime - 10)
        playerManager.seek(to: newTime / videoDuration)
        hapticManager.impact(style: .medium)
    }
    
    private func fastForwardVideo() {
        let currentTime = CMTimeGetSeconds(playerManager.player?.currentTime() ?? CMTime.zero)
        let duration = CMTimeGetSeconds(playerManager.player?.currentItem?.duration ?? CMTime.zero)
        let newTime = min(duration, currentTime + 10)
        playerManager.seek(to: newTime / videoDuration)
        hapticManager.impact(style: .medium)
    }
    
    private func seekToProgress(_ progress: Double) {
        let duration = CMTimeGetSeconds(playerManager.player?.currentItem?.duration ?? CMTime.zero)
        let newTime = duration * progress
        playerManager.seek(to: newTime / videoDuration)
    }
    
    private func changeVideoQuality(_ quality: VideoQuality) {
        videoQuality = quality
        hapticManager.impact(style: .medium)
    }
    
    private func changePlaybackSpeed(_ speed: Float) {
        playbackRate = speed
        playerManager.player?.rate = speed
        hapticManager.impact(style: .medium)
    }
    
    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func toggleLikeWithAnimation() {
        if isDisliked {
            isDisliked = false
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isLiked.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func toggleDislikeWithAnimation() {
        if isLiked {
            isLiked = false
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isDisliked.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func toggleSubscriptionWithAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isSubscribed.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func toggleWatchLaterWithAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isWatchLater.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func toggleNotifications() {
        isNotificationEnabled.toggle()
        hapticManager.impact(style: .medium)
    }
    
    private func toggleDescription() {
        withAnimation(.easeInOut(duration: 0.3)) {
            expandedDescription.toggle()
        }
        hapticManager.impact(style: .medium)
    }
    
    private func shareVideo() {
        showingShareSheet = true
        hapticManager.impact(style: .medium)
    }
    
    private func remixVideo() {
        hapticManager.impact(style: .medium)
    }
    
    private func downloadVideo() {
        hapticManager.impact(style: .medium)
    }
    
    private func showSuperThanks() {
        hapticManager.impact(style: .medium)
    }
    
    private func changeCommentSort(_ option: CommentSortOption) {
        commentSortOption = option
        loadComments()
        hapticManager.impact(style: .medium)
    }
    
    private func loadComments() {
        isLoadingComments = true
        
        Task {
            do {
                let loadedComments = try await commentsManager.loadComments(for: video.id, sortBy: commentSortOption)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        comments = loadedComments
                        isLoadingComments = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingComments = false
                }
            }
        }
    }
    
    private func loadRecommendations() {
        isLoadingRecommendations = true
        
        Task {
            do {
                let recommendations = try await recommendationService.getSimilarVideos(to: video, limit: 10)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        recommendedVideos = recommendations
                        isLoadingRecommendations = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingRecommendations = false
                }
            }
        }
    }
    
    private func handleNewComment(_ comment: VideoComment) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            comments.insert(comment, at: 0)
        }
        hapticManager.impact(style: .medium)
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
        let maxOffset: CGFloat = 100
        headerOpacity = Double(max(0, min(1, 1 - (abs(offset) / maxOffset))))
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            playerManager.pause()
        case .active:
            break
        @unknown default:
            break
        }
    }
    
    private func trackVideoView() {
        analyticsManager.trackVideoImpression(video)
        
        engagementTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            analyticsManager.trackVideoEngagement(video, watchTime: watchTime)
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dismiss()
        }
    }
    
    private func dismissMiniPlayer() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showMiniPlayer = false
            playerManager.pause()
        }
    }
    
    private func cleanupVideo() {
        playerControlsTimer?.invalidate()
        engagementTimer?.invalidate()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        
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
}

// MARK: - Enhanced Action Button
struct EnhancedActionButton: View {
    let icon: String
    let text: String
    var isSelected: Bool = false
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
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
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Enhanced Comment Row View
struct EnhancedCommentRowView: View {
    let comment: VideoComment
    @State private var isLiked = false
    @State private var showingReplies = false
    @State private var isReplying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // Enhanced Commenter Avatar
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.7), AppTheme.Colors.primary.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 12) {
                    // Enhanced Comment Header
                    HStack(spacing: 8) {
                        Text(comment.author.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if comment.author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Menu {
                            Button("Report") { }
                            Button("Hide user from channel") { }
                            Button("Copy") { }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    // Enhanced Comment Text
                    Text(comment.text)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                    
                    // Enhanced Comment Actions
                    HStack(spacing: 20) {
                        Button(action: { toggleLike() }) {
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
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: { }) {
                            Image(systemName: "hand.thumbsdown")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: { isReplying = true }) {
                            Text("Reply")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Spacer()
                    }
                    
                    // Enhanced Show Replies Button
                    if comment.replyCount > 0 {
                        Button(action: { toggleReplies() }) {
                            HStack(spacing: 8) {
                                Image(systemName: showingReplies ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text("\(comment.replyCount) \(comment.replyCount == 1 ? "reply" : "replies")")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        if showingReplies {
                            VStack(spacing: 12) {
                                ForEach(0..<min(comment.replyCount, 3), id: \.self) { index in
                                    HStack(alignment: .top, spacing: 12) {
                                        Rectangle()
                                            .fill(AppTheme.Colors.divider)
                                            .frame(width: 2, height: 24)
                                        
                                        Circle()
                                            .fill(AppTheme.Colors.surface)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text("R")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text("Reply Author")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                                
                                                Text("1h ago")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                            }
                                            
                                            Text("This is a sample reply to the comment.")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.Colors.textSecondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.leading, 24)
                            .transition(.opacity.combined(with: .slide))
                        }
                    }
                }
            }
            
            if isReplying {
                // Reply composer
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("Y")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    TextField("Reply to \(comment.author.displayName)...", text: .constant(""))
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(16)
                    
                    Button("Cancel") {
                        isReplying = false
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.leading, 48)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingReplies)
        .animation(.easeInOut(duration: 0.3), value: isReplying)
    }
    
    private func toggleLike() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleReplies() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingReplies.toggle()
        }
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Enhanced Recommended Video Row
struct EnhancedRecommendedVideoRow: View {
    let video: Video
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced Thumbnail
            ZStack {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        )
                }
                .frame(width: 140, height: 78)
                .cornerRadius(12)
                .clipped()
                
                // Duration badge
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
                
                // Watch progress indicator
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(AppTheme.Colors.primary)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 3)
                        .opacity(0.3) // Simulate some progress
                }
            }
            
            // Enhanced Video Info
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                
                HStack(spacing: 6) {
                    Text(video.creator.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(video.formattedViews)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.timeAgo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Enhanced More options
            Menu {
                Button("Watch later") { }
                Button("Add to playlist") { }
                Button("Share") { }
                Button("Not interested") { }
                Button("Don't recommend channel") { }
                Button("Report") { }
            } label: {
                Image(systemName: "ellipsis.vertical")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .padding(8)
            }
        }
        .padding(.vertical, 8)
        .background(isHovered ? AppTheme.Colors.surface.opacity(0.5) : Color.clear)
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Supporting Components

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CommentSkeletonView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 16)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 40)
                    .cornerRadius(4)
                
                HStack {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 60, height: 16)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 40, height: 16)
                        .cornerRadius(4)
                    
                    Spacer()
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct RecommendedVideoSkeletonView: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 140, height: 78)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 32)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 16)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 16)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            Spacer()
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Preview
struct VideoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        VideoDetailView(video: Video.sampleVideos[0])
    }
}