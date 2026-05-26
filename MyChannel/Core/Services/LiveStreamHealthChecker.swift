import Foundation
import AVFoundation

struct LiveStreamHealthResult {
    let channel: LiveTVChannel
    let isHealthy: Bool
    let latency: TimeInterval
}

enum LiveStreamHealthChecker {
    private static let probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func rankHealthyChannels(_ channels: [LiveTVChannel],
                                    timeout: TimeInterval = 1.0) async -> [LiveTVChannel] {
        guard !channels.isEmpty else { return [] }
        
        // Batch check with optimized timeout based on network quality
        let networkQuality = NetworkOptimizer.shared.connectionQuality
        let adjustedTimeout = networkQuality == .poor ? timeout * 1.5 : timeout
        
        // Process all channels with concurrency limit
        return await withTaskGroup(of: LiveStreamHealthResult.self, returning: [LiveStreamHealthResult].self) { group in
            for ch in channels {
                group.addTask {
                    let start = CFAbsoluteTimeGetCurrent()
                    let healthy = await quickProbe(urlString: ch.streamURL, timeout: adjustedTimeout)
                    let dt = CFAbsoluteTimeGetCurrent() - start
                    return LiveStreamHealthResult(channel: ch, isHealthy: healthy, latency: max(0, dt))
                }
            }
            
            var results: [LiveStreamHealthResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        .filter { $0.isHealthy }
        .sorted { lhs, rhs in
            // Prioritize by health, then latency, then viewer count
            if lhs.isHealthy != rhs.isHealthy { return lhs.isHealthy && !rhs.isHealthy }
            if abs(lhs.latency - rhs.latency) > 0.05 { return lhs.latency < rhs.latency }
            return lhs.channel.viewerCount > rhs.channel.viewerCount
        }
        .map { $0.channel }
    }

    private static func quickProbe(urlString: String, timeout: TimeInterval) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        // Race HEAD and rangedGET in parallel — first success wins.
        // AVAsset probing is intentionally omitted: for unreachable HLS streams
        // AVFoundation retries master playlists and all variant tracks, producing
        // dozens of timed-out requests per channel and flooding the network.
        return await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask { await httpProbe(url: url, method: "HEAD", timeout: timeout) }
            group.addTask { await rangedGetProbe(url: url, timeout: timeout) }
            for await success in group {
                if success { group.cancelAll(); return true }
            }
            return false
        }
    }

    private static func httpProbe(url: URL, method: String, timeout: TimeInterval) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.setValue("MyChannel/1.0 (iOS) VideoPlayer", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.apple.mpegurl, application/x-mpegURL, */*", forHTTPHeaderField: "Accept")
        
        do {
            let (_, resp) = try await probeSession.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
        } catch { }
        return false
    }

    private static func rangedGetProbe(url: URL, timeout: TimeInterval) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        req.setValue("bytes=0-2048", forHTTPHeaderField: "Range")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.setValue("MyChannel/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await probeSession.data(for: req)
            if let http = resp as? HTTPURLResponse, (200...206).contains(http.statusCode) {
                // M3U8 playlist usually starts with #EXTM3U
                if let s = String(data: data, encoding: .utf8), s.contains("#EXTM3U") {
                    return true
                }
                // Some CDNs may not return text; accept HTTP success as OK.
                return true
            }
        } catch { }
        return false
    }

    // NOTE: assetProbe is intentionally removed. AVURLAsset.loadValuesAsynchronously
    // for unreachable HLS streams internally retries master playlists and all variant
    // tracks with no upper bound, producing 30+ timeout errors per channel in the log.
    // HEAD + rangedGET in quickProbe are sufficient health signals.
}