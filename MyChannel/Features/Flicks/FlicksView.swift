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
    @State private var showingComments = false
    @State private var showingShare = false
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var showingProfile = false
    @State private var selectedCreator: User?
    @State private var subscriberCounts: [String: Int] = [:] // Track subscriber counts
    
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
                    
                    // YouTube-style top overlay
                    topOverlay
                        .zIndex(1)
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
            .onAppear {
                loadFlicksContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FlicksResetToFirst"))) { _ in
                // Handle tab reselection - reset to first video
                resetToFirstVideo()
            }
            .sheet(isPresented: $showingComments) {
                if !videos.isEmpty && currentIndex < videos.count {
                    YouTubeStyleCommentsSheet(video: videos[currentIndex])
                        .presentationDetents([.height(200), .medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingShare) {
                if !videos.isEmpty && currentIndex < videos.count {
                    YouTubeStyleShareSheet(video: videos[currentIndex])
                        .presentationDetents([.height(400)])
                        .presentationDragIndicator(.visible)
                }
            }
            .fullScreenCover(isPresented: $showingProfile) {
                if let creator = selectedCreator {
                    FlicksCreatorProfileView(creator: creator)
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 24) {
                // Animated loading circles
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 12, height: 12)
                            .scaleEffect(1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: UUID()
                            )
                    }
                }
                .onAppear {
                    // Trigger animations
                }
                
                Text("Flicks")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Top Overlay (YouTube Style)
    private var topOverlay: some View {
        VStack {
            HStack {
                // Back/Home button - now functional!
                Button(action: {
                    // Send notification to switch to home tab
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.3))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Center title with YouTube-style design
                Text("Flicks")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Search and Camera buttons
                HStack(spacing: 12) {
                    Button(action: {
                        // Send notification to switch to search tab
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        // Show upload view
                        NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Vertical Video Feed
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
                YouTubeStyleVideoPlayer(
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
                        showingComments = true
                    },
                    onShare: {
                        showingShare = true
                    },
                    onProfileTap: {
                        selectedCreator = videos[index].creator
                        showingProfile = true
                    }
                )
                .tag(index)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: currentIndex) // Add smooth animation
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
            
            // Simulate realistic loading time
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                videos = Video.sampleVideos.shuffled()
                isLoading = false
            }
        }
    }
    
    private func resetToFirstVideo() {
        // Reset to first video when Flicks tab is tapped again
        guard !videos.isEmpty && currentIndex != 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentIndex = 0
        }
        
        // Haptic feedback
        HapticManager.shared.impact(style: .medium)
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
                // Decrease subscriber count
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
            } else {
                followedCreators.insert(creator.id)
                // Increase subscriber count
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func preloadNextVideos(currentIndex: Int) {
        if currentIndex >= videos.count - 3 {
            Task {
                let moreVideos = Video.sampleVideos.shuffled().prefix(5)
                await MainActor.run {
                    videos.append(contentsOf: moreVideos)
                }
            }
        }
    }
}

// MARK: - YouTube Style Video Player
struct YouTubeStyleVideoPlayer: View {
    let video: Video
    let isCurrentVideo: Bool
    let isLiked: Bool
    let isFollowing: Bool
    let subscriberCount: Int
    let onLike: () -> Void
    let onFollow: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onProfileTap: () -> Void
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showControls = false
    @State private var controlsTimer: Timer?
    @State private var isPlaying = true
    @State private var showPlayIcon = false
    
    var body: some View {
        ZStack {
            // Video Player Background
            if isCurrentVideo {
                VideoPlayer(player: playerManager.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onTapGesture {
                        togglePlayPause()
                        showPlayPauseIcon()
                    }
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        playerManager.pause()
                    }
            } else {
                // High-quality thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Rectangle()
                            .fill(.black)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            
            // Play/Pause Icon Overlay
            if showPlayIcon {
                Image(systemName: isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.4))
                            .frame(width: 100, height: 100)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            
            // YouTube-style overlays
            GeometryReader { geometry in
                ZStack {
                    // Bottom gradient for text readability
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 300)
                        .allowsHitTesting(false)
                    }
                    
                    // Content overlays
                    HStack(alignment: .bottom) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            
                            // Creator info section
                            HStack(spacing: 12) {
                                Button(action: onProfileTap) {
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
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("@\(video.creator.username)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        
                                        if video.creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(AppTheme.Colors.primary)
                                        }
                                    }
                                    
                                    Text("\(subscriberCount.formatted()) subscribers")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                // YouTube-style follow button
                                if !isFollowing {
                                    Button(action: onFollow) {
                                        Text("Subscribe")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.white)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 12)
                            
                            // Video description
                            VStack(alignment: .leading, spacing: 8) {
                                Text(video.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                if !video.description.isEmpty {
                                    Text(video.description)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: geometry.size.width * 0.65, alignment: .leading)
                            .padding(.bottom, 100)
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                        
                        // Right side - Action buttons (YouTube style)
                        VStack(spacing: 24) {
                            Spacer()
                            
                            // Like button
                            YouTubeActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                text: formatCount(video.likeCount),
                                isActive: isLiked,
                                activeColor: .red,
                                action: onLike
                            )
                            
                            // Comment button
                            YouTubeActionButton(
                                icon: "bubble.right.fill",
                                text: formatCount(video.commentCount),
                                action: onComment
                            )
                            
                            // Share button
                            YouTubeActionButton(
                                icon: "arrowshape.turn.up.right.fill",
                                text: "Share",
                                action: onShare
                            )
                            
                            // More options
                            YouTubeActionButton(
                                icon: "ellipsis",
                                text: "",
                                action: { }
                            )
                            
                            // Creator profile (mini)
                            Button(action: onProfileTap) {
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.primary.opacity(0.7))
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.play()
        isPlaying = true
    }
    
    private func togglePlayPause() {
        playerManager.togglePlayPause()
        isPlaying.toggle()
        HapticManager.shared.impact(style: .light)
    }
    
    private func showPlayPauseIcon() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showPlayIcon = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showPlayIcon = false
            }
        }
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
}

// MARK: - YouTube Action Button
struct YouTubeActionButton: View {
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
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isActive ? activeColor : .white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(isActive ? .white.opacity(0.2) : .clear)
                    )
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01) {
            // Handle long press if needed
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - YouTube Style Comments Sheet
struct YouTubeStyleCommentsSheet: View {
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
                            YouTubeCommentRow(comment: comment)
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

// MARK: - YouTube Comment Row
struct YouTubeCommentRow: View {
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
                        .fill(AppTheme.Colors.primary.opacity(0.7))
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("@\(comment.author.username)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Button(action: { }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 20) {
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 6) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { }) {
                            Text("Reply")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
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
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.primary)
                        
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Handle bar
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
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ShareOption(icon: "message.fill", title: "Messages", color: .green)
                        ShareOption(icon: "envelope.fill", title: "Mail", color: .blue)
                        ShareOption(icon: "square.and.arrow.up", title: "More", color: .gray)
                        ShareOption(icon: "link", title: "Copy Link", color: .orange)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

struct ShareOption: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color)
                .clipShape(Circle())
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
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
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .overlay(
                                    Text(String(creator.displayName.prefix(1)))
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(creator.displayName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            Text("\(creator.subscriberCount.formatted()) subscribers")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    // Bio
                    if let bio = creator.bio {
                        Text(bio)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Text("Subscribe")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.Colors.surface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
            }
        }
    }
}

#Preview {
    FlicksView()
        .preferredColorScheme(.dark)
}