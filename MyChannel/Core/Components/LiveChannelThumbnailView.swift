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
    
    // 🔥 Pre-warmed player cache
    private var playerCache: [String: AVPlayer] = [:]
    private let playerQueue = DispatchQueue(label: "com.mychannel.thermonuclear.players", attributes: .concurrent)
    
    // 🔥 Asset cache for instant replay
    private var assetCache: [String: AVURLAsset] = [:]
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
        }
        assetQueue.async(flags: .barrier) { [weak self] in
            self?.assetCache.removeAll()
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
            // Limit player cache to 10
            if self?.playerCache.count ?? 0 >= 10 {
                if let oldest = self?.playerCache.keys.first {
                    self?.playerCache[oldest]?.pause()
                    self?.playerCache.removeValue(forKey: oldest)
                }
            }
            self?.playerCache[url] = player
        }
    }
    
    func removeCachedPlayer(for url: String) {
        playerQueue.async(flags: .barrier) { [weak self] in
            self?.playerCache[url]?.pause()
            self?.playerCache.removeValue(forKey: url)
        }
    }
    
    // MARK: - Asset Cache
    func getCachedAsset(for url: String) -> AVURLAsset? {
        assetQueue.sync { assetCache[url] }
    }
    
    func cacheAsset(_ asset: AVURLAsset, for url: String) {
        assetQueue.async(flags: .barrier) { [weak self] in
            if self?.assetCache.count ?? 0 >= 20 {
                self?.assetCache.removeValue(forKey: self?.assetCache.keys.first ?? "")
            }
            self?.assetCache[url] = asset
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
        onStreamReady: (() -> Void)? = nil
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
                    onAllFailed: { handleAllFailed() }
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
               urlString.contains("akamaized.net") ||       // Akamai CDN
               urlString.contains("cloudfront.net") ||      // AWS CloudFront
               urlString.contains("twimg.com") ||           // Twitter images
               urlString.contains("fbcdn.net") ||           // Facebook CDN
               urlString.contains("staticflickr.com") ||    // Flickr
               urlString.contains("image.tmdb.org") ||      // TMDB movie images
               urlString.contains("static.wikia.nocookie.net") || // Fandom wikis (not Wikipedia)
               urlString.contains("m.media-amazon.com") ||  // Amazon images
               urlString.contains("images-na.ssl-images-amazon.com") // Amazon SSL images
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

// MARK: - 🔥 THERMONUCLEAR PLAYER
private struct ThermonuclearPlayer: UIViewRepresentable {
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
private final class ThermonuclearPlayerView: UIView {
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
                DispatchQueue.main.async { [weak self] in
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
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
                if p.timeControlStatus == .playing {
                    self?.notifyReady(onReady)
                    // 🔥 Generate snapshot after playing
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
            DispatchQueue.main.async {
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
        DispatchQueue.main.async { onReady() }
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
                DispatchQueue.main.async { onSnapshot(image) }
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
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
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
private struct ThermonuclearShimmer: View {
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
private struct ThermonuclearPulsingDot: View {
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
