//
//  VerticalVideoFeedView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct VerticalVideoFeedView: View {
    @StateObject private var viewModel = FeedShortsViewModel()
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showActions = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Video feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.shorts.enumerated()), id: \.element.id) { index, short in
                        ShortVideoPlayerView(
                            video: short,
                            isActive: index == currentIndex,
                            showActions: $showActions
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Side actions panel
                if showActions && !viewModel.shorts.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            FeedActionsPanel(
                                video: viewModel.shorts[currentIndex],
                                onLike: { videoId in
                                    viewModel.toggleLike(videoId: videoId)
                                },
                                onComment: { videoId in
                                    // Show comments sheet
                                },
                                onShare: { videoId in
                                    // Show share sheet
                                }
                            )
                            .padding(.trailing)
                        }
                        
                        Spacer().frame(height: 100) // Tab bar space
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadShorts()
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            if !viewModel.shorts.isEmpty {
                viewModel.trackView(for: viewModel.shorts[newValue].id)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                    
                    // Auto-hide actions when scrolling
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showActions = abs(dragOffset) < 50
                    }
                }
                .onEnded { value in
                    dragOffset = 0
                    
                    // Show actions after scroll ends
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showActions = true
                        }
                    }
                }
        )
    }
}

// MARK: - Short Video Player
struct ShortVideoPlayerView: View {
    let video: Video
    let isActive: Bool
    @Binding var showActions: Bool
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showVideoInfo = true
    
    var body: some View {
        ZStack {
            // Video player (full screen)
            if isActive {
                VideoPlayer(player: playerManager.player)
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showVideoInfo.toggle()
                            showActions.toggle()
                        }
                    }
            } else {
                // Thumbnail when not active
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(9/16, contentMode: .fill)
                }
                .clipped()
            }
            
            // Video info overlay
            if showVideoInfo {
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            // Creator info
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.creator.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("@\(video.creator.username)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Button("Follow") {
                                    // Handle follow
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(16)
                            }
                            
                            // Video title/description
                            Text(video.title)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            
                            // Hashtags
                            if !video.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(video.tags.prefix(3), id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Music info (if applicable)
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("Original Audio - \(video.creator.displayName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120) // Space for tab bar and actions
                }
            }
        }
        .onAppear {
            if isActive {
                setupPlayer()
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                setupPlayer()
                playerManager.play()
            } else {
                playerManager.pause()
            }
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true) // Auto-loop shorts
    }
}

// MARK: - Feed Actions Panel (renamed to avoid conflicts)
struct FeedActionsPanel: View {
    let video: Video
    let onLike: (String) -> Void
    let onComment: (String) -> Void
    let onShare: (String) -> Void
    
    @State private var isLiked = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Like button
            VStack(spacing: 4) {
                Button(action: {
                    isLiked.toggle()
                    onLike(video.id)
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(isLiked ? .red : .white)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                    }
                }
                
                Text("\(video.likeCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            // Comment button
            VStack(spacing: 4) {
                Button(action: { onComment(video.id) }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "bubble.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                Text("\(video.commentCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            // Share button
            VStack(spacing: 4) {
                Button(action: { onShare(video.id) }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Share")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            // Creator avatar (links to profile)
            Button(action: {
                // Navigate to creator profile
            }) {
                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            }
        }
    }
}

// MARK: - Feed Shorts View Model (renamed to avoid conflicts)
@MainActor
class FeedShortsViewModel: ObservableObject {
    @Published var shorts: [Video] = []
    @Published var isLoading = false
    
    func loadShorts() {
        isLoading = true
        
        // Simulate loading shorts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.shorts = Video.sampleVideos.filter { $0.isShort || $0.duration < 60 }
            
            // If no shorts, make some regular videos into shorts
            if self.shorts.isEmpty {
                self.shorts = Array(Video.sampleVideos.prefix(10))
            }
            
            self.isLoading = false
        }
    }
    
    func toggleLike(videoId: String) {
        // Update like state
        if let index = shorts.firstIndex(where: { $0.id == videoId }) {
            // This would normally make an API call
            print("Liked video: \(videoId)")
        }
    }
    
    func trackView(for videoId: String) {
        Task {
            try? await APIService.shared.trackView(videoId: videoId, duration: 0)
        }
    }
}

#Preview {
    VerticalVideoFeedView()
}