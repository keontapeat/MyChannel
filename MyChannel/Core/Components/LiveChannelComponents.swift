// ⚡ PERFORMANCE: Extracted from LiveChannelThumbnailView.swift — independent compilation unit.
// Player, image, shimmer, and YouTube thumbnail cache compile in parallel.
import SwiftUI
import AVFoundation
import AVKit

// MARK: - 🔥 THERMONUCLEAR PLAYER
struct ThermonuclearPlayer: UIViewRepresentable {
    let urls: [String]
    let initialPlaybackFraction: Double?
    let onReady: () -> Void
    let onSnapshot: (UIImage) -> Void
    var onAllFailed: (() -> Void)?

    func makeUIView(context: Context) -> ThermonuclearPlayerView {
        let view = ThermonuclearPlayerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ThermonuclearPlayerView, context: Context) {
        uiView.configure(urls: urls, initialPlaybackFraction: initialPlaybackFraction, onReady: onReady, onSnapshot: onSnapshot, onAllFailed: onAllFailed)
    }
    
    static func dismantleUIView(_ uiView: ThermonuclearPlayerView, coordinator: ()) {
        uiView.teardown()
    }
}

// MARK: - 🔥 THERMONUCLEAR PLAYER VIEW
final class ThermonuclearPlayerView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var urlCandidates: [String] = []
    private var initialPlaybackFraction: Double?
    private var currentIndex: Int = 0
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var retryWorkItem: DispatchWorkItem?
    private var snapshotWorkItem: DispatchWorkItem?
    private var hasNotifiedReady = false
    private var hasNotifiedAllFailed = false
    private var isConfigured = false
    private var configuredURLs: [String] = []
    private var onAllFailedCallback: (() -> Void)?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    func configure(urls: [String], initialPlaybackFraction: Double?, onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void, onAllFailed: (() -> Void)? = nil) {
        // 🔥 Prevent duplicate configurations
        guard !isConfigured || configuredURLs != urls || self.initialPlaybackFraction != initialPlaybackFraction else { return }
        
        urlCandidates = urls
        configuredURLs = urls
        self.initialPlaybackFraction = initialPlaybackFraction
        currentIndex = 0
        isConfigured = true
        hasNotifiedAllFailed = false
        onAllFailedCallback = onAllFailed
        
        teardownPlayerOnly()
        startPlayer(onReady: onReady, onSnapshot: onSnapshot)
    }
    
    private func startPlayer(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        guard currentIndex < urlCandidates.count else {
            // 🔥 All URLs failed - notify caller so they can hide the channel
            if !hasNotifiedAllFailed {
                hasNotifiedAllFailed = true
                Task { @MainActor [weak self] in
                    self?.onAllFailedCallback?()
                }
            }
            return
        }
        
        let urlString = urlCandidates[currentIndex]
        guard let url = URL(string: urlString) else {
            tryNextURL(onReady: onReady, onSnapshot: onSnapshot)
            return
        }
        
        // 🔥 Check cache first
        let cache = ThermonuclearThumbnailCache.shared
        
        // Try cached player
        if let cachedPlayer = cache.getCachedPlayer(for: urlString) {
            cache.removeCachedPlayer(for: urlString)
            setupPlayer(cachedPlayer, onReady: onReady)
            return
        }
        
        // 🔥 Create THERMONUCLEAR optimized player
        let asset: AVURLAsset
        if let cachedAsset = cache.getCachedAsset(for: urlString) {
            asset = cachedAsset
        } else {
            // 🔥 Add proper headers for Pluto TV and other streaming services
            asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false,
                AVURLAssetAllowsCellularAccessKey: true,
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                    "Accept": "*/*",
                    "Accept-Language": "en-US,en;q=0.9",
                    "Connection": "keep-alive",
                    "Accept-Encoding": "gzip, deflate, br",
                    "Origin": "https://pluto.tv",
                    "Referer": "https://pluto.tv/"
                ]
            ])
            cache.cacheAsset(asset, for: urlString)
        }
        
        let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [])
        
        // 🔥🔥🔥 THERMONUCLEAR SETTINGS - ABSOLUTE MINIMUM LATENCY 🔥🔥🔥
        item.preferredPeakBitRate = 50_000 // 🔥 50kbps - BLAZING INSTANT!
        item.preferredForwardBufferDuration = 0.02 // 🔥 20ms buffer - NUCLEAR!
        item.preferredMaximumResolution = CGSize(width: 256, height: 144) // 🔥 144p - SPEED!
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        
        if #available(iOS 16.0, *) {
            player.defaultRate = 1.0
        }
        
        setupPlayer(player, onReady: onReady)
        
        // 🔥 Status observer
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.applyInitialPlaybackFractionIfNeeded()
                    self.notifyReady(onReady)
                    self.player?.play()
                case .failed:
                    self.tryNextURL(onReady: onReady, onSnapshot: onSnapshot)
                default:
                    break
                }
            }
        }
        
        // 🔥 Time control observer
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                if p.timeControlStatus == .playing {
                    self?.notifyReady(onReady)
                    self?.generateSnapshotIfNeeded(from: asset, onSnapshot: onSnapshot)
                }
            }
        }
        
        // 🔥 Loop observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        // 🔥 BLAZING FAST RETRY - 600ms timeout!
        let retry = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.player?.timeControlStatus != .playing else { return }
                self.tryNextURL(onReady: onReady, onSnapshot: onSnapshot)
            }
        }
        retryWorkItem = retry
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.6, execute: retry) // 🔥 600ms!
        
        // 🔥 Snapshot timeout - generate even if not playing
        let snapshot = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.generateSnapshotIfNeeded(from: asset, onSnapshot: onSnapshot)
        }
        snapshotWorkItem = snapshot
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: snapshot)
        
        player.play()
    }
    
    private func setupPlayer(_ player: AVPlayer, onReady: @escaping () -> Void) {
        self.player = player
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)
        self.playerLayer = layer
        
        hasNotifiedReady = false
        setNeedsLayout()
        layoutIfNeeded()
        
        // 🔥 Background/foreground handling
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(play), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(play), name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
    }
    
    private func notifyReady(_ onReady: @escaping () -> Void) {
        guard !hasNotifiedReady else { return }
        hasNotifiedReady = true
        retryWorkItem?.cancel()
        Task { @MainActor in onReady() }
    }

    private func applyInitialPlaybackFractionIfNeeded() {
        guard let fraction = initialPlaybackFraction,
              fraction > 0,
              let item = player?.currentItem,
              let timeRange = item.seekableTimeRanges.last?.timeRangeValue else {
            return
        }

        let start = CMTimeGetSeconds(timeRange.start)
        let duration = CMTimeGetSeconds(timeRange.duration)
        guard duration > 0 else { return }

        let target = start + duration * max(0, min(1, fraction))
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600))
        initialPlaybackFraction = nil
    }
    
    private func tryNextURL(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        currentIndex += 1
        teardownPlayerOnly()
        startPlayer(onReady: onReady, onSnapshot: onSnapshot)
    }
    
    private var hasGeneratedSnapshot = false
    
    private func generateSnapshotIfNeeded(from asset: AVAsset, onSnapshot: @escaping (UIImage) -> Void) {
        guard !hasGeneratedSnapshot else { return }
        hasGeneratedSnapshot = true
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 270) // 270p snapshot
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                Task { @MainActor in onSnapshot(image) }
            } catch {
                // Silent fail - video will show instead
            }
        }
    }
    
    @objc private func pause() { player?.pause() }
    @objc private func play() { player?.play() }
    
    private func teardownPlayerOnly() {
        retryWorkItem?.cancel()
        snapshotWorkItem?.cancel()
        retryWorkItem = nil
        snapshotWorkItem = nil
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        initialPlaybackFraction = nil
        hasGeneratedSnapshot = false
    }
    
    func teardown() {
        NotificationCenter.default.removeObserver(self)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        teardownPlayerOnly()
    }
    
    deinit { teardown() }
}

// MARK: - 🔥 BULLETPROOF ASYNC IMAGE (Never shows broken icon)
private struct BulletproofAsyncImage: View {
    let url: String
    let onLoaded: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Show absolutely nothing when loading/failed - gradient is behind
                Color.clear
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageURL = URL(string: url) else {
            isLoading = false
            return
        }
        
        // 🔥 Skip cache for YouTube thumbnails to ensure fresh images
        let shouldSkipCache = url.contains("ytimg.com")
        
        // Check cache first (skip for YouTube to avoid stale "unavailable" thumbnails)
        if !shouldSkipCache,
           let cached = URLCache.shared.cachedResponse(for: URLRequest(url: imageURL)),
           let uiImage = UIImage(data: cached.data) {
            self.image = uiImage
            self.isLoading = false
            onLoaded()
            return
        }
        
        // Load from network
        Task {
            do {
                var request = URLRequest(url: imageURL)
                request.cachePolicy = shouldSkipCache ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
                
                let (data, response) = try await URLSession.configured.data(for: request)
                
                // 🔥 Validate image isn't too small (YouTube "unavailable" placeholder is often tiny)
                guard let uiImage = UIImage(data: data) else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // 🔥 Reject suspiciously small images (likely error placeholders)
                let minSize: CGFloat = 100
                guard uiImage.size.width >= minSize && uiImage.size.height >= minSize else {
                    print("🔥 [BulletproofImage] Rejecting small image: \(uiImage.size) for \(url)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Cache the response (only if valid)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !shouldSkipCache {
                    let cachedResponse = CachedURLResponse(response: response, data: data)
                    URLCache.shared.storeCachedResponse(cachedResponse, for: URLRequest(url: imageURL))
                }
                
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                    onLoaded()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // 🔥 Clear all cached YouTube thumbnails
    static func clearYouTubeThumbnailCache() {
        URLCache.shared.removeAllCachedResponses()
        print("🔥 [BulletproofImage] Cleared all URL cache")
    }
}

// MARK: - 🔥 THERMONUCLEAR SHIMMER
struct ThermonuclearShimmer: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.5),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: -geo.size.width + (phase * geo.size.width * 2))
        }
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - 🔥🔥🔥 THERMONUCLEAR YOUTUBE THUMBNAIL CACHE 🔥🔥🔥
/// Ultra-fast in-memory cache for validated YouTube thumbnails
@MainActor
final class ThermonuclearYouTubeThumbnailCache {
    static let shared = ThermonuclearYouTubeThumbnailCache()
    
    // 🔥 LRU cache with 200 thumbnail limit
    private var imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        return cache
    }()
    
    // 🔥 Track known-bad URLs (error thumbnails) - never retry these
    private var badURLs: Set<String> = []
    
    // 🔥 In-flight requests to prevent duplicate network calls
    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]
    
    // 🔥 Shared URLSession for maximum connection reuse
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 10 // 🔥 More parallel connections
        config.urlCache = nil // No disk cache overhead
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func getCached(_ url: String) -> UIImage? {
        imageCache.object(forKey: url as NSString)
    }
    
    func cache(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: url as NSString, cost: cost)
    }
    
    func isBadURL(_ url: String) -> Bool {
        badURLs.contains(url)
    }
    
    func markBadURL(_ url: String) {
        badURLs.insert(url)
    }
    
    // 🔥🔥🔥 THERMONUCLEAR PREWARM - Load thumbnails in parallel! 🔥🔥🔥
    func prewarmThumbnails(_ urls: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(20) { // Prewarm up to 20 at once
                    group.addTask {
                        _ = await self.getOrLoad(url)
                    }
                }
            }
            print("🔥🔥🔥 [ThermonuclearThumbnails] Prewarmed \(min(urls.count, 20)) thumbnails!")
        }
    }
    
    func getOrLoad(_ url: String) async -> UIImage? {
        // 🔥 Check cache first - instant return
        if let cached = getCached(url) {
            return cached
        }
        
        // 🔥 Check if known bad URL
        if isBadURL(url) {
            return nil
        }
        
        // 🔥 Check if already loading - wait for existing request
        if let existing = inFlightRequests[url] {
            return await existing.value
        }
        
        // 🔥 Start new request
        let task = Task<UIImage?, Never> {
            await loadAndValidate(url)
        }
        inFlightRequests[url] = task
        
        let result = await task.value
        inFlightRequests.removeValue(forKey: url)
        
        return result
    }
    
    private func loadAndValidate(_ url: String) async -> UIImage? {
        guard let imageURL = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: imageURL)
            
            // 🔥 Parse image AND validate on background thread in one shot
            let result = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let uiImage = UIImage(data: data) else { return nil }
                
                // 🔥 ULTRA-FAST yellow detection
                if Self.isYouTubeErrorThumbnailFast(uiImage) {
                    return nil
                }
                
                return uiImage
            }.value
            
            if let validImage = result {
                cache(validImage, for: url)
                return validImage
            } else {
                markBadURL(url)
                return nil
            }
            
        } catch {
            markBadURL(url)
            return nil
        }
    }
    
    /// 🔥🔥🔥 ULTRA-FAST YouTube error detection - samples only 4 pixels! 🔥🔥🔥
    nonisolated private static func isYouTubeErrorThumbnailFast(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let isLittleEndian = cgImage.bitmapInfo.contains(.byteOrder32Little)
        
        // 🔥 Sample only 4 strategic pixels - corners of center region
        let points = [
            (width / 4, height / 4),
            (3 * width / 4, height / 4),
            (width / 4, 3 * height / 4),
            (3 * width / 4, 3 * height / 4)
        ]
        
        var yellowCount = 0
        
        for (x, y) in points {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = isLittleEndian ? bytes[offset + 2] : bytes[offset]
            let g = isLittleEndian ? bytes[offset + 1] : bytes[offset + 1]
            let b = isLittleEndian ? bytes[offset] : bytes[offset + 2]
            
            // Yellow: high R (>200), high G (>150), low B (<100)
            if r > 200 && g > 150 && b < 100 {
                yellowCount += 1
            }
        }
        
        // 2+ yellow pixels = error thumbnail (was 3; use 2 so we catch when red circle covers one corner)
        return yellowCount >= 2
    }
    
    /// Public check so views can reject error thumbnails before displaying (e.g. Live TV cards)
    nonisolated static func isErrorThumbnail(_ image: UIImage) -> Bool {
        isYouTubeErrorThumbnailFast(image)
    }
}

// MARK: - 🔥🔥🔥 THERMONUCLEAR SMART YOUTUBE THUMBNAIL VIEW 🔥🔥🔥
/// Blazing fast YouTube thumbnail with error detection and caching
struct SmartYouTubeThumbnailView<Placeholder: View>: View {
    let url: String
    let placeholder: () -> Placeholder
    let onLoaded: () -> Void
    
    @State private var loadedImage: UIImage?
    @State private var showPlaceholder = false
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if showPlaceholder {
                placeholder()
            } else {
                // 🔥 Show placeholder immediately while loading (no spinner = faster perceived load)
                placeholder()
                    .opacity(0.8)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        // 🔥 INSTANT: Check cache first
        if let cached = ThermonuclearYouTubeThumbnailCache.shared.getCached(url) {
            if !ThermonuclearYouTubeThumbnailCache.isErrorThumbnail(cached) {
                loadedImage = cached
                onLoaded()
            } else {
                ThermonuclearYouTubeThumbnailCache.shared.markBadURL(url)
                showPlaceholder = true
            }
            return
        }
        
        // 🔥 INSTANT: Check if known bad URL
        if ThermonuclearYouTubeThumbnailCache.shared.isBadURL(url) {
            showPlaceholder = true
            return
        }
        
        // 🔥 Load with deduplication; reject error thumbnails so we never show yellow/red
        if let image = await ThermonuclearYouTubeThumbnailCache.shared.getOrLoad(url) {
            if ThermonuclearYouTubeThumbnailCache.isErrorThumbnail(image) {
                ThermonuclearYouTubeThumbnailCache.shared.markBadURL(url)
                showPlaceholder = true
            } else {
                loadedImage = image
                onLoaded()
            }
        } else {
            showPlaceholder = true
        }
    }
}

// MARK: - 🔥 THERMONUCLEAR PULSING DOT
struct ThermonuclearPulsingDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 5, height: 5)
            .scaleEffect(isPulsing ? 1.3 : 0.7)
            .opacity(isPulsing ? 1 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - 🔥 THERMONUCLEAR PREWARM HELPER
enum ThermonuclearPrewarm {
    /// 🔥 Prewarm channels - only prewarm healthy ones!
    static func prewarmChannels(_ channels: [LiveTVChannel]) {
        Task {
            // Only prewarm healthy channels for SPEED
            let healthyIds = await StreamHealthMLAgent.shared.healthyChannelIds
            let healthyURLs = channels
                .filter { healthyIds.isEmpty || healthyIds.contains($0.id) }
                .prefix(6) // 🔥 Only top 6 for speed
                .map { $0.streamURL }
            ThermonuclearThumbnailCache.shared.prewarmStreams(Array(healthyURLs))
        }
    }
    
    static func prewarmURLs(_ urls: [String]) {
        // 🔥 Only prewarm first 6 for speed
        ThermonuclearThumbnailCache.shared.prewarmStreams(Array(urls.prefix(6)))
    }
}

// MARK: - Preview
#Preview("🔥 THERMONUCLEAR Thumbnail") {
    VStack(spacing: 16) {
        Text("🔥 THERMONUCLEAR THUMBNAILS 🔥")
            .font(.headline)
        
        HStack(spacing: 12) {
            LiveChannelThumbnailView(
                streamURL: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
                channelCategory: .anime,
                channelName: "Dragon Ball Z"
            )
            .frame(width: 160, height: 90)
            .cornerRadius(8)
            
            LiveChannelThumbnailView(
                streamURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
                channelCategory: .comedy,
                channelName: "Family Guy"
            )
            .frame(width: 160, height: 90)
            .cornerRadius(8)
        }
        
        HStack(spacing: 12) {
            LiveChannelThumbnailView(
                streamURL: "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8",
                channelCategory: .sports,
                channelName: "ESPN"
            )
            .frame(width: 160, height: 90)
            .cornerRadius(8)
            
            LiveChannelThumbnailView(
                streamURL: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
                channelCategory: .movies,
                channelName: "Action Movies"
            )
            .frame(width: 160, height: 90)
            .cornerRadius(8)
        }
    }
    .padding()
    .background(Color.black)
}
