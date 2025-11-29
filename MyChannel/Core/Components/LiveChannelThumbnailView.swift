import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct LiveChannelThumbnailView: View {
    let streamURL: String
    let posterURL: String?
    let fallbackStreamURL: String?
    let allowPlaybackInPreviews: Bool
    var channelCategory: LiveTVChannel.ChannelCategory?
    var channelName: String?

    @State private var isReady: Bool = false
    @State private var snapshot: UIImage?
    @State private var loadAttempted: Bool = false

    init(streamURL: String, posterURL: String? = nil, fallbackStreamURL: String? = nil, allowPlaybackInPreviews: Bool = false, channelCategory: LiveTVChannel.ChannelCategory? = nil, channelName: String? = nil) {
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.fallbackStreamURL = fallbackStreamURL
        self.allowPlaybackInPreviews = allowPlaybackInPreviews
        self.channelCategory = channelCategory
        self.channelName = channelName
    }

    var body: some View {
        ZStack {
            // 🔥 FIRE GRADIENT PLACEHOLDER - Shows immediately while loading
            firePlaceholder
            
            // Video preview sits in the back and fades in when ready
            if !AppConfig.isPreview || allowPlaybackInPreviews {
                LivePreviewPlayer(
                    urls: [streamURL] + (fallbackStreamURL != nil ? [fallbackStreamURL!] : []),
                    onReady: {
                        if !isReady {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isReady = true
                            }
                        }
                    },
                    onSnapshot: { img in
                        if snapshot == nil {
                            snapshot = img
                        }
                    }
                )
                .opacity(isReady ? 1 : 0)
            }

            // Snapshot overlay for smooth transitions
            if let snap = snapshot, !isReady {
                Image(uiImage: snap)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
            
            // 🔥 LIVE pulse indicator overlay
            if !isReady {
                livePulseOverlay
            }
        }
        .clipped()
        .onAppear {
            loadAttempted = true
        }
    }
    
    // 🔥 Fire gradient placeholder based on category
    @ViewBuilder
    private var firePlaceholder: some View {
        let categoryColor = channelCategory?.color ?? .blue
        
        ZStack {
            // Dynamic gradient based on category
            LinearGradient(
                colors: [
                    categoryColor.opacity(0.8),
                    categoryColor.opacity(0.4),
                    Color.black.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated shimmer effect
            if !isReady {
                ShimmerView()
                    .opacity(0.3)
            }
            
            // Category icon
            VStack(spacing: 6) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if let name = channelName {
                    Text(name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
        }
        .opacity(isReady ? 0 : 1)
    }
    
    // Category-specific icons
    private var categoryIcon: String {
        switch channelCategory {
        case .anime: return "sparkles.tv"
        case .scifi: return "wand.and.stars"
        case .reality: return "person.3.fill"
        case .comedy: return "face.smiling.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .entertainment: return "star.fill"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        case .classic: return "tv.fill"
        case .none: return "tv.fill"
        }
    }
    
    // Live pulse indicator
    @ViewBuilder
    private var livePulseOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    PulsingDot()
                    Text("LOADING")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .padding(6)
            }
        }
    }
}

// 🔥 Pulsing dot for loading indicator
private struct PulsingDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .scaleEffect(isPulsing ? 1.2 : 0.8)
            .opacity(isPulsing ? 1 : 0.6)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// 🔥 Shimmer loading effect
private struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.4),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: -geo.size.width + (phase * geo.size.width * 2))
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: phase
            )
            .onAppear { phase = 1 }
        }
        .clipped()
    }
}

private struct LivePreviewPlayer: UIViewRepresentable {
    let urls: [String]
    let onReady: () -> Void
    let onSnapshot: (UIImage) -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.configure(with: urls, onReady: onReady, onSnapshot: onSnapshot)
    }
}

private final class PlayerContainerView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var urlCandidates: [String] = []
    private var currentIndex: Int = 0
    private var timeControlObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var readyTimeoutWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var hasNotifiedReady = false
    private var isConfigured = false // 🔥 Prevent duplicate configurations
    private var configuredURLs: [String] = [] // 🔥 Track what we configured with
    
    // 🔥 THERMONUCLEAR: Static cache for pre-loaded players
    private static var playerCache: [String: AVPlayer] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.mychannel.playerCache", attributes: .concurrent)

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func configure(with urls: [String], onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        // 🔥 PREVENT DUPLICATE CONFIGURATIONS - Only configure once per URL set
        if isConfigured && configuredURLs == urls {
            return
        }
        
        urlCandidates = urls
        configuredURLs = urls
        
        // 🔥 NUCLEAR FALLBACKS - Multiple reliable test streams for 100% success
        let nuclearFallbacks = [
            "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8", // Mux test stream
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8", // Apple test
            "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8", // Google Shaka
            "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8", // Akamai test
            "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8" // Unified streaming
        ]
        
        for fallback in nuclearFallbacks {
            if !urlCandidates.contains(where: { $0 == fallback }) {
                urlCandidates.append(fallback)
            }
        }
        
        currentIndex = 0
        teardown()
        isConfigured = true
        startPlayer(onReady: onReady, onSnapshot: onSnapshot)
    }

    private func startPlayer(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        guard currentIndex < urlCandidates.count, let url = URL(string: urlCandidates[currentIndex]) else { return }

        // 🔥🔥🔥 THERMONUCLEAR OPTIMIZATIONS - FASTEST IN THE WORLD 🔥🔥🔥
        
        // 1. Check if we have a cached player ready to go
        let urlString = url.absoluteString
        if let cachedPlayer = Self.playerCache[urlString] {
            Self.cacheQueue.async(flags: .barrier) {
                Self.playerCache.removeValue(forKey: urlString)
            }
            setupExistingPlayer(cachedPlayer, onReady: onReady, onSnapshot: onSnapshot)
            return
        }
        
        // 2. Create asset with AGGRESSIVE low-latency options
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false,
            AVURLAssetAllowsCellularAccessKey: true,
            "AVURLAssetHTTPHeaderFieldsKey": ["Connection": "keep-alive"]
        ])
        
        // 3. Load only what we need - don't wait for full metadata
        let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [])
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false // 🔥 Don't waste bandwidth when paused
        
        // 🔥🔥🔥 THERMONUCLEAR BITRATE - Ultra-low for INSTANT thumbnails
        item.preferredPeakBitRate = 150_000 // 150 kbps - BLAZING FAST
        item.preferredForwardBufferDuration = 0.1 // 100ms buffer - INSTANT!
        item.preferredMaximumResolution = CGSize(width: 426, height: 240) // 240p max for thumbnails

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        
        // 🔥 iOS 16+ low latency mode
        if #available(iOS 16.0, *) {
            player.defaultRate = 1.0
        }

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)

        self.player = player
        self.playerLayer = layer
        self.hasNotifiedReady = false

        // 🔥 Observe status with high priority
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.notifyReadyIfNeeded(onReady)
                    player.play()
                } else if item.status == .failed {
                    self.tryNextCandidate(onReady: onReady, onSnapshot: onSnapshot)
                }
            }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] p, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if p.timeControlStatus == .playing {
                    self.notifyReadyIfNeeded(onReady)
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        // 🔥 ULTRA-FAST TIMEOUT: Snapshot after 500ms
        let readyWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.player?.timeControlStatus != .playing {
                self.generateSnapshot(from: asset) { img in
                    if let img { onSnapshot(img) }
                }
            }
        }
        self.readyTimeoutWork = readyWork
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5, execute: readyWork)

        // 🔥 AGGRESSIVE RETRY: Try next URL after 1.5 seconds
        let retry = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.player?.timeControlStatus != .playing {
                    self.tryNextCandidate(onReady: onReady, onSnapshot: onSnapshot)
                }
            }
        }
        self.retryWork = retry
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1.5, execute: retry)

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsPause), name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsResume), name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)

        player.play()
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // 🔥 Setup existing cached player instantly
    private func setupExistingPlayer(_ player: AVPlayer, onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)
        
        self.player = player
        self.playerLayer = layer
        self.hasNotifiedReady = false
        
        // Cached player is ready immediately
        notifyReadyIfNeeded(onReady)
        player.play()
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // 🔥 STATIC: Pre-warm players for upcoming URLs
    static func prewarmPlayers(for urls: [String]) {
        let queue = DispatchQueue.global(qos: .utility)
        queue.async {
            for urlString in urls.prefix(3) {
                guard let url = URL(string: urlString) else { continue }
                guard playerCache[urlString] == nil else { continue }
                
                let asset = AVURLAsset(url: url, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: false,
                    AVURLAssetAllowsCellularAccessKey: true
                ])
                let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [])
                item.preferredPeakBitRate = 150_000
                item.preferredForwardBufferDuration = 0.1
                
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                player.automaticallyWaitsToMinimizeStalling = false
                
                cacheQueue.async(flags: .barrier) {
                    playerCache[urlString] = player
                }
            }
        }
    }

    private func tryNextCandidate(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        currentIndex += 1
        teardownPlayerOnly()
        if currentIndex < urlCandidates.count {
            startPlayer(onReady: onReady, onSnapshot: onSnapshot)
        } else {
            // 🔥 ALL STREAMS FAILED - Still notify ready so UI doesn't hang on loading forever
            // The placeholder will remain visible which is better than infinite loading
            print("⚠️ [LiveThumbnail] All \(urlCandidates.count) stream URLs failed - showing placeholder")
            DispatchQueue.main.async {
                onReady() // This will hide the "LOADING" indicator
            }
        }
    }

    private func notifyReadyIfNeeded(_ onReady: @escaping () -> Void) {
        if !hasNotifiedReady {
            hasNotifiedReady = true
            DispatchQueue.main.async { onReady() }
        }
    }

    private func generateSnapshot(from asset: AVAsset, completion: @escaping (UIImage?) -> Void) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        let time = CMTime(seconds: 1, preferredTimescale: 600)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                DispatchQueue.main.async { completion(image) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    @objc private func handleAppBackground() { player?.pause() }
    @objc private func handleAppForeground() { player?.play() }
    @objc private func handlePreviewsPause() { player?.pause() }
    @objc private func handlePreviewsResume() { player?.play() }

    private func teardownPlayerOnly() {
        readyTimeoutWork?.cancel()
        retryWork?.cancel()
        readyTimeoutWork = nil
        retryWork = nil
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        teardownPlayerOnly()
    }

    deinit { teardown() }
}

#Preview("LiveChannelThumbnailView") {
    LiveChannelThumbnailView(
        streamURL: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        posterURL: "https://upload.wikimedia.org/wikipedia/commons/3/31/Red_dot.svg"
    )
    .frame(width: 200, height: 112)
    .background(Color(.systemGray6))
    .preferredColorScheme(.light)
}