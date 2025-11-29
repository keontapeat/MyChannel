import Foundation
import AVFoundation

// Aggregates live channels from openly documented HLS sources and EPGs
final class LiveTVService {
    static let shared = LiveTVService()
    private init() {}
    
    // 🔥 Cache for preloaded assets
    private var preloadedAssets: [String: AVURLAsset] = [:]
    private let preloadQueue = DispatchQueue(label: "com.mychannel.liveTVPreload", qos: .userInitiated)

    func fetchChannels() async -> [LiveTVChannel] {
        // For now, return curated, legal HLS channels (sample list present in model)
        // Later we can plug in Samsung TV Plus/Pluto public guide JSONs if allowed
        return LiveTVChannel.sampleChannels
    }
    
    // 🔥🔥🔥 THERMONUCLEAR: Prewarm thumbnails for instant display 🔥🔥🔥
    func thermonuclearPrewarm(count: Int = 10) {
        let channels = Array(LiveTVChannel.sampleChannels.prefix(count))
        ThermonuclearPrewarm.prewarmChannels(channels)
        print("🔥🔥🔥 [THERMONUCLEAR] Prewarmed \(count) channels for INSTANT thumbnails!")
    }
    
    // 🔥 FIRE: Preload the first N channels for instant playback
    func preloadFireChannels(count: Int = 6) async {
        let channels = Array(LiveTVChannel.sampleChannels.prefix(count))
        
        // 🔥 Also prewarm thumbnails
        thermonuclearPrewarm(count: count)
        
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask { [weak self] in
                    await self?.preloadChannel(channel)
                }
            }
        }
        
        print("🔥 LiveTVService: Preloaded \(count) fire channels for instant playback")
    }
    
    /// Preload next channel for smooth switching
    func preloadChannel(_ channel: LiveTVChannel) async {
        guard let url = URL(string: channel.streamURL) else { return }
        
        // Check if already preloaded
        if preloadedAssets[channel.id] != nil { return }
        
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
            // Silently fail - fallback will handle
        }
    }
    
    /// Get preloaded asset if available
    func getPreloadedAsset(for channelId: String) -> AVURLAsset? {
        return preloadedAssets[channelId]
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
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            // Try asset-based check as fallback
            return await checkAssetPlayability(url)
        }
        
        return false
    }
    
    private func checkAssetPlayability(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        return await withCheckedContinuation { continuation in
            asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                var playable = false
                var error: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &error)
                if status == .loaded {
                    playable = asset.isPlayable
                }
                continuation.resume(returning: playable)
            }
        }
    }
}


