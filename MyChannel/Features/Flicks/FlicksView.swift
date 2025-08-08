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
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea(.all)
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
    @State private var showControls = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - Always show the thumbnail/image as fallback
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } placeholder: {
                    // Colored background as placeholder
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: Double.random(in: 0.3...0.7), 
                                          green: Double.random(in: 0.3...0.7), 
                                          blue: Double.random(in: 0.3...0.7)),
                                    Color(red: Double.random(in: 0.1...0.5), 
                                          green: Double.random(in: 0.1...0.5), 
                                          blue: Double.random(in: 0.1...0.5))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Tap to Play")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                }
                
                // Video Player (when current and ready)
                if isCurrentVideo && playerManager.player != nil {
                    VideoPlayer(player: playerManager.player)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(playerManager.isLoading ? 0 : 1)
                }
                
                // Bottom gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                
                // Content overlays
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
                        .frame(maxWidth: geometry.size.width * 0.7)
                        
                        // Right side - Action buttons
                        VStack(spacing: 20) {
                            // Like button
                            ActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                text: formatCount(video.likeCount),
                                isActive: isLiked,
                                activeColor: .red,
                                action: onLike
                            )
                            
                            // Dislike button
                            ActionButton(
                                icon: "heart.slash",
                                text: "",
                                action: { }
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                
                // Tap gesture for play/pause
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlayPause()
                    }
            }
        }
        .onAppear {
            if isCurrentVideo {
                setupPlayer()
            }
        }
        .onDisappear {
            playerManager.pause()
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true)
        
        // Auto-play after setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playerManager.play()
        }
    }
    
    private func togglePlayPause() {
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