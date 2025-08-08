//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct FlicksView: View {
    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingComments = false
    @State private var showingShare = false
    @State private var showingSearch = false
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let swipeThreshold: CGFloat = 50
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea(.all)
                    
                    if isLoading {
                        loadingView
                    } else {
                        verticalVideoFeed(geometry: geometry)
                    }
                    
                    // Search button - top right only
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button(action: { 
                                showingSearch = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.black.opacity(0.4))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
            .ignoresSafeArea(.all)
            .onAppear {
                loadFlicksContent()
            }
            .sheet(isPresented: $showingComments) {
                if !videos.isEmpty && currentIndex < videos.count {
                    FlicksCommentsSheet(video: videos[currentIndex])
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingShare) {
                if !videos.isEmpty && currentIndex < videos.count {
                    VideoShareSheet(items: [videos[currentIndex].videoURL, videos[currentIndex].title])
                        .presentationDetents([.medium])
                }
            }
            .fullScreenCover(isPresented: $showingSearch) {
                SearchView()
            }
        }
    }
    
    // MARK: - Loading View  
    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    .scaleEffect(1.5)
                
                Text("Loading Flicks...")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Vertical Video Feed
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
                FlicksVideoPlayer(
                    video: videos[index],
                    isCurrentVideo: index == currentIndex,
                    isLiked: likedVideos.contains(videos[index].id),
                    isFollowing: followedCreators.contains(videos[index].creator.id),
                    onLike: {
                        toggleLike(for: videos[index])
                    },
                    onFollow: {
                        toggleFollow(for: videos[index].creator)
                    },
                    onComment: {
                        showingComments = true
                    },
                    onShare: {
                        showingShare = true
                    }
                )
                .tag(index)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea(.all)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .onChange(of: currentIndex) { _, newValue in
            impactFeedback.impactOccurred()
            preloadNextVideos(currentIndex: newValue)
        }
    }

    // MARK: - Helper Methods
    private func loadFlicksContent() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            // Simulate loading
            try? await Task.sleep(nanoseconds: 500_000_000) // Reduced to 0.5 seconds
            
            await MainActor.run {
                videos = Video.sampleVideos.shuffled()
                isLoading = false
                print("🔥 Loaded \(videos.count) videos for Flicks")
            }
        }
    }
    
    private func toggleLike(for video: Video) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
            } else {
                likedVideos.insert(video.id)
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleFollow(for creator: User) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
            } else {
                followedCreators.insert(creator.id)
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func preloadNextVideos(currentIndex: Int) {
        // Preload logic for smooth scrolling
        if currentIndex >= videos.count - 3 {
            // Load more videos
            Task {
                let moreVideos = Video.sampleVideos.shuffled().prefix(5)
                await MainActor.run {
                    videos.append(contentsOf: moreVideos)
                }
            }
        }
    }
}

// MARK: - Flicks Video Player
struct FlicksVideoPlayer: View {
    let video: Video
    let isCurrentVideo: Bool
    let isLiked: Bool
    let isFollowing: Bool
    let onLike: () -> Void
    let onFollow: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showControls = false
    @State private var hasSetupPlayer = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // SLEEK YOUTUBE-STYLE BACKGROUND
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(
                            // Dark overlay for better contrast
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.0),
                                            Color.black.opacity(0.2),
                                            Color.black.opacity(0.6)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                } placeholder: {
                    // PREMIUM SLEEK PLACEHOLDER
                    ZStack {
                        // Animated gradient background
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.1, green: 0.1, blue: 0.3),
                                        Color(red: 0.2, green: 0.0, blue: 0.4),
                                        Color(red: 0.4, green: 0.0, blue: 0.6),
                                        Color(red: 0.6, green: 0.0, blue: 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Subtle pattern overlay
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.clear,
                                        Color.black.opacity(0.2)
                                    ],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 400
                                )
                            )
                        
                        // SLEEK CONTENT OVERLAY
                        VStack(spacing: 24) {
                            // Category badge
                            HStack {
                                Image(systemName: video.category.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(video.category.displayName.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(video.category.color.opacity(0.5), lineWidth: 1)
                                    )
                            )
                            
                            // Main play button with glow effect
                            ZStack {
                                // Glow effect
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                
                                // Play button
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(0.3), lineWidth: 2)
                                        )
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                        .offset(x: 3) // Slight offset for visual balance
                                }
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            
                            // Title with glassmorphism background
                            VStack(spacing: 8) {
                                Text(video.title)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                
                                // Stats row
                                HStack(spacing: 16) {
                                    Label(video.formattedViewCount, systemImage: "eye.fill")
                                    Label(video.formattedLikeCount, systemImage: "heart.fill")
                                    Label(video.formattedDuration, systemImage: "clock.fill")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            
                            // Tap to play hint
                            Text("TAP TO PLAY")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(2)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.black.opacity(0.3))
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                // Video Player (when current and ready) - PROPER ASPECT RATIO
                if isCurrentVideo && playerManager.player != nil {
                    VideoPlayer(player: playerManager.player)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(.black)
                        .allowsHitTesting(false) // Let our tap gesture handle interactions
                }
                
                // SLEEK LOADING STATE
                if isCurrentVideo && playerManager.isLoading {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.4))
                            .background(.ultraThinMaterial)
                        
                        VStack(spacing: 20) {
                            // Animated loading ring
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 4)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                            }
                            
                            VStack(spacing: 8) {
                                Text("Loading Video")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Preparing your experience...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                // PREMIUM ERROR STATE
                if isCurrentVideo && playerManager.hasError {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.6))
                            .background(.ultraThinMaterial)
                        
                        VStack(spacing: 24) {
                            // Error icon with glow
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.red.opacity(0.2),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red.opacity(0.9))
                                    .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                            
                            VStack(spacing: 12) {
                                Text("Video Unavailable")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(playerManager.errorMessage ?? "Unable to load this video right now")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            
                            // Retry button
                            Button(action: { setupPlayer() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Try Again")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(.white)
                                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                // Bottom gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                
                // Content overlays - PROPER POSITIONING
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 16) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 12) {
                            // Creator section
                            HStack(spacing: 12) {
                                // Profile image
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.primary)
                                        .overlay(
                                            Text(String(video.creator.displayName.prefix(1)))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                )
                                
                                // Creator info
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("@\(video.creator.username)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        if video.creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.Colors.primary)
                                        }
                                    }
                                    
                                    Text("\(formatSubscribers(video.creator.subscriberCount)) subscribers")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                // Subscribe button
                                if !isFollowing {
                                    Button(action: onFollow) {
                                        Text("Subscribe")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.white)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Video title and description
                            VStack(alignment: .leading, spacing: 6) {
                                Text(video.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                if !video.description.isEmpty {
                                    Text(video.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .frame(maxWidth: geometry.size.width * 0.65) // Fixed width calculation
                        
                        // Right side - Action buttons
                        VStack(spacing: 18) {
                            // Like button
                            ActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                text: formatCount(video.likeCount),
                                isActive: isLiked,
                                activeColor: .red,
                                action: onLike
                            )
                            
                            // Comment button
                            ActionButton(
                                icon: "bubble.right.fill",
                                text: formatCount(video.commentCount),
                                action: onComment
                            )
                            
                            // Share button
                            ActionButton(
                                icon: "arrowshape.turn.up.right.fill",
                                text: "Share",
                                action: onShare
                            )
                            
                            // More button
                            ActionButton(
                                icon: "ellipsis",
                                text: "",
                                action: { }
                            )
                        }
                        .frame(width: 60) // Fixed width for action buttons
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 40) // Dynamic bottom padding
                }
                
                // Tap gesture for play/pause - FULL SCREEN
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isCurrentVideo {
                            if playerManager.player != nil {
                                togglePlayPause()
                            } else {
                                setupPlayer()
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            if isCurrentVideo && !hasSetupPlayer {
                setupPlayer()
            }
        }
        .onChange(of: isCurrentVideo) { _, newValue in
            if newValue && !hasSetupPlayer {
                setupPlayer()
            } else if !newValue {
                playerManager.pause()
                hasSetupPlayer = false
            }
        }
        .onDisappear {
            playerManager.pause()
            hasSetupPlayer = false
        }
    }
    
    private func setupPlayer() {
        print("🎬 Setting up player for: \(video.title)")
        hasSetupPlayer = true
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true)
        
        // Auto-play immediately when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isCurrentVideo && !playerManager.hasError {
                print("▶️ Starting auto-play for: \(self.video.title)")
                playerManager.play()
            }
        }
    }
    
    private func togglePlayPause() {
        print("🎯 Toggle play/pause - isPlaying: \(playerManager.isPlaying)")
        playerManager.togglePlayPause()
        HapticManager.shared.impact(style: .light)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    private func formatSubscribers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Simple Action Button
struct ActionButton: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var activeColor: Color = AppTheme.Colors.primary
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(style: .light)
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isActive ? activeColor : .white)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01) {
            // Handle if needed
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Flicks Comments Sheet
struct FlicksCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var comments: [VideoComment] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(.gray.opacity(0.4))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                
                // Header with YouTube styling
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comments")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text("\(video.commentCount) comments")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            FlicksCommentRow(comment: comment)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                    }
                }
                
                // Comment input (YouTube style)
                VStack(spacing: 0) {
                    Divider()
                        .background(.gray.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        
                        HStack(spacing: 12) {
                            TextField("Add a comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .focused($isTextFieldFocused)
                                .lineLimit(1...4)
                            
                            if !newComment.isEmpty {
                                Button("Post") {
                                    postComment()
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        comments = VideoComment.sampleComments
    }
    
    private func postComment() {
        guard !newComment.isEmpty else { return }
        
        let comment = VideoComment(
            author: User.sampleUsers[0],
            text: newComment,
            likeCount: 0,
            replyCount: 0,
            createdAt: Date()
        )
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            comments.insert(comment, at: 0)
        }
        
        newComment = ""
        isTextFieldFocused = false
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Flicks Comment Row
struct FlicksCommentRow: View {
    let comment: VideoComment
    @State private var isLiked = false
    @State private var showReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.7));
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("@\(comment.author.username)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Button(action: { }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 20) {
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 6) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { }) {
                            Text("Reply")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            
            // Show replies section
            if comment.replyCount > 0 {
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(AppTheme.Colors.textTertiary)
                            .frame(width: 24, height: 1)
                        
                        Text("\(comment.replyCount) replies")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 48)
                .padding(.top, 8)
            }
        }
    }
    
    private func toggleLike() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - YouTube Style Share Sheet
struct YouTubeStyleShareSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    private let shareOptions = [
        ("message.fill", "Messages"),
        ("square.and.arrow.up.fill", "Copy Link"),
        ("square.on.square", "Copy"),
        ("bookmark.fill", "Save"),
        ("exclamationmark.triangle.fill", "Report")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(.gray.opacity(0.4))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            // Header
            HStack {
                Text("Share")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Share options
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                ForEach(shareOptions, id: \.0) { icon, title in
                    Button(action: { }) {
                        VStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 56, height: 56)
                                .background(.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            
            Spacer()
        }
    }
}

// MARK: - Flicks Creator Profile View  
struct FlicksCreatorProfileView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("@\(creator.username)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FlicksView()
        .preferredColorScheme(.dark)
}