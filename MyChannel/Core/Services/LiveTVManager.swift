//
//  LiveTVManager.swift
//  MyChannel
//
//  Created by AI Assistant on 12/20/24.
//
//  🔥 BULLETPROOF LIVE TV MANAGER 🔥
//  Ensures all channels work 24/7 by:
//  1. Loading the Firebase-curated catalog (fixable server-side, no app release)
//  2. Falling back to bundled curated channels when the catalog is unavailable
//  3. Monitoring stream health
//  4. Auto-refreshing on app launch and caching for instant/offline load

import Foundation
import Combine

@MainActor
final class LiveTVManager: ObservableObject {
    static let shared = LiveTVManager()
    
    // MARK: - Published State
    @Published private(set) var channels: [LiveTVChannel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefresh: Date?

    // MARK: - Configuration
    private let refreshIntervalHours: Double = 4 // Refresh every 4 hours

    // MARK: - Private State
    private var refreshTask: Task<Void, Never>?
    private let cache = ChannelCache()

    private init() {
        // Load cached channels immediately for instant UI
        loadCachedChannels()
    }
    
    // MARK: - Public API
    
    /// Call this on app launch to ensure fresh channels
    func initialize() async {
        print("🔥 [LiveTVManager] Initializing...")
        
        // Load cache first for instant display
        loadCachedChannels()
        
        // Then refresh in background if needed
        if shouldRefresh() {
            await refreshChannels()
        }

        // Stream health is owned by StreamHealthMLAgent (single source of truth).
        // It runs its own background monitoring; we no longer duplicate that work here.

        print("✅ [LiveTVManager] Ready with \(channels.count) channels")
    }
    
    /// Force refresh all channel data
    func refreshChannels() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 [LiveTVManager] Refreshing channels from API...")
        
        // 1️⃣ Prefer the Firebase-curated catalog (can be fixed server-side, no app release).
        if let remote = await LiveTVCatalogService.shared.fetchRemoteChannels(), !remote.isEmpty {
            channels = remote
            lastRefresh = Date()
            cache.save(channels: remote, lastRefresh: Date())
            print("✅ [LiveTVManager] Using \(remote.count) Firebase-curated channels")
            return
        }
        
        // 2️⃣ No Firebase catalog available — use the curated local channels.
        //    The Pluto TV API fetch/merge path was removed: Pluto blocks in-app
        //    playback, and merging its stream URLs actively overwrote our working
        //    curated HLS URLs with Pluto URLs that only ever fell back to a demo
        //    clip. Curated sample data (or the Firestore catalog above) is the
        //    source of truth.
        let curated = LiveTVChannel.sampleChannels
        channels = curated
        lastRefresh = Date()
        cache.save(channels: curated, lastRefresh: Date())
        print("✅ [LiveTVManager] Using \(curated.count) curated channels")
    }
    
    /// Check if a specific channel is working.
    /// Delegates to StreamHealthMLAgent, the single source of truth for stream
    /// health. Unknown (not-yet-probed) channels are treated as available so we
    /// never hide channels that simply haven't been checked yet.
    func isChannelHealthy(_ channelId: String) -> Bool {
        let agent = StreamHealthMLAgent.shared
        if agent.unhealthyChannelIds.contains(channelId) { return false }
        return true
    }

    // MARK: - Cache Management
    
    private func loadCachedChannels() {
        if let cached = cache.load() {
            channels = cached.channels
            lastRefresh = cached.lastRefresh
            print("📦 [LiveTVManager] Loaded \(cached.channels.count) cached channels")
        } else {
            // Use static channels as initial data
            channels = LiveTVChannel.sampleChannels
            print("📦 [LiveTVManager] Using \(channels.count) static channels")
        }
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = lastRefresh else { return true }
        let hoursSinceRefresh = Date().timeIntervalSince(lastRefresh) / 3600
        return hoursSinceRefresh > refreshIntervalHours
    }
    
}

// MARK: - Cache

private class ChannelCache {
    private let cacheKey = "live_tv_channels_cache_v2"
    
    struct CachedData: Codable {
        let channels: [LiveTVChannel]
        let lastRefresh: Date
    }
    
    func save(channels: [LiveTVChannel], lastRefresh: Date) {
        let data = CachedData(channels: channels, lastRefresh: lastRefresh)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    func load() -> CachedData? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedData.self, from: data) else {
            return nil
        }
        return cached
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

// MARK: - App Lifecycle Integration

extension LiveTVManager {
    /// Call this when app becomes active
    func onAppBecameActive() {
        Task {
            if shouldRefresh() {
                await refreshChannels()
            }
        }
    }
    
    /// Call this when app enters background
    func onAppEnteredBackground() {
        // Stream health monitoring is owned by StreamHealthMLAgent; nothing to
        // cancel here anymore.
    }
}



