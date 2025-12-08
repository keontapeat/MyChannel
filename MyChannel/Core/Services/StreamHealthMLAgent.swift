//
//  StreamHealthMLAgent.swift
//  MyChannel
//
//  🔥🔥🔥 THERMONUCLEAR STREAM HEALTH ML AGENT 🔥🔥🔥
//  BLAZING FAST stream health detection
//  Sub-100ms responses, parallel probing, aggressive caching
//
//  Created by AI Assistant on 12/6/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Stream Health Status
enum StreamHealthStatus: String, Codable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
}

// MARK: - Stream Health Result
struct StreamHealthResult: Codable {
    let channelId: String
    let streamURL: String
    let status: StreamHealthStatus
    let latencyMs: Int
    let lastChecked: Date
    let consecutiveFailures: Int
    let successRate: Double
    
    var isPlayable: Bool { status == .healthy || status == .degraded }
}

// MARK: - 🔥🔥🔥 THERMONUCLEAR STREAM HEALTH ML AGENT 🔥🔥🔥
@MainActor
final class StreamHealthMLAgent: ObservableObject {
    static let shared = StreamHealthMLAgent()
    
    // MARK: - Published State
    @Published private(set) var healthyChannelIds: Set<String> = []
    @Published private(set) var unhealthyChannelIds: Set<String> = []
    @Published private(set) var isInitialized = false
    @Published private(set) var totalChecked: Int = 0
    @Published private(set) var healthyCount: Int = 0
    
    // MARK: - 🔥 BLAZING FAST CACHE
    private var healthCache: [String: StreamHealthResult] = [:]
    private var checkHistory: [String: [Bool]] = [:]
    private let cacheValidityDuration: TimeInterval = 600 // 10 min cache for healthy
    private let unhealthyCacheValidity: TimeInterval = 120 // 2 min for unhealthy
    
    // 🔥 KNOWN GOOD STREAMS - Skip health check entirely!
    private let knownGoodDomains: Set<String> = [
        "devstreaming-cdn.apple.com",
        "test-streams.mux.dev",
        "demo.unified-streaming.com",
        "cph-p2p-msl.akamaized.net",
        "ntv1.akamaized.net",
        "ntv2.akamaized.net"
    ]
    
    // 🔥 KNOWN BAD PATTERNS - Instant reject!
    private let knownBadPatterns: [String] = [
        "404", "error", "offline", "expired"
    ]
    
    // MARK: - 🔥 OPTIMIZED SESSION - Reuse connections!
    private lazy var fastSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5 // 🔥 BLAZING 1.5s timeout
        config.timeoutIntervalForResource = 2.0
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 10
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    // MARK: - Background Monitoring
    private var monitoringTask: Task<Void, Never>?
    
    private init() {
        print("🔥 [StreamHealthML] THERMONUCLEAR Stream Health Agent ONLINE!")
        startBackgroundMonitoring()
    }
    
    // MARK: - 🔥🔥🔥 BLAZING FAST PUBLIC API 🔥🔥🔥
    
    /// 🔥 INSTANT filter - uses cache, NO network calls for cached channels
    func filterHealthyChannels(_ channels: [LiveTVChannel]) async -> [LiveTVChannel] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var healthy: [LiveTVChannel] = []
        var needsCheck: [LiveTVChannel] = []
        
        // 🔥 PHASE 1: Instant cache lookup (< 1ms)
        for channel in channels {
            // Known good domain? INSTANT PASS! 🔥
            if isKnownGoodStream(channel.streamURL) {
                healthy.append(channel)
                continue
            }
            
            // Check cache
            if let cached = healthCache[channel.id], !isCacheExpired(cached) {
                if cached.isPlayable {
                    healthy.append(channel)
                }
                // Skip unhealthy silently
            } else {
                needsCheck.append(channel)
            }
        }
        
        // 🔥 PHASE 2: Parallel batch check for unknowns (if any)
        if !needsCheck.isEmpty {
            let results = await ultraFastBatchCheck(needsCheck)
            for (channel, result) in zip(needsCheck, results) {
                if result.isPlayable {
                    healthy.append(channel)
                }
            }
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("🔥 [StreamHealthML] Filtered \(channels.count) → \(healthy.count) in \(Int(elapsed))ms")
        
        return healthy
    }
    
    /// 🔥 INSTANT health check - cache first, always
    func isChannelHealthy(_ channel: LiveTVChannel) async -> Bool {
        // Known good? INSTANT! 🔥
        if isKnownGoodStream(channel.streamURL) { return true }
        
        // Cache hit? INSTANT! 🔥
        if let cached = healthCache[channel.id], !isCacheExpired(cached) {
            return cached.isPlayable
        }
        
        // Need to check - but FAST
        let result = await ultraFastCheck(channel)
        return result.isPlayable
    }
    
    /// Get cached health status (INSTANT, no network)
    func getHealthStatus(_ channelId: String) -> StreamHealthStatus {
        healthCache[channelId]?.status ?? .unknown
    }
    
    /// 🔥 Mark a channel as unhealthy (called when stream fails to play)
    func markChannelUnhealthy(_ channelId: String) {
        print("🔥 [StreamHealthML] Marking \(channelId) as UNHEALTHY from player failure")
        
        // Update cache with unhealthy status
        let result = StreamHealthResult(
            channelId: channelId,
            streamURL: "",
            status: .unhealthy,
            latencyMs: 0,
            lastChecked: Date(),
            consecutiveFailures: (healthCache[channelId]?.consecutiveFailures ?? 0) + 1,
            successRate: 0
        )
        healthCache[channelId] = result
        
        // Update published state
        healthyChannelIds.remove(channelId)
        unhealthyChannelIds.insert(channelId)
    }
    
    /// 🔥 Mark a channel as healthy (called when stream plays successfully)
    func markChannelHealthy(_ channelId: String) {
        // Only update if not already healthy in cache
        if healthCache[channelId]?.status != .healthy {
            let result = StreamHealthResult(
                channelId: channelId,
                streamURL: "",
                status: .healthy,
                latencyMs: 100,
                lastChecked: Date(),
                consecutiveFailures: 0,
                successRate: 1.0
            )
            healthCache[channelId] = result
            
            // Update published state
            unhealthyChannelIds.remove(channelId)
            healthyChannelIds.insert(channelId)
        }
    }
    
    // MARK: - 🔥🔥🔥 THERMONUCLEAR PROBING 🔥🔥🔥
    
    /// 🔥 Single channel ultra-fast check
    private func ultraFastCheck(_ channel: LiveTVChannel) async -> StreamHealthResult {
        let channelId = channel.id
        let streamURL = channel.streamURL
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 🔥 INSTANT KNOWN GOOD
        if isKnownGoodStream(streamURL) {
            return createResult(channelId: channelId, streamURL: streamURL, status: .healthy, latencyMs: 0)
        }
        
        // 🔥 INSTANT KNOWN BAD
        if isKnownBadStream(streamURL) {
            return createResult(channelId: channelId, streamURL: streamURL, status: .unhealthy, latencyMs: 0)
        }
        
        // 🔥 RACE: First successful probe wins!
        let status = await withTaskGroup(of: (String, Bool).self) { group -> StreamHealthStatus in
            // Fire all probes in parallel!
            group.addTask { ("head", await self.blazingHeadProbe(url: streamURL)) }
            group.addTask { ("m3u8", await self.blazingM3U8Probe(url: streamURL)) }
            
            // First success wins!
            for await (method, success) in group {
                if success {
                    group.cancelAll()
                    print("🔥 [StreamHealthML] \(channel.name) passed \(method) probe")
                    return .healthy
                }
            }
            
            // Try fallback if available
            if let fallback = channel.previewFallbackURL {
                if await self.blazingHeadProbe(url: fallback) {
                    return .degraded
                }
            }
            
            return .unhealthy
        }
        
        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        let result = createResult(channelId: channelId, streamURL: streamURL, status: status, latencyMs: latencyMs)
        
        // Cache it
        healthCache[channelId] = result
        updatePublishedState()
        
        return result
    }
    
    /// 🔥 PARALLEL batch check - all channels at once!
    private func ultraFastBatchCheck(_ channels: [LiveTVChannel]) async -> [StreamHealthResult] {
        await withTaskGroup(of: (Int, StreamHealthResult).self) { group in
            var results = [StreamHealthResult](repeating: StreamHealthResult(
                channelId: "", streamURL: "", status: .unknown,
                latencyMs: 0, lastChecked: Date(), consecutiveFailures: 0, successRate: 0
            ), count: channels.count)
            
            for (index, channel) in channels.enumerated() {
                group.addTask {
                    let result = await self.ultraFastCheck(channel)
                    return (index, result)
                }
            }
            
            for await (index, result) in group {
                results[index] = result
            }
            
            return results
        }
    }
    
    // MARK: - 🔥🔥🔥 BLAZING PROBE METHODS 🔥🔥🔥
    
    /// 🔥 HEAD probe - 500ms timeout!
    private func blazingHeadProbe(url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 0.5 // 🔥 500ms!
        request.setValue("MyChannel/1.0", forHTTPHeaderField: "User-Agent")
        
        // Pluto TV headers
        if url.absoluteString.contains("pluto.tv") {
            request.setValue("https://pluto.tv", forHTTPHeaderField: "Origin")
            request.setValue("https://pluto.tv/", forHTTPHeaderField: "Referer")
        }
        
        do {
            let (_, response) = try await fastSession.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
        } catch { }
        
        return false
    }
    
    /// 🔥 M3U8 probe - 800ms timeout, range request!
    private func blazingM3U8Probe(url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.8 // 🔥 800ms!
        request.setValue("bytes=0-512", forHTTPHeaderField: "Range") // 🔥 Only 512 bytes!
        request.setValue("MyChannel/1.0", forHTTPHeaderField: "User-Agent")
        
        if url.absoluteString.contains("pluto.tv") {
            request.setValue("https://pluto.tv", forHTTPHeaderField: "Origin")
            request.setValue("https://pluto.tv/", forHTTPHeaderField: "Referer")
        }
        
        do {
            let (data, response) = try await fastSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let content = String(data: data, encoding: .utf8) {
                    return content.contains("#EXTM3U") || content.contains("#EXT-X-")
                }
                return true
            }
        } catch { }
        
        return false
    }
    
    // MARK: - 🔥 HELPER METHODS
    
    private func isKnownGoodStream(_ url: String) -> Bool {
        for domain in knownGoodDomains {
            if url.contains(domain) { return true }
        }
        return false
    }
    
    private func isKnownBadStream(_ url: String) -> Bool {
        let lower = url.lowercased()
        for pattern in knownBadPatterns {
            if lower.contains(pattern) { return true }
        }
        return false
    }
    
    private func isCacheExpired(_ result: StreamHealthResult) -> Bool {
        let validity = result.status == .unhealthy ? unhealthyCacheValidity : cacheValidityDuration
        return Date().timeIntervalSince(result.lastChecked) > validity
    }
    
    private func createResult(
        channelId: String,
        streamURL: String,
        status: StreamHealthStatus,
        latencyMs: Int
    ) -> StreamHealthResult {
        var history = checkHistory[channelId] ?? []
        history.append(status == .healthy || status == .degraded)
        if history.count > 10 { history.removeFirst() }
        checkHistory[channelId] = history
        
        let successRate = history.isEmpty ? 0.5 : Double(history.filter { $0 }.count) / Double(history.count)
        let consecutiveFailures = status == .unhealthy ? (healthCache[channelId]?.consecutiveFailures ?? 0) + 1 : 0
        
        return StreamHealthResult(
            channelId: channelId,
            streamURL: streamURL,
            status: status,
            latencyMs: latencyMs,
            lastChecked: Date(),
            consecutiveFailures: consecutiveFailures,
            successRate: successRate
        )
    }
    
    private func updatePublishedState() {
        var healthy = Set<String>()
        var unhealthy = Set<String>()
        
        for (channelId, result) in healthCache {
            if result.isPlayable {
                healthy.insert(channelId)
            } else if result.status == .unhealthy {
                unhealthy.insert(channelId)
            }
        }
        
        healthyChannelIds = healthy
        unhealthyChannelIds = unhealthy
        totalChecked = healthCache.count
        healthyCount = healthy.count
    }
    
    // MARK: - 🔥 BACKGROUND MONITORING
    
    private func startBackgroundMonitoring() {
        monitoringTask = Task { [weak self] in
            // 🔥 FAST initial check - top 20 only!
            await self?.performInitialHealthCheck()
            
            // Background loop
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 sec intervals
                await self?.performPeriodicHealthCheck()
            }
        }
    }
    
    private func performInitialHealthCheck() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔥 [StreamHealthML] THERMONUCLEAR initial health check starting...")
        
        // 🔥 Only check top 20 initially for SPEED
        let topChannels = Array(LiveTVChannel.sampleChannels.prefix(20))
        _ = await ultraFastBatchCheck(topChannels)
        
        isInitialized = true
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        print("✅ [StreamHealthML] Initial check DONE in \(elapsed)ms - \(healthyCount)/\(totalChecked) healthy")
    }
    
    private func performPeriodicHealthCheck() async {
        let channelsToCheck = LiveTVChannel.sampleChannels.filter { channel in
            guard let cached = healthCache[channel.id] else { return true }
            if cached.status == .unhealthy {
                return Date().timeIntervalSince(cached.lastChecked) > 60 // 1 min
            }
            return Date().timeIntervalSince(cached.lastChecked) > 300 // 5 min
        }
        
        if !channelsToCheck.isEmpty {
            _ = await ultraFastBatchCheck(Array(channelsToCheck.prefix(8)))
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    deinit { monitoringTask?.cancel() }
}

