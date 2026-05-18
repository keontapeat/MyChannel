//
//  MinimalHeroSection.swift
//  MyChannel
//
//  Extracted from HomeView.swift for better code organization
//

import SwiftUI
import AVFoundation
import AVKit
import UIKit

// MARK: - Minimal Hero Section (Pager)
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    @Binding var selectedIndex: Int
    let showLiveHeroPreviewInPreviews: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @State private var showingFeaturedManager = false
    
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    private var isAdmin: Bool {
        guard let email = appState.currentUser?.email else { return false }
        return email.lowercased() == "keontapeat@mychannel.live" || 
               email.lowercased() == "keontapeat@gmail.com"
    }

    var body: some View {
        // Only show section if there are featured videos OR user is admin (to add videos)
        if !featuredContent.isEmpty || isAdmin {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("FEATURED")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .tracking(1)
                    
                    Spacer()
                    
                    // Quick Edit Button (Admin Only)
                    if isAdmin {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            showingFeaturedManager = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Edit")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingFeaturedManager) {
                    ThermonuclearFeaturedManager()
                        .environmentObject(appState)
                        .background(
                            UIKitSheetConfigurator(
                                configuration: UIKitSheetConfiguration(
                                    detents: [.large()],
                                    largestUndimmedDetentIdentifier: .large,
                                    prefersGrabberVisible: true,
                                    prefersScrollingExpandsWhenScrolledToEdge: false,
                                    preferredCornerRadius: 28
                                )
                            )
                        )
                }

                // Display: Only show carousel if there are actually featured videos
                if featuredContent.isEmpty {
                    // Empty state for admin
                    if isAdmin {
                        emptyStateView
                    }
                } else {
                    // Show actual featured videos
                    featuredCarouselView
                }
            }
        }
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("No Featured Videos")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Pin up to 3 videos to feature on Home")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            showingFeaturedManager = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Add First Video")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Featured Carousel View
    @ViewBuilder
    private var featuredCarouselView: some View {
        FeaturedUIKitCarousel(
            videos: featuredContent,
            selectedIndex: $selectedIndex,
            isCompact: isCompact,
            allowLiveInPreview: showLiveHeroPreviewInPreviews,
            onPlayVideo: onPlayVideo,
            onAddToList: onAddToList
        )
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FeaturedUIKitCarousel: UIViewRepresentable {
    let videos: [Video]
    @Binding var selectedIndex: Int
    let isCompact: Bool
    let allowLiveInPreview: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.reuseID)
        return collectionView
    }
    
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        collectionView.reloadData()
        let clampedIndex = min(max(selectedIndex, 0), max(videos.count - 1, 0))
        if videos.indices.contains(clampedIndex), collectionView.numberOfItems(inSection: 0) > clampedIndex {
            collectionView.scrollToItem(at: IndexPath(item: clampedIndex, section: 0), at: .centeredHorizontally, animated: false)
        }
    }
    
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
        static let reuseID = "FeaturedUIKitCarouselCell"
        var parent: FeaturedUIKitCarousel
        
        init(parent: FeaturedUIKitCarousel) {
            self.parent = parent
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.videos.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseID, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                let video = parent.videos[indexPath.item]
                FeaturedHeroCard(
                    video: video,
                    isCompact: parent.isCompact,
                    isActive: indexPath.item == parent.selectedIndex,
                    allowLiveInPreview: parent.allowLiveInPreview,
                    onPlay: { self.parent.onPlayVideo(video) },
                    onAddToList: { self.parent.onAddToList(video) }
                )
                .padding(.horizontal, 20)
            }
            .margins(.all, 0)
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            collectionView.bounds.size
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateSelectedIndex(from: scrollView)
        }
        
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateSelectedIndex(from: scrollView)
        }
        
        private func updateSelectedIndex(from scrollView: UIScrollView) {
            guard scrollView.bounds.width > 0 else { return }
            let index = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
            if parent.videos.indices.contains(index), parent.selectedIndex != index {
                parent.selectedIndex = index
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

// MARK: - Featured Hero Card
struct FeaturedHeroCard: View {
    let video: Video
    let isCompact: Bool
    let isActive: Bool
    let allowLiveInPreview: Bool
    let onPlay: () -> Void
    let onAddToList: () -> Void

    @State private var isPressed = false
    @State private var isBuffering = false
    @EnvironmentObject private var appState: AppState

    /// Whether this video URL can be played directly by AVPlayer (Firebase Storage, local files, direct MP4s).
    /// YouTube/web URLs cannot — they need the WebView-based VideoLiveThumbnailView instead.
    private var isDirectPlayable: Bool {
        let url = video.videoURL.lowercased()
        guard !url.isEmpty else { return false }
        // Firebase Storage, local file://, or direct .mp4/.m3u8 links
        return url.contains("firebasestorage.googleapis.com")
            || url.hasPrefix("file://")
            || url.hasSuffix(".mp4")
            || url.hasSuffix(".mov")
            || url.hasSuffix(".m3u8")
            || url.contains("alt=media") // Firebase Storage token URLs
    }

    /// Whether this video should use the YouTube/web-based live thumbnail preview
    private var isYouTubeContent: Bool {
        video.contentSource == .youtube || video.isLiveStream
    }

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        ZStack {
            // MARK: Media Layer
            ZStack {
                // 1) Static poster (always rendered as base layer)
                posterImage

                // 2) Video preview — only on the ACTIVE card, pick the right player
                if isActive && !isPreview {
                    if isDirectPlayable {
                        // Firebase Storage / local file → native AVPlayer loop
                        MutedLoopVideoPlayer(videoURL: video.videoURL, isActive: isActive)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    } else if isYouTubeContent && (!isPreview || allowLiveInPreview) {
                        // YouTube / live → web-based thumbnail preview
                        VideoLiveThumbnailView(video: video, cornerRadius: 16)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )

            // Overlayed content
            VStack(spacing: 12) {
                topBadges
                Spacer()
                bottomContent
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    // MARK: - Poster Image
    @ViewBuilder
    private var posterImage: some View {
        if video.id == "shot_by_keonta_intro" || video.id == FeaturedStore.ownerIntroVideoId {
            Image("ShotByKeontaThumbnail")
                .resizable()
                .scaledToFill()
        } else if video.thumbnailURL.hasPrefix("asset://"),
                  let assetName = video.thumbnailURL.split(separator: "/").last.map(String.init),
                  !assetName.isEmpty {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image
                        .resizable()
                        .scaledToFill()
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            )
        }
    }
    
    // MARK: - Top Badges
    @ViewBuilder
    private var topBadges: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: video.category.iconName)
                Text(video.category.displayName)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.35)))

            Spacer()

            Text(video.formattedDuration)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
    
    // MARK: - Bottom Content
    @ViewBuilder
    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(video.creator.displayName, systemImage: "person.crop.circle.fill")
                    .lineLimit(1)
                Text("·")
                Label(video.formattedViewCount, systemImage: "eye.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onPlay()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Play")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onAddToList()
                }) {
                    let saved = appState.isVideoInWatchLater(video.id)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        Image(systemName: saved ? "checkmark" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(saved ? AppTheme.Colors.primary : .black)
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch later")
                .accessibilityHint("Add or remove from your Watch Later")
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

// MARK: - Asset cache so Firebase Storage video is only downloaded once
final class LoopAssetCache {
    static let shared = LoopAssetCache()
    private var cache: [String: AVURLAsset] = [:]
    private var warmTasks: [String: Task<Void, Never>] = [:]
    private init() {}

    func asset(for urlString: String) -> AVURLAsset {
        if let cached = cache[urlString] { return cached }
        let url = URL(string: urlString) ?? URL(fileURLWithPath: urlString)
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        cache[urlString] = asset
        // Warm in background — load tracks + isPlayable so first frame is instant
        warmTasks[urlString] = Task.detached(priority: .utility) { [weak asset] in
            guard let asset else { return }
            _ = try? await asset.load(.tracks, .isPlayable)
        }
        return asset
    }
}

// MARK: - Muted Looping Inline Video Player (with pause/resume logic)
struct MutedLoopVideoPlayer: UIViewRepresentable {
    let videoURL: String
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        // URL changed → reconfigure
        if uiView.currentURL != videoURL {
            configure(view: uiView, coordinator: context.coordinator)
        }

        // Pause/resume based on active state
        if isActive {
            if uiView.player?.rate == 0 {
                uiView.player?.play()
            }
        } else {
            uiView.player?.pause()
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        // Clean up when view is removed
        uiView.player?.pause()
        uiView.player = nil
        uiView.playerLayer?.removeFromSuperlayer()
        coordinator.loopObserver = nil
        coordinator.bgObserver = nil
        coordinator.fgObserver = nil
        coordinator.pauseObserver = nil
        coordinator.resumeObserver = nil
    }

    private func configure(view: PlayerContainerView, coordinator: Coordinator) {
        // Tear down previous player
        view.player?.pause()
        view.playerLayer?.removeFromSuperlayer()
        view.player = nil
        view.playerLayer = nil
        view.currentURL = videoURL
        coordinator.loopObserver = nil
        coordinator.bgObserver = nil
        coordinator.fgObserver = nil
        coordinator.pauseObserver = nil
        coordinator.resumeObserver = nil

        guard !videoURL.isEmpty else { return }

        // Reuse cached asset — no re-download on repeat appearances
        let asset = LoopAssetCache.shared.asset(for: videoURL)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8.0

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        view.player = player
        view.playerLayer = layer

        // Loop at end
        coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // Pause on app background
        coordinator.bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak player] _ in
            player?.pause()
        }

        // Resume on app foreground (only if this card is active)
        coordinator.fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak player] _ in
            // Will be resumed by updateUIView when isActive == true
            _ = player
        }

        // Pause/resume for fullscreen covers
        coordinator.pauseObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LivePreviewsShouldPause"),
            object: nil,
            queue: .main
        ) { [weak player] _ in
            player?.pause()
        }
        coordinator.resumeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LivePreviewsShouldResume"),
            object: nil,
            queue: .main
        ) { [weak player] _ in
            // Will be resumed by updateUIView when isActive == true
            _ = player
        }

        if isActive {
            player.play()
        }
    }

    class Coordinator {
        var loopObserver: NSObjectProtocol?
        var bgObserver: NSObjectProtocol?
        var fgObserver: NSObjectProtocol?
        var pauseObserver: NSObjectProtocol?
        var resumeObserver: NSObjectProtocol?

        deinit {
            [loopObserver, bgObserver, fgObserver, pauseObserver, resumeObserver].compactMap { $0 }.forEach {
                NotificationCenter.default.removeObserver($0)
            }
        }
    }
}

final class PlayerContainerView: UIView {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var currentURL: String?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

#Preview {
    MinimalHeroSection(
        featuredContent: Video.sampleVideos,
        selectedIndex: .constant(0),
        showLiveHeroPreviewInPreviews: false,
        onPlayVideo: { _ in },
        onAddToList: { _ in }
    )
    .environmentObject(AppState())
}

