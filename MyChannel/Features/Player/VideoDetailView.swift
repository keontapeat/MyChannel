//
//  VideoDetailView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var commentsManager = CommentsManager()
    @StateObject private var recommendationService = SmartRecommendationService.shared
    
    @State private var showPlayer = false
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var isSubscribed = false
    @State private var isWatchLater = false
    @State private var showingCommentComposer = false
    @State private var showingShareSheet = false
    @State private var showingMoreOptions = false
    @State private var recommendedVideos: [Video] = []
    @State private var comments: [VideoComment] = []
    @State private var expandedDescription = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Video Player Section
                    videoPlayerSection
                    
                    // Video Info Section
                    videoInfoSection
                    
                    // Action Buttons Section
                    actionButtonsSection
                    
                    // Comments Section
                    commentsSection
                    
                    // Recommended Videos Section
                    recommendedVideosSection
                }
            }
            .background(AppTheme.Colors.background)
            .ignoresSafeArea(.container, edges: .top)
        }
        .navigationBarHidden(true)
        .onAppear {
            setupVideo()
            loadComments()
            loadRecommendations()
        }
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { comment in
                commentsManager.addComment(comment)
                comments.insert(comment, at: 0)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.videoURL])
        }
        .sheet(isPresented: $showingMoreOptions) {
            VideoMoreOptionsSheet(video: video)
        }
    }
    
    // MARK: - Video Player Section
    private var videoPlayerSection: some View {
        ZStack {
            // Video Player
            if showPlayer {
                VideoPlayer(player: playerManager.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .background(Color.black)
            } else {
                // Thumbnail with play button
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        )
                }
                .clipped()
                .overlay(
                    Button(action: { playVideo() }) {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.7))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .offset(x: 3) // Center the play icon
                        }
                    }
                    .scaleEffect(1.0)
                    .shadow(radius: 10)
                )
            }
            
            // Back button overlay
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.6))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Video Info Section
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Stats
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("\(video.formattedViews) views")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(video.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            // Creator Info Row
            HStack(spacing: 12) {
                // Creator Avatar
                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .font(.system(size: 20))
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // Creator Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(video.creator.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text("\(video.creator.subscriberCount.formatted()) subscribers")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Subscribe Button
                Button(action: { toggleSubscription() }) {
                    HStack(spacing: 6) {
                        if !isSubscribed {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                        }
                        
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(isSubscribed ? AppTheme.Colors.textSecondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary
                    )
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text(video.description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(expandedDescription ? nil : 3)
                    .multilineTextAlignment(.leading)
                
                if video.description.count > 100 {
                    Button(expandedDescription ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedDescription.toggle()
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Like Button
                ActionButton(
                    icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    text: video.likeCount.formatted(),
                    isSelected: isLiked
                ) {
                    toggleLike()
                }
                
                // Dislike Button
                ActionButton(
                    icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    text: "Dislike",
                    isSelected: isDisliked
                ) {
                    toggleDislike()
                }
                
                // Share Button
                ActionButton(
                    icon: "square.and.arrow.up",
                    text: "Share"
                ) {
                    showingShareSheet = true
                }
                
                // Remix Button
                ActionButton(
                    icon: "waveform",
                    text: "Remix"
                ) {
                    // Handle remix
                }
                
                // Thanks Button
                ActionButton(
                    icon: "heart",
                    text: "Thanks"
                ) {
                    // Handle thanks/super thanks
                }
                
                // Download Button
                ActionButton(
                    icon: "arrow.down.circle",
                    text: "Download"
                ) {
                    // Handle download
                }
                
                // Save Button
                ActionButton(
                    icon: isWatchLater ? "bookmark.fill" : "bookmark",
                    text: "Save",
                    isSelected: isWatchLater
                ) {
                    toggleWatchLater()
                }
                
                // More Button
                ActionButton(
                    icon: "ellipsis",
                    text: "More"
                ) {
                    showingMoreOptions = true
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Comments Header
            HStack {
                Text("Comments")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("•")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(video.commentCount)")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                // Sort button
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                        Text("Sort")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            
            // Add Comment Row
            HStack(spacing: 12) {
                // Current user avatar
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("Y")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Button(action: { showingCommentComposer = true }) {
                    HStack {
                        Text("Add a comment...")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            
            // Comments List
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(comments) { comment in
                    CommentRowView(comment: comment)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Recommended Videos Section
    private var recommendedVideosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Up next")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(recommendedVideos) { recommendedVideo in
                    NavigationLink(destination: VideoDetailView(video: recommendedVideo)) {
                        RecommendedVideoRow(video: recommendedVideo)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Helper Methods
    private func setupVideo() {
        playerManager.setupPlayer(with: video)
        
        // Set initial states (you'd load these from your data store)
        isLiked = false // Load from user preferences
        isSubscribed = false // Load from user subscriptions
        isWatchLater = false // Load from user saved videos
    }
    
    private func playVideo() {
        showPlayer = true
        playerManager.togglePlayPause()
    }
    
    private func toggleLike() {
        if isDisliked {
            isDisliked = false
        }
        isLiked.toggle()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // TODO: Send like/unlike to backend
    }
    
    private func toggleDislike() {
        if isLiked {
            isLiked = false
        }
        isDisliked.toggle()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // TODO: Send dislike to backend
    }
    
    private func toggleSubscription() {
        isSubscribed.toggle()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // TODO: Subscribe/unsubscribe from backend
    }
    
    private func toggleWatchLater() {
        isWatchLater.toggle()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // TODO: Save/remove from watch later
    }
    
    private func loadComments() {
        // Load comments for this video
        Task {
            comments = await commentsManager.loadComments(for: video.id)
        }
    }
    
    private func loadRecommendations() {
        Task {
            do {
                recommendedVideos = try await recommendationService.getSimilarVideos(to: video, limit: 10)
            } catch {
                print("Failed to load recommendations: \(error)")
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let text: String
    var isSelected: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
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

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: VideoComment
    @State private var isLiked = false
    @State private var showingReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Commenter Avatar
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    // Comment Header
                    HStack(spacing: 8) {
                        Text(comment.author.displayName)
                            .font(.system(size: 13, weight: .semibold))
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
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    // Comment Text
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    // Comment Actions
                    HStack(spacing: 16) {
                        Button(action: { isLiked.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.system(size: 14))
                                    .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "hand.thumbsdown")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        Button("Reply") {
                            // Handle reply
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                    }
                    
                    // Show Replies Button
                    if comment.replyCount > 0 {
                        Button(action: { showingReplies.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: showingReplies ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text("\(comment.replyCount) replies")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        if showingReplies {
                            // TODO: Load and show replies
                            VStack(spacing: 8) {
                                ForEach(0..<min(comment.replyCount, 3), id: \.self) { _ in
                                    HStack {
                                        Rectangle()
                                            .fill(AppTheme.Colors.divider)
                                            .frame(width: 1, height: 20)
                                            .padding(.trailing, 8)
                                        
                                        Text("Sample reply text...")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Recommended Video Row
struct RecommendedVideoRow: View {
    let video: Video
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
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
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .clipped()
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(4),
                alignment: .bottomTrailing
            )
            
            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(video.creator.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Text("\(video.formattedViews) views")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // More options
            Button(action: {}) {
                Image(systemName: "ellipsis.vertical")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views and Models
struct CommentComposerView: View {
    let video: Video
    let onComment: (VideoComment) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Video Info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 60, height: 34)
                    .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Comment Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Name")
                                .font(.system(size: 14, weight: .medium))
                            
                            TextField("Add a comment...", text: $commentText, axis: .vertical)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                                .lineLimit(5...10)
                        }
                    }
                    
                    Rectangle()
                        .fill(AppTheme.Colors.divider)
                        .frame(height: 1)
                        .padding(.leading, 44)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Button(action: postComment) {
                        if isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Comment")
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(commentText.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                    .cornerRadius(16)
                    .disabled(commentText.isEmpty || isPosting)
                }
                .padding()
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func postComment() {
        guard !commentText.isEmpty else { return }
        
        isPosting = true
        
        // Simulate posting delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let newComment = VideoComment(
                author: User.sampleUsers[0], // Current user
                text: commentText,
                likeCount: 0,
                replyCount: 0,
                createdAt: Date()
            )
            
            onComment(newComment)
            isPosting = false
            dismiss()
        }
    }
}

struct VideoMoreOptionsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Video Info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 60, height: 34)
                    .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Options List
                VStack(spacing: 0) {
                    VideoOptionRow(icon: "plus.rectangle.on.folder", title: "Add to playlist") {}
                    VideoOptionRow(icon: "clock", title: "Save to Watch Later") {}
                    VideoOptionRow(icon: "square.and.arrow.up", title: "Share") {}
                    VideoOptionRow(icon: "person.crop.circle.badge.minus", title: "Don't recommend channel") {}
                    VideoOptionRow(icon: "hand.thumbsdown", title: "Not interested") {}
                    VideoOptionRow(icon: "flag", title: "Report") {}
                }
                
                Spacer()
            }
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct VideoOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VideoShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Comments Manager
class CommentsManager: ObservableObject {
    @Published var comments: [VideoComment] = []
    
    func loadComments(for videoId: String) async -> [VideoComment] {
        // Simulate loading comments
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        return VideoComment.sampleComments
    }
    
    func addComment(_ comment: VideoComment) {
        comments.insert(comment, at: 0)
    }
}

// MARK: - Video Comment Model
struct VideoComment: Identifiable, Codable {
    let id: String
    let author: User
    let text: String
    let likeCount: Int
    let replyCount: Int
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        author: User,
        text: String,
        likeCount: Int = 0,
        replyCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.createdAt = createdAt
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension VideoComment {
    static let sampleComments: [VideoComment] = [
        VideoComment(
            author: User.sampleUsers[1],
            text: "This video is absolutely amazing! The explanation was so clear and easy to follow. Thanks for sharing this knowledge!",
            likeCount: 156,
            replyCount: 12,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[2],
            text: "Finally someone who actually knows what they're talking about. Subscribed! 🔥",
            likeCount: 89,
            replyCount: 5,
            createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[3],
            text: "Could you make a follow-up video covering the advanced techniques? This was super helpful!",
            likeCount: 34,
            replyCount: 3,
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[0],
            text: "The quality of your content keeps getting better. Keep up the great work! 👏",
            likeCount: 67,
            replyCount: 8,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        )
    ]
}

#Preview {
    VideoDetailView(video: Video.sampleVideos[0])
}