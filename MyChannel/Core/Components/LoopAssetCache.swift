import AVFoundation

/// Thread-safe asset cache for looping videos
actor LoopAssetCache {
    static let shared = LoopAssetCache()
    private var cache: [String: AVURLAsset] = [:]
    private var warmTasks: [String: Task<Void, Never>] = [:]
    private var accessOrder: [String] = []
    
    // Max videos to keep in memory
    private let maxCapacity = 50

    private init() {}

    func asset(for urlString: String) -> AVURLAsset {
        if let cached = cache[urlString] {
            updateAccessOrder(for: urlString)
            return cached
        }
        
        let url = URL(string: urlString) ?? URL(fileURLWithPath: urlString)
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        
        cache[urlString] = asset
        updateAccessOrder(for: urlString)
        enforceCapacity()
        
        // Warm in background — load tracks + isPlayable so first frame is instant
        warmTasks[urlString] = Task.detached(priority: .utility) { [weak asset] in
            guard let asset else { return }
            _ = try? await asset.load(.tracks, .isPlayable)
        }
        return asset
    }
    
    private func updateAccessOrder(for urlString: String) {
        if let index = accessOrder.firstIndex(of: urlString) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(urlString)
    }
    
    private func enforceCapacity() {
        while cache.count > maxCapacity {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
            warmTasks[oldest]?.cancel()
            warmTasks.removeValue(forKey: oldest)
        }
    }
}
