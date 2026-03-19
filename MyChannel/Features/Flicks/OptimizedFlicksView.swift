//
//  OptimizedFlicksView.swift
//  MyChannel
//
//  🔥 INFINITE SCROLL FLICKS - TikTok-LEVEL PERFORMANCE
//  Viewport rendering, preloading, smooth gestures
//

import SwiftUI
import AVKit

struct OptimizedFlicksView: View {
    @StateObject private var viewModel = FlicksViewModel()
    @StateObject private var scrollOptimizer = AdvancedScrollOptimizer.shared
    @StateObject private var playerPool = VideoPlayerPool.shared
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isTransitioning = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Vertical paging scroll
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.flicks.enumerated()), id: \.element.id) { index, flick in
                        FlickPlayerView(
                            flick: flick,
                            isActive: index == currentIndex,
                            geometry: geometry
                        )
                        .tag(index)
                        .onAppear {
                            handleFlickAppear(index: index)
                        }
                        .onDisappear {
                            handleFlickDisappear(index: index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { newIndex in
                    handleIndexChange(newIndex)
                }
                
                // UI Overlay
                FlickOverlayUI(flick: viewModel.flicks[safe: currentIndex])
            }
        }
        .onAppear {
            viewModel.loadInitialFlicks()
            preloadAdjacentFlicks()
        }
        .trackPerformance("FlicksView")
    }
    
    // MARK: - Performance Optimizations
    
    private func handleFlickAppear(index: Int) {
        // Preload next 3 flicks
        let preloadIndices = (index + 1)...(index + 3)
        for i in preloadIndices {
            guard i < viewModel.flicks.count else { continue }
            let flick = viewModel.flicks[i]
            
            Task {
                await preloadFlick(flick)
            }
        }
        
        // Load more if near end
        if index >= viewModel.flicks.count - 5 {
            Task {
                await viewModel.loadMoreFlicks()
            }
        }
    }
    
    private func handleFlickDisappear(index: Int) {
        // Release player for off-screen flicks
        let flick = viewModel.flicks[safe: index]
        if let flickId = flick?.id {
            playerPool.releasePlayer(for: flickId)
        }
    }
    
    private func handleIndexChange(_ newIndex: Int) {
        // Track view
        if let flick = viewModel.flicks[safe: newIndex] {
            viewModel.trackView(flick: flick)
        }
        
        // Preload adjacent
        preloadAdjacentFlicks()
    }
    
    private func preloadAdjacentFlicks() {
        let indices = [currentIndex - 1, currentIndex, currentIndex + 1, currentIndex + 2]
        
        for index in indices {
            guard let flick = viewModel.flicks[safe: index] else { continue }
            
            Task {
                await preloadFlick(flick)
            }
        }
    }
    
    private func preloadFlick(_ flick: Flick) async {
        guard let videoURL = flick.videoURL else { return }
        
        // Preload video asset
        VideoPreloadManager.shared.preloadVideo(url: videoURL, videoId: flick.id)
        
        // Prefetch thumbnail
        if let thumbnailURL = flick.thumbnailURL {
            ImagePrefetcher.shared.prefetch(url: thumbnailURL)
        }
    }
}

// MARK: - Flick Player View

struct FlickPlayerView: View {
    let flick: Flick
    let isActive: Bool
    let geometry: GeometryProxy
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isMuted = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
            } else {
                // Loading placeholder
                AsyncImage(url: flick.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .ignoresSafeArea()
            }
            
            // Tap to pause/play
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlayback()
                }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .onAppear {
            if isActive {
                setupPlayer()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                setupPlayer()
                play()
            } else {
                pause()
            }
        }
    }
    
    private func setupPlayer() {
        guard player == nil, let videoURL = flick.videoURL else { return }
        
        // Get player from pool
        let pooledPlayer = VideoPlayerPool.shared.acquirePlayer(for: flick.id)
        
        // Check for preloaded item
        if let playerItem = VideoPreloadManager.shared.getPreloadedItem(for: flick.id) {
            pooledPlayer.replaceCurrentItem(with: playerItem)
            print("🔥 [Flicks] Using preloaded item for \(flick.id)")
        } else {
            let playerItem = AVPlayerItem(url: videoURL)
            pooledPlayer.replaceCurrentItem(with: playerItem)
        }
        
        // Configure for looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: pooledPlayer.currentItem,
            queue: .main
        ) { _ in
            pooledPlayer.seek(to: .zero)
            pooledPlayer.play()
        }
        
        player = pooledPlayer
    }
    
    private func play() {
        player?.play()
        isPlaying = true
    }
    
    private func pause() {
        player?.pause()
        isPlaying = false
    }
    
    private func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
}

// MARK: - Flick Overlay UI

struct FlickOverlayUI: View {
    let flick: Flick?
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                // Creator info
                if let flick = flick {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(flick.creator.username)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(flick.caption)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 20) {
                    FlicksActionButton(icon: "heart.fill", count: flick?.likes ?? 0)
                    FlicksActionButton(icon: "bubble.right.fill", count: flick?.comments ?? 0)
                    FlicksActionButton(icon: "arrowshape.turn.up.right.fill", count: flick?.shares ?? 0)
                }
            }
            .padding()
        }
    }
}

struct FlicksActionButton: View {
    let icon: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text("\(count.abbreviated)")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Flicks View Model

@MainActor
class FlicksViewModel: ObservableObject {
    @Published var flicks: [Flick] = []
    @Published var isLoading = false
    
    private var lastDocument: Any?
    private let pageSize = 20
    
    func loadInitialFlicks() {
        Task {
            isLoading = true
            // Load from Firestore or API
            // For now, use sample data
            flicks = Flick.sampleFlicks
            isLoading = false
        }
    }
    
    func loadMoreFlicks() async {
        guard !isLoading else { return }
        isLoading = true
        
        // Simulate loading more
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Append more flicks
        flicks.append(contentsOf: Flick.sampleFlicks)
        
        isLoading = false
    }
    
    func trackView(flick: Flick) {
        // Track view analytics
        print("📊 [Analytics] Flick viewed: \(flick.id)")
    }
}

// MARK: - Models

struct Flick: Identifiable {
    let id: String
    let videoURL: URL?
    let thumbnailURL: URL?
    let creator: Creator
    let caption: String
    let likes: Int
    let comments: Int
    let shares: Int
    
    struct Creator {
        let username: String
        let avatarURL: URL?
    }
    
    static let sampleFlicks: [Flick] = []
}

// MARK: - Extensions

extension Int {
    var abbreviated: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}
