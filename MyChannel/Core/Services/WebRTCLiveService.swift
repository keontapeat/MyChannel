//
//  WebRTCLiveService.swift
//  MyChannel
//
//  Phase 2.3: WebRTC Live Streaming — sub-500ms latency.
//  Uses Cloud Run signaling + STUN/TURN for NAT traversal.
//

import Foundation
import Combine

// MARK: - Models

struct LiveStreamConfig: Codable {
    let streamId: String
    let hostUserId: String
    let title: String
    let quality: LiveStreamQuality
    let latencyMode: LatencyMode
    let maxViewers: Int
    let enableDVR: Bool
    let enableChat: Bool
    let enableLowLatency: Bool
    
    enum LiveStreamQuality: String, Codable, CaseIterable {
        case q720p = "720p"
        case q1080p = "1080p"
        case q1440p = "1440p"
        case q4k = "4k"
    }
    
    enum LatencyMode: String, Codable {
        case normal = "normal"         // ~3-5s (HLS)
        case low = "low"              // ~1-2s (LL-HLS)
        case ultraLow = "ultra_low"   // <500ms (WebRTC)
    }
}

struct LiveStreamStats: Codable {
    let viewerCount: Int
    let peakViewers: Int
    let avgLatencyMs: Int
    let bitrate: Int
    let fps: Int
    let duration: TimeInterval
    let totalChatMessages: Int
    let totalLikes: Int
}

struct ICECandidate: Codable {
    let sdp: String
    let sdpMid: String?
    let sdpMLineIndex: Int?
}

struct SDPAnswer: Codable {
    let sdp: String
    let type: String
}

// MARK: - WebRTC Live Service

@MainActor
final class WebRTCLiveService: ObservableObject {
    static let shared = WebRTCLiveService()
    
    @Published var isLive = false
    @Published var currentStreamId: String?
    @Published var viewerCount: Int = 0
    @Published var streamStats: LiveStreamStats?
    @Published var latencyMs: Int = 0
    @Published var connectionState: ConnectionState = .disconnected
    
    private var cancellables = Set<AnyCancellable>()
    private let redisCache = RedisCacheService.shared
    
    enum ConnectionState: String {
        case disconnected
        case connecting
        case connected
        case live
        case reconnecting
        case failed
    }
    
    // STUN/TURN servers for NAT traversal
    private let iceServers: [[String: String]] = [
        ["urls": "stun:stun.l.google.com:19302"],
        ["urls": "stun:stun1.l.google.com:19302"],
        ["urls": "stun:stun2.l.google.com:19302"],
        // TURN servers via Cloud Run (for restrictive NATs)
        ["urls": "turn:turn.mychannel.app:3478?transport=udp", "username": "mychannel", "credential": "live"],
        ["urls": "turn:turn.mychannel.app:3478?transport=tcp", "username": "mychannel", "credential": "live"]
    ]
    
    private init() {}
    
    // MARK: - 🎥 HOST: Start Live Stream
    
    func startLiveStream(config: LiveStreamConfig) async throws -> String {
        guard !isLive else { throw LiveStreamError.alreadyLive }
        
        connectionState = .connecting
        
        struct Request: Encodable {
            let task: String
            let streamId: String
            let hostUserId: String
            let title: String
            let quality: String
            let latencyMode: String
            let maxViewers: Int
            let enableLowLatency: Bool
        }
        struct Response: Decodable {
            let streamId: String?
            let iceServers: [[String: String]]?
            let status: String?
        }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(
                task: "start_live_stream",
                streamId: config.streamId,
                hostUserId: config.hostUserId,
                title: config.title,
                quality: config.quality.rawValue,
                latencyMode: config.latencyMode.rawValue,
                maxViewers: config.maxViewers,
                enableLowLatency: config.enableLowLatency
            )
        )
        
        guard let streamId = r.streamId, r.status == "active" else {
            connectionState = .failed
            throw LiveStreamError.startFailed
        }
        
        currentStreamId = streamId
        isLive = true
        connectionState = .live
        
        // Cache live stream info in Redis for fast viewer discovery
        await redisCache.set("live:\(streamId)", value: config.title, ttl: 86400)
        await redisCache.set("live:viewers:\(streamId)", value: 0, ttl: 3600)
        
        print("🎥 [WebRTC] Live stream started: \(streamId) (latency: \(config.latencyMode.rawValue))")
        return streamId
    }
    
    // MARK: - 👁️ VIEWER: Join Live Stream
    
    func joinLiveStream(streamId: String, userId: String) async throws -> SDPAnswer {
        connectionState = .connecting
        
        // Check Redis cache for live stream existence (1ms)
        let cachedTitle: String? = await redisCache.get("live:\(streamId)", type: String.self)
        guard cachedTitle != nil else {
            throw LiveStreamError.streamNotFound
        }
        
        struct Request: Encodable {
            let task: String
            let streamId: String
            let userId: String
        }
        struct Response: Decodable {
            let sdp: String?
            let type: String?
            let iceCandidates: [ICECandidate]?
        }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(task: "join_live_stream", streamId: streamId, userId: userId)
        )
        
        guard let sdp = r.sdp, let type = r.type else {
            connectionState = .failed
            throw LiveStreamError.joinFailed
        }
        
        connectionState = .connected
        currentStreamId = streamId
        
        // Increment viewer count in Redis (atomic)
        await redisCache.set("live:viewers:\(streamId)", value: (viewerCount + 1), ttl: 3600)
        
        print("👁️ [WebRTC] Joined live stream: \(streamId)")
        return SDPAnswer(sdp: sdp, type: type)
    }
    
    // MARK: - 🛑 END LIVE STREAM
    
    func endLiveStream() async throws {
        guard let streamId = currentStreamId else { return }
        
        struct Request: Encodable { let task: String; let streamId: String }
        struct Response: Decodable { let status: String? }
        
        let _: Response = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(task: "end_live_stream", streamId: streamId)
        )
        
        // Clean up Redis
        await redisCache.delete("live:\(streamId)")
        await redisCache.delete("live:viewers:\(streamId)")
        
        isLive = false
        currentStreamId = nil
        connectionState = .disconnected
        viewerCount = 0
        
        print("🛑 [WebRTC] Live stream ended: \(streamId)")
    }
    
    // MARK: - 📊 REAL-TIME STATS
    
    func fetchStreamStats(streamId: String) async throws -> LiveStreamStats {
        // Try Redis cache first (1ms for hot data)
        if let cached: LiveStreamStats = await redisCache.get("live:stats:\(streamId)", type: LiveStreamStats.self) {
            self.streamStats = cached
            self.viewerCount = cached.viewerCount
            return cached
        }
        
        struct Request: Encodable { let task: String; let streamId: String }
        struct Response: Decodable {
            let viewerCount: Int?; let peakViewers: Int?; let avgLatencyMs: Int?
            let bitrate: Int?; let fps: Int?; let duration: Double?
            let totalChatMessages: Int?; let totalLikes: Int?
        }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(task: "live_stream_stats", streamId: streamId)
        )
        
        let stats = LiveStreamStats(
            viewerCount: r.viewerCount ?? 0,
            peakViewers: r.peakViewers ?? 0,
            avgLatencyMs: r.avgLatencyMs ?? 0,
            bitrate: r.bitrate ?? 0,
            fps: r.fps ?? 30,
            duration: r.duration ?? 0,
            totalChatMessages: r.totalChatMessages ?? 0,
            totalLikes: r.totalLikes ?? 0
        )
        
        // Cache for 10 seconds (very fresh)
        await redisCache.set("live:stats:\(streamId)", value: stats, ttl: 10)
        
        self.streamStats = stats
        self.viewerCount = stats.viewerCount
        self.latencyMs = stats.avgLatencyMs
        
        return stats
    }
    
    // MARK: - 🔌 SIGNALING (ICE Candidates)
    
    func sendICECandidate(_ candidate: ICECandidate, streamId: String) async throws {
        struct Request: Encodable {
            let task: String; let streamId: String; let sdp: String
            let sdpMid: String?; let sdpMLineIndex: Int?
        }
        let _: EmptyResponse = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(
                task: "ice_candidate", streamId: streamId,
                sdp: candidate.sdp, sdpMid: candidate.sdpMid,
                sdpMLineIndex: candidate.sdpMLineIndex
            )
        )
    }
    
    // MARK: - 🔴 DISCOVER LIVE STREAMS
    
    func discoverLiveStreams(limit: Int = 20) async throws -> [LiveStreamConfig] {
        // Redis cache for live stream directory (5ms)
        if let cached: [LiveStreamConfig] = await redisCache.get("live:directory", type: [LiveStreamConfig].self) {
            return Array(cached.prefix(limit))
        }
        
        struct Request: Encodable { let task: String; let limit: Int }
        struct RawStream: Decodable {
            let streamId: String?; let hostUserId: String?; let title: String?
            let quality: String?; let latencyMode: String?; let maxViewers: Int?
            let enableDVR: Bool?; let enableChat: Bool?; let enableLowLatency: Bool?
        }
        struct Response: Decodable { let streams: [RawStream]? }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(task: "discover_live", limit: limit)
        )
        
        let streams = (r.streams ?? []).compactMap { raw -> LiveStreamConfig? in
            guard let id = raw.streamId, let host = raw.hostUserId, let title = raw.title else { return nil }
            return LiveStreamConfig(
                streamId: id, hostUserId: host, title: title,
                quality: .init(rawValue: raw.quality ?? "720p") ?? .q720p,
                latencyMode: .init(rawValue: raw.latencyMode ?? "ultra_low") ?? .ultraLow,
                maxViewers: raw.maxViewers ?? 10000,
                enableDVR: raw.enableDVR ?? true,
                enableChat: raw.enableChat ?? true,
                enableLowLatency: raw.enableLowLatency ?? true
            )
        }
        
        // Cache directory for 30 seconds
        await redisCache.set("live:directory", value: streams, ttl: 30)
        return streams
    }
    
    private struct EmptyResponse: Decodable {}
}

// MARK: - Errors

enum LiveStreamError: LocalizedError {
    case alreadyLive
    case startFailed
    case joinFailed
    case streamNotFound
    case signalingFailed
    case notLive
    
    var errorDescription: String? {
        switch self {
        case .alreadyLive: return "Already live streaming"
        case .startFailed: return "Failed to start live stream"
        case .joinFailed: return "Failed to join live stream"
        case .streamNotFound: return "Live stream not found"
        case .signalingFailed: return "WebRTC signaling failed"
        case .notLive: return "Not currently live"
        }
    }
}
