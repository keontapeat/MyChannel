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
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let swipeThreshold: CGFloat = 50
    
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
                    
                    // Professional overlay controls
                    overlayControls
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
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
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(1.5)
            
            Text("Loading Flicks...")
                .font(AppTheme.Typography.headline)
                .foregroundColor(.white)
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
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: currentIndex) { _, newValue in
            impactFeedback.impactOccurred()
            preloadNextVideos(currentIndex: newValue)
        }
    }
    
    // MARK: - Overlay Controls
    private var overlayControls: some View {
        VStack {
            HStack {
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 16)
                
                Spacer()
                
                Text("Flicks")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func loadFlicksContent() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            // Simulate loading
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                videos = Video.sampleVideos.shuffled()
                isLoading = false
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
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        ZStack {
            // Video Player
            if isCurrentVideo {
                VideoPlayer(player: playerManager.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onTapGesture {
                        togglePlayPause()
                    }
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        playerManager.pause()
                    }
            } else {
                // Thumbnail for non-current videos
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            
            // Professional side actions
            VStack {
                Spacer()
                
                HStack {
                    // Video info
                    VStack(alignment: .leading, spacing: 12) {
                        // Creator info
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .overlay(
                                        Text(String(video.creator.displayName.prefix(1)))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(video.creator.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    if video.creator.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.Colors.primary)
                                    }
                                }
                                
                                Text("\(video.creator.subscriberCount.formatted()) subscribers")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            // Follow button
                            Button(action: onFollow) {
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isFollowing ? AppTheme.Colors.textSecondary : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(isFollowing ? .white.opacity(0.2) : AppTheme.Colors.primary)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Video title and description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(video.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Text(video.description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Professional action buttons
                    VStack(spacing: 24) {
                        // Like button
                        FlicksActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            text: video.likeCount.formatted(),
                            isActive: isLiked,
                            action: onLike
                        )
                        
                        // Comment button
                        FlicksActionButton(
                            icon: "bubble.right",
                            text: video.commentCount.formatted(),
                            action: onComment
                        )
                        
                        // Share button
                        FlicksActionButton(
                            icon: "arrowshape.turn.up.right",
                            text: "Share",
                            action: onShare
                        )
                        
                        // More options
                        FlicksActionButton(
                            icon: "ellipsis",
                            text: "",
                            action: { }
                        )
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.play()
        resetControlsTimer()
    }
    
    private func togglePlayPause() {
        playerManager.togglePlayPause()
        showControls = true
        resetControlsTimer()
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// MARK: - Flicks Action Button
struct FlicksActionButton: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(style: .light)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? AppTheme.Colors.primary : .white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(isActive ? AppTheme.Colors.primary : .white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isActive ? .white : .white)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Flicks Comments Sheet
struct FlicksCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var comments: [VideoComment] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Comments")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(video.commentCount)")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding()
                
                Divider()
                
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            FlicksCommentRow(comment: comment)
                        }
                    }
                    .padding()
                }
                
                // Comment input
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        HStack {
                            TextField("Add a comment...", text: $newComment)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                            
                            if !newComment.isEmpty {
                                Button("Post") {
                                    postComment()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(24)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
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
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Flicks Comment Row
struct FlicksCommentRow: View {
    let comment: VideoComment
    @State private var isLiked = false
    
    var body: some View {
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(comment.author.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(comment.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Spacer()
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 16) {
                    Button(action: { toggleLike() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                            
                            if comment.likeCount > 0 {
                                Text(comment.likeCount.formatted())
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Reply") { }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
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

// MARK: - Preview
#Preview {
    FlicksView()
        .preferredColorScheme(.dark)
}