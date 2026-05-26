//
//  VerticalShortsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct VerticalShortsView: View {
    @StateObject private var viewModel = ShortsViewModel()
    @State private var currentIndex = 0
    @State private var showActions = true
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Vertical video feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.shorts.enumerated()), id: \.element.id) { index, short in
                        ShortVideoView(
                            video: short,
                            isActive: index == currentIndex,
                            showActions: $showActions,
                            geometry: geometry
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { idx in
                    if idx >= max(0, viewModel.shorts.count - 3) {
                        Task { await viewModel.loadMoreIfNeeded() }
                    }
                }
                
                // Actions panel overlay
                if showActions, !viewModel.shorts.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            ShortsActionsPanel(
                                video: viewModel.shorts.indices.contains(currentIndex) ? viewModel.shorts[currentIndex] : viewModel.shorts[0],
                                onLike: { videoId in
                                    viewModel.toggleLike(videoId: videoId)
                                },
                                onComment: { videoId in
                                    // Show comments
                                },
                                onShare: { videoId in
                                    // Show share
                                }
                            )
                            .padding(.trailing)
                        }
                        
                        Spacer().frame(height: 120) // Tab bar space
                    }
                }
            }
        }
        .onAppear { viewModel.loadShorts() }
        .onChange(of: currentIndex) { newValue in
            if !viewModel.shorts.isEmpty {
                viewModel.trackView(for: viewModel.shorts[newValue].id)
                
                // 🔥 THERMONUCLEAR: Prefetch next 3 videos for instant swipe
                for offset in 1...3 {
                    let prefetchIdx = newValue + offset
                    if prefetchIdx < viewModel.shorts.count {
                        let prefetchVideo = viewModel.shorts[prefetchIdx]
                        
                        // Use PlayerPoolManager for aggressive asset preloading
                        PlayerPoolManager.shared.preloadAsset(for: prefetchVideo.videoURL)
                        
                        // Also use VideoPlayerManager's prewarm for AVPlayerItem caching
                        VideoPlayerManager.prewarm(urlString: prefetchVideo.videoURL)
                        
                        // Prefetch thumbnail image too
                        if let thumbURL = URL(string: prefetchVideo.thumbnailURL) {
                            ImagePrefetcher.shared.prefetch(urls: [thumbURL])
                        }
                    }
                }
                
                // Also prefetch previous video for smooth back-swipe
                let prevIdx = newValue - 1
                if prevIdx >= 0 {
                    let prevVideo = viewModel.shorts[prevIdx]
                    PlayerPoolManager.shared.preloadAsset(for: prevVideo.videoURL)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showActions = abs(dragOffset) < 50
                    }
                }
                .onEnded { value in
                    dragOffset = 0
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showActions = true
                        }
                    }
                }
        )
    }
}

// MARK: - Short Video View
struct ShortVideoView: View {
    let video: Video
    let isActive: Bool
    @Binding var showActions: Bool
    let geometry: GeometryProxy
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showVideoInfo = true
    @State private var showDebugHUD = false
    
    var body: some View {
        ZStack {
            // Full screen video player
            if isActive, let player = playerManager.player {
                RawPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showVideoInfo.toggle()
                            showActions.toggle()
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        withAnimation(.spring()) { showDebugHUD.toggle() }
                    }
            } else {
                // Thumbnail when not active - 🔥 PERF: Use cached image
                AppAsyncImage(
                    url: URL(string: video.thumbnailURL),
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(9/16, contentMode: .fill)
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(9/16, contentMode: .fill)
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            
            // Video info overlay
            if showVideoInfo {
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            // Creator info - 🔥 PERF: Use cached image
                            HStack(spacing: 12) {
                                AppAsyncImage(
                                    url: URL(string: video.creator.profileImageURL ?? ""),
                                    content: { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                    }
                                )
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
                            
                            // Music info
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
                    .padding(.bottom, 140) // Space for actions and tab bar
                }
            }

            // Debug HUD overlay
            if showDebugHUD, let stats = playerManager.currentPlaybackStats() {
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚙️ Debug HUD").font(.caption2).bold()
                    Text("Res: \(stats.width)x\(stats.height)").font(.caption2)
                    Text("Bitrate: \(stats.bitrateKbps) kbps").font(.caption2)
                    Text(String(format: "FPS: %.1f", stats.fps)).font(.caption2)
                    Text(String(format: "Time: %.1f/%.1f", stats.currentTime, stats.duration)).font(.caption2)
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
            }
        }
        .onAppear {
            if isActive {
                setupPlayer()
            }
        }
        .onChange(of: isActive) { newValue in
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
        playerManager.applyShortsStartupTuning()
    }
}

// MARK: - Shorts Actions Panel
struct ShortsActionsPanel: View {
    let video: Video
    let onLike: (String) -> Void
    let onComment: (String) -> Void
    let onShare: (String) -> Void
    
    @State private var isLiked = false
    @State private var likeCount = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Like button
            VStack(spacing: 4) {
                Button(action: {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
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
                
                Text(formatCount(likeCount > 0 ? likeCount : video.likeCount))
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
                
                Text(formatCount(video.commentCount))
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
            
            // More actions
            VStack(spacing: 4) {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                Text("More")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            // Creator avatar - 🔥 PERF: Use cached image
            Button {
                // Navigate to creator profile
            } label: {
                AppAsyncImage(
                    url: URL(string: video.creator.profileImageURL ?? ""),
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                    }
                )
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
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

// MARK: - Shorts View Model
@MainActor
class ShortsViewModel: ObservableObject {
    @Published var shorts: [Video] = []
    @Published var isLoading = false
    private var isPaging = false
    private let shortsService = ShortsFirestoreService.shared
    
    func loadShorts() {
        isLoading = true
        Task { @MainActor in
            let fetched = await shortsService.fetchNextPage(limit: 10)
            if fetched.isEmpty {
                // Fallback: fetch short-form content from Firestore
                let firestoreVids = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 20)
                var seeds = firestoreVids.filter { $0.isShort || $0.duration < 60 }
                if seeds.isEmpty { seeds = Array(firestoreVids.prefix(10)) }
                self.shorts = seeds
            } else {
                self.shorts = fetched
            }
            isLoading = false
        }
    }

    func loadMoreIfNeeded() async {
        guard !isPaging else { return }
        isPaging = true
        let next = await shortsService.fetchNextPage(limit: 8)
        await MainActor.run {
            if !next.isEmpty { self.shorts.append(contentsOf: next) }
            self.isPaging = false
        }
    }
    
    func toggleLike(videoId: String) {
        if let index = shorts.firstIndex(where: { $0.id == videoId }) {
            print("Liked short video: \(videoId)")
        }
    }
    
    func trackView(for videoId: String) {
        Task {
            try? await APIService.shared.trackView(videoId: videoId, duration: 0)
        }
    }
}

#Preview {
    VerticalShortsView()
}