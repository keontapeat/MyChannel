//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit

struct FlicksView: View {
    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var selectedCreator: User?
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var showingFlicksSettings = false

    @State private var commentsVideo: Video?
    @State private var shareVideo: Video?

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
                    
                    topOverlay
                        .zIndex(2)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden()
            .task {
                if videos.isEmpty { loadFlicksContent() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FlicksResetToFirst"))) { _ in
                resetToFirstVideo()
            }
            .sheet(item: $commentsVideo) { video in
                FlicksCommentsSheet(video: video)
                    .presentationDetents([.height(200), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $shareVideo) { video in
                FlicksShareSheet(video: video)
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedCreator) { creator in
                FlicksCreatorProfileView(creator: creator)
            }
            .sheet(isPresented: $showingFlicksSettings) {
                FlicksSettingsPanel()
                    .presentationDetents([.height(600), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.8),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                    
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.3),
                            value: UUID()
                        )
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                
                VStack(spacing: 12) {
                    Text("Flicks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("Loading amazing content...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: UUID()
                            )
                    }
                }
            }
        }
    }
    
    private var topOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .accessibilityLabel("Home")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Flicks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchBar"), object: nil)
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .accessibilityLabel("Search")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingFlicksSettings = true
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .accessibilityLabel("Flicks Settings")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }
    
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
                ProfessionalVideoPlayer(
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
                        commentsVideo = videos[index]
                    },
                    onShare: {
                        shareVideo = videos[index]
                    },
                    onProfileTap: {
                        selectedCreator = videos[index].creator
                    }
                )
                .id(videos[index].id)
                .tag(index)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(AppTheme.AnimationPresets.spring, value: currentIndex)
        .onChange(of: currentIndex) { _, newValue in
            impactFeedback.impactOccurred()
            preloadNextVideos(currentIndex: newValue)
        }
    }
    
    private func loadFlicksContent() {
        Task {
            isLoading = true
            try? await Task.sleep(nanoseconds: 750_000_000)
            videos = Video.sampleVideos.shuffled()
            isLoading = false
        }
    }
    
    private func resetToFirstVideo() {
        guard !videos.isEmpty && currentIndex != 0 else { return }
        withAnimation(AppTheme.AnimationPresets.spring) {
            currentIndex = 0
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleLike(for video: Video) {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
            } else {
                likedVideos.insert(video.id)
            }
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleFollow(for creator: User) {
        withAnimation(AppTheme.AnimationPresets.spring) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
            } else {
                followedCreators.insert(creator.id)
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
            }
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func preloadNextVideos(currentIndex: Int) {
        if currentIndex >= videos.count - 3 {
            Task {
                let more = Array(Video.sampleVideos.shuffled().prefix(6))
                videos.append(contentsOf: more)
            }
        }
    }
}


struct FlicksCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var comments: [VideoComment] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.2))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comments")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text("\(video.commentCount.formatted()) comments")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            FlicksCommentRow(comment: comment)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial.opacity(0.3))
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    Divider()
                        .background(.gray.opacity(0.2))
                    
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 16) {
                            TextField("Add a thoughtful comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium))
                                .focused($isTextFieldFocused)
                                .lineLimit(1...4)
                            
                            if !newComment.isEmpty {
                                Button("Post") {
                                    postComment()
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(.ultraThinMaterial)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { loadComments() }
    }
    
    private func loadComments() { comments = VideoComment.sampleComments }
    
    private func postComment() {
        guard !newComment.isEmpty else { return }
        let comment = VideoComment(
            author: User.sampleUsers[0],
            text: newComment,
            likeCount: 0,
            replyCount: 0,
            createdAt: Date()
        )
        withAnimation(AppTheme.AnimationPresets.spring) { comments.insert(comment, at: 0) }
        newComment = ""
        isTextFieldFocused = false
        HapticManager.shared.impact(style: .medium)
    }
}

struct FlicksCommentRow: View {
    let comment: VideoComment
    @State private var isLiked = false
    @State private var showReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.8))
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("@\(comment.author.username)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Button(action: { }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 24) {
                        Button(action: toggleLike) {
                            HStack(spacing: 8) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { }) {
                            Text("Reply")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 6)
                }
            }
            
            if comment.replyCount > 0 {
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppTheme.Colors.primary.opacity(0.6))
                            .frame(width: 32, height: 2)
                            .cornerRadius(1)
                        
                        Text("View \(comment.replyCount) replies")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 56)
                .padding(.top, 12)
            }
        }
    }
    
    private func toggleLike() {
        withAnimation(AppTheme.AnimationPresets.bouncy) { isLiked.toggle() }
        HapticManager.shared.impact(style: .light)
    }
}

struct FlicksShareSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                
                HStack {
                    Text("Share")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 24) {
                        FlicksShareOption(icon: "message.fill", title: "Messages", color: .green)
                        FlicksShareOption(icon: "envelope.fill", title: "Mail", color: .blue)
                        FlicksShareOption(icon: "square.and.arrow.up", title: "More", color: .gray)
                        FlicksShareOption(icon: "link", title: "Copy Link", color: AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FlicksShareOption: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

struct FlicksCreatorProfileView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 20) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .overlay(
                                    Text(String(creator.displayName.prefix(1)))
                                        .font(.system(size: 52, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Text(creator.displayName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            Text("\(creator.subscriberCount.formatted()) subscribers")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    if let bio = creator.bio {
                        Text(bio)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Text("Subscribe")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 60)
                .padding(.trailing, 24)
            }
        }
    }
}

struct FlicksSettingsPanel: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flicks_video_quality") private var videoQuality: String = "Auto"
    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0
    @AppStorage("flicks_content_category") private var contentCategory: String = "For You"
    @AppStorage("flicks_feed_type") private var feedType: String = "For You"
    @AppStorage("flicks_auto_play") private var autoPlayNext: Bool = true
    @AppStorage("flicks_data_saver") private var dataSaverMode: Bool = false
    @AppStorage("flicks_captions") private var showCaptions: Bool = false
    
    private let videoQualities = ["Auto", "720p", "1080p", "4K"]
    private let playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let contentCategories = ["For You", "Gaming", "Music", "Comedy", "Tech", "Sports", "Education", "Art", "Food", "Travel"]
    private let feedTypes = ["For You", "Following", "Trending"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.3))
                            .frame(width: 50, height: 5)
                            .padding(.top, 12)
                        
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            
                            Text("Flicks Settings")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    VStack(spacing: 24) {
                        FlicksSettingsSection(
                            title: "Feed Preferences",
                            icon: "rectangle.stack.fill",
                            iconColor: AppTheme.Colors.primary
                        ) {
                            VStack(spacing: 16) {
                                FlicksSettingsPicker(
                                    title: "Feed Type",
                                    selection: $feedType,
                                    options: feedTypes,
                                    icon: "list.bullet"
                                )
                                
                                FlicksSettingsPicker(
                                    title: "Content Category",
                                    selection: $contentCategory,
                                    options: contentCategories,
                                    icon: "tag.fill"
                                )
                            }
                        }
                        
                        FlicksSettingsSection(
                            title: "Video & Playback",
                            icon: "play.rectangle.fill",
                            iconColor: .blue
                        ) {
                            VStack(spacing: 16) {
                                FlicksSettingsPicker(
                                    title: "Video Quality",
                                    selection: $videoQuality,
                                    options: videoQualities,
                                    icon: "4k.tv"
                                )
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "speedometer")
                                            .foregroundStyle(.orange)
                                            .frame(width: 20)
                                        
                                        Text("Playback Speed")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(playbackSpeed, specifier: "%.2f")x")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(playbackSpeeds, id: \.self) { speed in
                                            Button("\(speed, specifier: speed == 1.0 ? "%.0f" : "%.2f")x") {
                                                playbackSpeed = speed
                                                HapticManager.shared.impact(style: .light)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(playbackSpeed == speed ? .white : AppTheme.Colors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                playbackSpeed == speed ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                                                in: Capsule()
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        FlicksSettingsSection(
                            title: "Preferences",
                            icon: "gearshape.fill",
                            iconColor: .purple
                        ) {
                            VStack(spacing: 16) {
                                FlicksSettingsToggle(
                                    title: "Auto-play Next Video",
                                    subtitle: "Automatically play the next video",
                                    isOn: $autoPlayNext,
                                    icon: "play.fill"
                                )
                                
                                FlicksSettingsToggle(
                                    title: "Data Saver Mode",
                                    subtitle: "Use less data by reducing video quality",
                                    isOn: $dataSaverMode,
                                    icon: "wifi.slash"
                                )
                                
                                FlicksSettingsToggle(
                                    title: "Show Captions",
                                    subtitle: "Display closed captions when available",
                                    isOn: $showCaptions,
                                    icon: "captions.bubble"
                                )
                            }
                        }
                        
                        FlicksSettingsSection(
                            title: "Quick Actions",
                            icon: "bolt.fill",
                            iconColor: .yellow
                        ) {
                            VStack(spacing: 12) {
                                FlicksQuickActionButton(
                                    title: "Clear Watch History",
                                    subtitle: "Reset your viewing recommendations",
                                    icon: "trash.fill",
                                    color: .red
                                ) {
                                    HapticManager.shared.impact(style: .medium)
                                }
                                
                                FlicksQuickActionButton(
                                    title: "Refresh Feed",
                                    subtitle: "Get fresh content recommendations",
                                    icon: "arrow.clockwise",
                                    color: .green
                                ) {
                                    HapticManager.shared.impact(style: .medium)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct FlicksSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            content
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct FlicksSettingsPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(selection)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            selection = option
                            HapticManager.shared.impact(style: .light)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? .white : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selection == option ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                            in: Capsule()
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct FlicksSettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                .onChange(of: isOn) { _, _ in
                    HapticManager.shared.impact(style: .light)
                }
        }
    }
}

#Preview {
    FlicksView()
        .preferredColorScheme(.dark)
}