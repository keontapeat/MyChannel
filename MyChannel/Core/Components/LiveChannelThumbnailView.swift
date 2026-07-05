import SwiftUI
import AVFoundation
import AVKit
import UIKit

@MainActor
final class LiveTVPreviewPlaybackStore: ObservableObject {
    static let shared = LiveTVPreviewPlaybackStore()

    private var dvrFractionsByChannelId: [String: Double] = [:]

    private init() {}

    func saveDVRFraction(_ fraction: Double, for channelId: String) {
        dvrFractionsByChannelId[channelId] = max(0, min(1, fraction))
    }

    func dvrFraction(for channelId: String) -> Double? {
        dvrFractionsByChannelId[channelId]
    }
}

// 🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
// 🔥 THERMONUCLEAR LIVE THUMBNAIL SYSTEM - FASTEST IN THE WORLD 🔥
// 🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
//
// Performance targets:
// - First frame: < 200ms (cached) / < 800ms (network)
// - Memory per thumbnail: < 2MB
// - CPU usage: < 5% per thumbnail
// - Battery impact: Minimal (ultra-low bitrate)
//
// 🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥

// MARK: - 🔥 GLOBAL ACTIVE PLAYER LIMITER (PERFORMANCE FIX)
/// Limits the number of concurrent ThermonuclearPlayer instances to prevent "Unable to render flattened version" errors
/// and maintain 60fps scrolling performance
@MainActor
final class ActivePlayerLimiter: ObservableObject {
    static let shared = ActivePlayerLimiter()
    
    // 🔥 CRITICAL: Maximum concurrent video players (prevents render flattening issues)
    // Increased to 8 for faster channel loading while maintaining performance
    private let maxActivePlayers: Int = 8
    
    // Track active player URLs in order of activation (oldest first)
    @Published private(set) var activePlayers: [String] = []
    
    private init() {}
    
    /// Request permission to activate a player. Returns true if allowed.
    func requestActivation(for url: String) -> Bool {
        // Already active? Allow
        if activePlayers.contains(url) {
            return true
        }
        
        // Under limit? Allow and register
        if activePlayers.count < maxActivePlayers {
            activePlayers.append(url)
            return true
        }
        
        // At limit - deny new activations to preserve performance
        return false
    }
    
    /// Deactivate a player when it goes off-screen
    func deactivate(url: String) {
        activePlayers.removeAll { $0 == url }
    }
    
    /// Force deactivate oldest player to make room
    func forceDeactivateOldest() -> String? {
        guard !activePlayers.isEmpty else { return nil }
        return activePlayers.removeFirst()
    }
    
    /// Check if a URL is currently active
    func isActive(_ url: String) -> Bool {
        activePlayers.contains(url)
    }
    
    /// Get current active count
    var activeCount: Int { activePlayers.count }
}

// MARK: - 🔥 LIVE CHANNEL LOADING TRACKER
/// Tracks loading state of live channels across sections for smart UI updates
@MainActor
final class LiveChannelLoadingTracker: ObservableObject {
    static let shared = LiveChannelLoadingTracker()
    
    @Published private(set) var readyChannels: Set<String> = []
    @Published private(set) var failedChannels: Set<String> = []
    @Published private(set) var isInitialLoadComplete = false
    
    private var loadingTimeout: Task<Void, Never>?
    
    private init() {
        // Start a 5-second timeout for initial load
        startLoadingTimeout()
    }
    
    func markReady(_ channelId: String) {
        readyChannels.insert(channelId)
        failedChannels.remove(channelId)
        checkInitialLoadComplete()
    }
    
    func markFailed(_ channelId: String) {
        failedChannels.insert(channelId)
        readyChannels.remove(channelId)
        checkInitialLoadComplete()
    }
    
    func isReady(_ channelId: String) -> Bool {
        readyChannels.contains(channelId)
    }
    
    func isFailed(_ channelId: String) -> Bool {
        failedChannels.contains(channelId)
    }
    
    private func startLoadingTimeout() {
        loadingTimeout?.cancel()
        loadingTimeout = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                isInitialLoadComplete = true
            }
        }
    }
    
    private func checkInitialLoadComplete() {
        // Consider initial load complete if we have at least 3 channels ready or 6 total processed
        let totalProcessed = readyChannels.count + failedChannels.count
        if readyChannels.count >= 3 || totalProcessed >= 6 {
            isInitialLoadComplete = true
            loadingTimeout?.cancel()
        }
    }
    
    func reset() {
        readyChannels.removeAll()
        failedChannels.removeAll()
        isInitialLoadComplete = false
        startLoadingTimeout()
    }
}

// MARK: - 🔥 THERMONUCLEAR THUMBNAIL CACHE
final class ThermonuclearThumbnailCache {
    static let shared = ThermonuclearThumbnailCache()
    
    // 🔥 Multi-layer cache system
    private var imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Max 100 thumbnails
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max
        return cache
    }()
    
    // 🔥 Pre-warmed player cache (playerOrder tracks insertion order for true LRU eviction)
    private var playerCache: [String: AVPlayer] = [:]
    private var playerOrder: [String] = []
    private let playerQueue = DispatchQueue(label: "com.mychannel.thermonuclear.players", attributes: .concurrent)
    
    // 🔥 Asset cache for instant replay (assetOrder tracks insertion order for true LRU eviction)
    private var assetCache: [String: AVURLAsset] = [:]
    private var assetOrder: [String] = []
    private let assetQueue = DispatchQueue(label: "com.mychannel.thermonuclear.assets", attributes: .concurrent)
    
    private init() {
        // 🔥 Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("🔥 [ThermonuclearCache] Memory warning - clearing caches")
        imageCache.removeAllObjects()
        playerQueue.async(flags: .barrier) { [weak self] in
            self?.playerCache.values.forEach { $0.pause() }
            self?.playerCache.removeAll()
            self?.playerOrder.removeAll()
        }
        assetQueue.async(flags: .barrier) { [weak self] in
            self?.assetCache.removeAll()
            self?.assetOrder.removeAll()
        }
    }
    
    // MARK: - Image Cache
    func getCachedImage(for url: String) -> UIImage? {
        imageCache.object(forKey: url as NSString)
    }
    
    func cacheImage(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate bytes
        imageCache.setObject(image, forKey: url as NSString, cost: cost)
    }
    
    // MARK: - Player Cache
    func getCachedPlayer(for url: String) -> AVPlayer? {
        playerQueue.sync { playerCache[url] }
    }
    
    func cachePlayer(_ player: AVPlayer, for url: String) {
        playerQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            // Evict the genuine oldest entry (LRU) once we hit the limit.
            if self.playerCache[url] == nil {
                self.playerOrder.append(url)
            }
            while self.playerCache.count >= 10, let oldest = self.playerOrder.first, oldest != url {
                self.playerCache[oldest]?.pause()
                self.playerCache.removeValue(forKey: oldest)
                self.playerOrder.removeFirst()
            }
            self.playerCache[url] = player
        }
    }
    
    func removeCachedPlayer(for url: String) {
        playerQueue.async(flags: .barrier) { [weak self] in
            self?.playerCache[url]?.pause()
            self?.playerCache.removeValue(forKey: url)
            self?.playerOrder.removeAll { $0 == url }
        }
    }
    
    // MARK: - Asset Cache
    func getCachedAsset(for url: String) -> AVURLAsset? {
        assetQueue.sync { assetCache[url] }
    }
    
    func cacheAsset(_ asset: AVURLAsset, for url: String) {
        assetQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            // Evict the genuine oldest entry (LRU) once we hit the limit.
            if self.assetCache[url] == nil {
                self.assetOrder.append(url)
            }
            while self.assetCache.count >= 20, let oldest = self.assetOrder.first, oldest != url {
                self.assetCache.removeValue(forKey: oldest)
                self.assetOrder.removeFirst()
            }
            self.assetCache[url] = asset
        }
    }
    
    // MARK: - 🔥 THERMONUCLEAR PREWARM
    func prewarmStreams(_ urls: [String]) {
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async { [weak self] in
            for urlString in urls.prefix(6) {
                guard let url = URL(string: urlString) else { continue }
                guard self?.getCachedAsset(for: urlString) == nil else { continue }
                
                // 🔥 Create ultra-optimized asset
                let asset = AVURLAsset(url: url, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: false,
                    AVURLAssetAllowsCellularAccessKey: true,
                    "AVURLAssetHTTPHeaderFieldsKey": [
                        "Connection": "keep-alive",
                        "Accept-Encoding": "gzip, deflate"
                    ]
                ])
                
                self?.cacheAsset(asset, for: urlString)
                
                // 🔥 Pre-create player for top 3
                if urls.prefix(3).contains(urlString) {
                    let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [])
                    item.preferredPeakBitRate = 100_000 // 100kbps - BLAZING
                    item.preferredForwardBufferDuration = 0.05 // 50ms buffer
                    item.preferredMaximumResolution = CGSize(width: 320, height: 180) // 180p
                    
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = true
                    player.automaticallyWaitsToMinimizeStalling = false
                    player.preventsDisplaySleepDuringVideoPlayback = false
                    
                    self?.cachePlayer(player, for: urlString)
                }
            }
            print("🔥 [ThermonuclearCache] Prewarmed \(min(urls.count, 6)) streams")
        }
    }
}

// MARK: - 🔥 THERMONUCLEAR LIVE THUMBNAIL VIEW
struct LiveChannelThumbnailView: View {
    let streamURL: String
    let posterURL: String?
    let fallbackStreamURL: String?
    let allowPlaybackInPreviews: Bool
    let initialDVRFraction: Double?
    let showsLiveBadge: Bool
    var channelCategory: LiveTVChannel.ChannelCategory?
    var channelName: String?
    var channelId: String?
    var onStreamFailed: (() -> Void)?
    var onStreamReady: (() -> Void)?
    /// 🔒 PERMANENT THUMBNAIL FIX: passed straight into the embedded AVPlayerLayer
    /// (see `ThermonuclearPlayerView.cornerRadius`) since a parent `.clipShape` on
    /// this view cannot mask that native sublayer. Defaults to 0 for call sites that
    /// clip a plain rectangle; pass the real corner radius for rounded cards.
    var cornerRadius: CGFloat = 0

    @State private var isReady: Bool = false
    @State private var cachedSnapshot: UIImage?
    @State private var hasAppeared = false
    @State private var canActivatePlayer = false
    @State private var posterLoaded = false
    @State private var streamFailed = false

    init(
        streamURL: String,
        posterURL: String? = nil,
        fallbackStreamURL: String? = nil,
        allowPlaybackInPreviews: Bool = false,
        initialDVRFraction: Double? = nil,
        showsLiveBadge: Bool = true,
        channelCategory: LiveTVChannel.ChannelCategory? = nil,
        channelName: String? = nil,
        channelId: String? = nil,
        onStreamFailed: (() -> Void)? = nil,
        onStreamReady: (() -> Void)? = nil,
        cornerRadius: CGFloat = 0
    ) {
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.fallbackStreamURL = fallbackStreamURL
        self.allowPlaybackInPreviews = allowPlaybackInPreviews
        self.initialDVRFraction = initialDVRFraction
        self.showsLiveBadge = showsLiveBadge
        self.channelCategory = channelCategory
        self.channelName = channelName
        self.channelId = channelId
        self.onStreamFailed = onStreamFailed
        self.onStreamReady = onStreamReady
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            // 🔥 Layer 0: ALWAYS show poster/logo image as base layer
            // This ensures thumbnails are ALWAYS visible, never blank
            staticPosterImage
            
            // 🔥 Layer 1: Cached video snapshot (shows in <10ms if available)
            if let snapshot = cachedSnapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.1)))
            }
            
            // 🔥 Layer 2: Live video player (ONLY if limiter allows)
            // Video player is completely hidden until stream is ready
            if canActivatePlayer && hasAppeared && (!AppConfig.isPreview || allowPlaybackInPreviews) && !streamFailed {
                ThermonuclearPlayer(
                    urls: buildURLCandidates(),
                    initialPlaybackFraction: initialDVRFraction,
                    onReady: { handleReady() },
                    onSnapshot: { handleSnapshot($0) },
                    onAllFailed: { handleAllFailed() },
                    cornerRadius: cornerRadius
                )
                .opacity(isReady ? 1 : 0)
                .allowsHitTesting(isReady)
            }
            
            // 🔥 Layer 3: LIVE badge (always show when we have a poster or stream is ready)
            if showsLiveBadge && (posterLoaded || isReady) {
                liveBadge
            }
        }
        .clipped()
        .onAppear {
            hasAppeared = true
            
            // 🔥 INSTANT cache check - no delay!
            if let cached = ThermonuclearThumbnailCache.shared.getCachedImage(for: streamURL) {
                cachedSnapshot = cached
                // If we have a cached snapshot, consider it ready enough to show
                if !isReady {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isReady = true
                    }
                    onStreamReady?()
                }
            }
            
            // 🔥 FAST player activation - reduced delay!
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 🔥 50ms (was 150ms)
                if ActivePlayerLimiter.shared.requestActivation(for: streamURL) {
                    canActivatePlayer = true
                } else if allowPlaybackInPreviews {
                    _ = ActivePlayerLimiter.shared.forceDeactivateOldest()
                    if ActivePlayerLimiter.shared.requestActivation(for: streamURL) {
                        canActivatePlayer = true
                    }
                }
            }
        }
        .onDisappear {
            // 🔥 Instant cleanup
            ActivePlayerLimiter.shared.deactivate(url: streamURL)
            canActivatePlayer = false
            isReady = false
        }
    }
    
    private func handleAllFailed() {
        streamFailed = true
        // Report to health agent and loading tracker if we have a channel ID
        if let channelId = channelId {
            Task { @MainActor in
                StreamHealthMLAgent.shared.markChannelUnhealthy(channelId)
                LiveChannelLoadingTracker.shared.markFailed(channelId)
            }
        }
        onStreamFailed?()
    }
    
    // 🔥 Build URL candidates with nuclear fallbacks
    private func buildURLCandidates() -> [String] {
        let nuclearFallbacks = [
            // Apple's official test streams - ALWAYS work
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
            // Mux test stream
            "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            // Akamai test stream
            "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8",
            // Unified Streaming demo
            "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"
        ]
        
        var urls: [String] = []
        if allowPlaybackInPreviews {
            if let fallback = fallbackStreamURL {
                urls.append(fallback)
            }
            urls.append(contentsOf: nuclearFallbacks)
            urls.append(streamURL)
        } else {
            urls.append(streamURL)
            if let fallback = fallbackStreamURL {
                urls.append(fallback)
            }
            urls.append(contentsOf: nuclearFallbacks)
        }
        
        return Array(NSOrderedSet(array: urls)) as? [String] ?? urls
    }
    
    private func handleReady() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isReady = true
        }
        // Mark channel as healthy when stream plays successfully
        if let channelId = channelId {
            Task { @MainActor in
                StreamHealthMLAgent.shared.markChannelHealthy(channelId)
                LiveChannelLoadingTracker.shared.markReady(channelId)
            }
        }
        onStreamReady?()
    }
    
    private func handleSnapshot(_ image: UIImage) {
        cachedSnapshot = image
        ThermonuclearThumbnailCache.shared.cacheImage(image, for: streamURL)
    }
    
    // 🔥 STATIC POSTER IMAGE - Always shows the channel logo as fallback
    private var staticPosterImage: some View {
        if let posterURL = posterURL {
            // 🔥 Handle asset:// URLs (local Assets.xcassets images)
            if posterURL.hasPrefix("asset://") {
                let assetName = String(posterURL.dropFirst("asset://".count))
                print("📸 [LiveChannelThumbnailView] Loading asset: \(assetName)")
                
                // 🔥 Use AppAsyncImage for robust asset:// URL handling
                return AnyView(
                    AppAsyncImage(url: URL(string: posterURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                if !posterLoaded {
                                    posterLoaded = true
                                    print("✅ [LiveChannelThumbnailView] Asset loaded: \(assetName)")
                                }
                            }
                    } placeholder: {
                        categoryGradientPlaceholder
                    }
                )
            } else if isValidImageURL(posterURL) {
                // 🔥 Use smart image loader that detects YouTube error thumbnails
                return AnyView(
                    SmartYouTubeThumbnailView(
                        url: posterURL,
                        placeholder: { categoryGradientPlaceholder },
                        onLoaded: {
                            if !posterLoaded {
                                posterLoaded = true
                            }
                        }
                    )
                )
            } else {
                // Invalid URL - show gradient placeholder
                print("⚠️ [LiveChannelThumbnailView] Invalid URL: \(posterURL)")
                return AnyView(categoryGradientPlaceholder)
            }
        } else {
            // No poster URL provided - show gradient placeholder
            print("⚠️ [LiveChannelThumbnailView] No posterURL provided")
            return AnyView(categoryGradientPlaceholder)
        }
    }
    
    // 🔥 Beautiful gradient placeholder with channel branding
    private var categoryGradientPlaceholder: some View {
        let categoryColor = channelCategory?.color ?? .blue
        
        return ZStack {
            // Dynamic gradient background
            LinearGradient(
                colors: [
                    categoryColor.opacity(0.9),
                    categoryColor.opacity(0.6),
                    categoryColor.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Channel icon and name
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                if let name = channelName {
                    Text(name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        }
        .onAppear {
            // Mark poster as loaded for gradient placeholder
            if !posterLoaded {
                posterLoaded = true
            }
        }
    }
    
    // 🔥 Fire gradient placeholder based on category
    private var firePlaceholder: some View {
        let categoryColor = channelCategory?.color ?? .blue
        
        return ZStack {
            // Dynamic gradient - beautiful category-colored background
            LinearGradient(
                colors: [
                    categoryColor.opacity(0.9),
                    categoryColor.opacity(0.7),
                    categoryColor.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle wave pattern for visual interest
            GeometryReader { geo in
                ZStack {
                    // Curved wave overlay
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: 0, y: h * 0.7))
                        path.addQuadCurve(
                            to: CGPoint(x: w, y: h * 0.6),
                            control: CGPoint(x: w * 0.5, y: h * 0.4)
                        )
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.08))
                    
                    // Second wave
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: 0, y: h * 0.85))
                        path.addQuadCurve(
                            to: CGPoint(x: w, y: h * 0.75),
                            control: CGPoint(x: w * 0.6, y: h * 0.95)
                        )
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.05))
                }
            }
            
            // Shimmer effect when loading
            if !isReady && hasAppeared && canActivatePlayer {
                ThermonuclearShimmer()
                    .opacity(0.25)
            }
            
            // Channel branding - centered logo/icon with channel name
            VStack(spacing: 8) {
                // Logo circle with icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                if let name = channelName {
                    Text(name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .padding(.horizontal, 8)
                }
            }
        }
        .opacity(isReady ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: isReady)
    }
    
    private var categoryIcon: String {
        switch channelCategory {
        case .anime: return "sparkles.tv"
        case .scifi: return "wand.and.stars"
        case .reality: return "person.3.fill"
        case .comedy: return "face.smiling.fill"
        case .kids: return "figure.and.child.holdinghands"
        case .news: return "newspaper.fill"
        case .sports: return "figure.run"
        case .movies: return "film.fill"
        case .music: return "music.note.tv"
        case .entertainment: return "tv.fill"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "heart.fill"
        case .business: return "chart.bar.fill"
        case .international: return "globe"
        case .classic: return "tv.fill"
        case .none: return "tv.fill"
        }
    }
    
    // Helper to check if a URL is likely to work for images
    private func isValidImageURL(_ urlString: String) -> Bool {
        let urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Skip Wikipedia URLs as they often block external requests
        if urlString.contains("wikipedia.org") || urlString.contains("wikimedia.org") {
            return false
        }
        // Skip SVG URLs as AsyncImage doesn't handle them well
        if urlString.hasSuffix(".svg") {
            return false
        }
        // 🔥 Accept any URL that looks like an image
        // Direct image file extensions
        if urlString.hasSuffix(".jpg") ||
           urlString.hasSuffix(".jpeg") ||
           urlString.hasSuffix(".png") ||
           urlString.hasSuffix(".webp") ||
           urlString.hasSuffix(".gif") {
            return true
        }
        // Known reliable image CDNs and services
        return urlString.contains("ytimg.com") ||           // YouTube thumbnails
               urlString.contains("imgur.com") ||           // Imgur
               urlString.contains("cloudinary.com") ||      // Cloudinary CDN
               urlString.contains("pluto.tv") ||            // Pluto TV
               urlString.contains("googleusercontent.com") || // Google CDN
               urlString.contains("firebasestorage.googleapis.com") || // 🔥 Firebase Storage thumbnails (uploads)
               urlString.contains("storage.googleapis.com") || // GCS direct
               urlString.contains("akamaized.net") ||       // Akamai CDN
               urlString.contains("cloudfront.net") ||      // AWS CloudFront
               urlString.contains("twimg.com") ||           // Twitter images
               urlString.contains("fbcdn.net") ||           // Facebook CDN
               urlString.contains("staticflickr.com") ||    // Flickr
               urlString.contains("image.tmdb.org") ||      // TMDB movie images
               urlString.contains("static.wikia.nocookie.net") || // Fandom wikis (not Wikipedia)
               urlString.contains("m.media-amazon.com") ||  // Amazon images
               urlString.contains("images-na.ssl-images-amazon.com") || // Amazon SSL images
               urlString.contains("mzstatic.com") ||        // Apple iTunes/TV artwork (stable, immutable)
               urlString.contains("picsum.photos")          // Picsum seeded images used in debug
    }
    
    // 🔥 LIVE badge
    private var liveBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.9))
                )
                Spacer()
            }
            Spacer()
        }
        .padding(4)
    }
    
    // 🔥 Loading indicator
    private var loadingIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    ThermonuclearPulsingDot()
                    Text("LOADING")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
                .padding(4)
            }
        }
    }
}


// ⚡ Player, image, shimmer + YouTube thumbnail cache extracted to LiveChannelComponents.swift
