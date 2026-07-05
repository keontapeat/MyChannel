import Foundation
import AVFoundation

// Aggregates live channels from openly documented HLS sources and EPGs
final class LiveTVService {
    static let shared = LiveTVService()
    private init() {}
    
    // 🔥 Cache for preloaded assets
    private var preloadedAssets: [String: AVURLAsset] = [:]
    private var preloadedChannelIds: Set<String> = []
    private var lastBulkPreloadAt: Date?
    private let preloadQueue = DispatchQueue(label: "com.mychannel.liveTVPreload", qos: .userInitiated)

    func fetchChannels() async -> [LiveTVChannel] {
        // 🔥 Use dynamic LiveTVManager for fresh channel data
        // Access MainActor-isolated properties properly
        let channels = await MainActor.run {
            let manager = LiveTVManager.shared
            return manager.channels.isEmpty ? LiveTVChannel.sampleChannels : manager.channels
        }
        return channels
    }
    
    /// Initialize the Live TV system - call on app launch
    func initialize() async {
        await LiveTVManager.shared.initialize()
    }
    
    /// Force refresh channel data from API
    func refreshChannels() async {
        await LiveTVManager.shared.refreshChannels()
    }
    
    // 🔥🔥🔥 THERMONUCLEAR: Prewarm thumbnails for instant display 🔥🔥🔥
    func thermonuclearPrewarm(count: Int = 10) {
        let channels = Array(LiveTVChannel.sampleChannels.prefix(count))
        ThermonuclearPrewarm.prewarmChannels(channels)
        
        // 🔥🔥🔥 ALSO prewarm YouTube thumbnails in parallel!
        let logoURLs = channels.map { $0.logoURL }
        Task { @MainActor in
            ThermonuclearYouTubeThumbnailCache.shared.prewarmThumbnails(logoURLs)
        }
        
        print("🔥🔥🔥 [THERMONUCLEAR] Prewarmed \(count) channels for INSTANT thumbnails!")
    }
    
    // 🔥 FIRE: Preload the first N channels for instant playback
    func preloadFireChannels(count: Int = 6) async {
        let shouldPreload = preloadQueue.sync { () -> Bool in
            if let lastBulkPreloadAt, Date().timeIntervalSince(lastBulkPreloadAt) < 300 {
                return false
            }
            lastBulkPreloadAt = Date()
            return true
        }
        guard shouldPreload else { return }
        
        let channels = Array(LiveTVChannel.sampleChannels.prefix(min(count, 3)))
        let logoURLs = channels.map { $0.logoURL }
        Task { @MainActor in
            ThermonuclearYouTubeThumbnailCache.shared.prewarmThumbnails(logoURLs)
        }
        
        print("🔥 LiveTVService: Preloaded \(channels.count) fire channel thumbnails")
    }
    
    /// Preload next channel for smooth switching
    func preloadChannel(_ channel: LiveTVChannel) async {
        guard let url = URL(string: channel.streamURL) else { return }
        
        // Check if already preloaded
        let shouldPreload = preloadQueue.sync { () -> Bool in
            guard preloadedAssets[channel.id] == nil, !preloadedChannelIds.contains(channel.id) else {
                return false
            }
            preloadedChannelIds.insert(channel.id)
            return true
        }
        guard shouldPreload else { return }
        
        // Create asset and preload metadata without playing
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false,
            AVURLAssetAllowsCellularAccessKey: true
        ])
        
        // Load playable status in background
        do {
            try await asset.loadValues(forKeys: ["playable", "duration"])
            
            // Cache the preloaded asset
            preloadQueue.async { [weak self] in
                self?.preloadedAssets[channel.id] = asset
            }
        } catch {
            preloadQueue.async { [weak self] in
                self?.preloadedChannelIds.remove(channel.id)
            }
        }
    }
    
    /// Get preloaded asset if available.
    /// Reads through `preloadQueue` to avoid a data race with the async writes
    /// in `preloadChannel(_:)` / `clearPreloadedAssets()`.
    func getPreloadedAsset(for channelId: String) -> AVURLAsset? {
        return preloadQueue.sync { preloadedAssets[channelId] }
    }
    
    /// Clear preloaded assets to free memory
    func clearPreloadedAssets() {
        preloadQueue.async { [weak self] in
            self?.preloadedAssets.removeAll()
        }
    }
    
    /// Get best quality stream URL with fallback
    func getOptimalStreamURL(for channel: LiveTVChannel, networkQuality: ConnectionQuality) -> String {
        // If channel has fallback URL, use it for poor connections
        if networkQuality == .poor, let fallback = channel.previewFallbackURL {
            return fallback
        }
        
        // For excellent connections, prefer main stream
        return channel.streamURL
    }
    
    /// Check if stream is accessible and healthy
    func checkStreamHealth(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Quick HEAD request to check accessibility
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.configured.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch { }
        
        return false
    }
}


