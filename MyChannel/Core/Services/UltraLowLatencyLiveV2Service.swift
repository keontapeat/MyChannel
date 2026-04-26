//
//  UltraLowLatencyLiveV2Service.swift
//  MyChannel
//
//  Phase 171: Ultra-Low Latency Live v2.
//  WebRTC fallback, sub-second latency, adaptive quality switching.
//  Uses `live-stream-optimizer-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct UltraLowLatencyLiveStreamConfig: Codable, Identifiable {
    let id: String
    let streamKey: String
    let rtmpURL: String
    let webrtcURL: String?
    let latencyMode: LatencyMode
    let maxBitrateMbps: Double
    let targetLatencyMs: Int
}

enum LatencyMode: String, Codable { case ultraLow, low, normal }

struct UltraLowLatencyLiveStreamStats: Codable {
    let viewerCount: Int
    let currentLatencyMs: Int
    let bitrateKbps: Int
    let droppedFrames: Int
    let protocol_: String
    let healthScore: Double
}

// MARK: - Service

@MainActor
final class UltraLowLatencyLiveV2Service: ObservableObject {
    static let shared = UltraLowLatencyLiveV2Service()
    private init() {}

    @Published private(set) var config: UltraLowLatencyLiveStreamConfig?
    @Published private(set) var stats = UltraLowLatencyLiveStreamStats(
        viewerCount: 0, currentLatencyMs: 0, bitrateKbps: 0, droppedFrames: 0, protocol_: "hls", healthScore: 1)
    @Published var isStreaming: Bool = false
    @Published var useWebRTC: Bool = false

    func createStream(creatorUid: String, latencyMode: LatencyMode) async throws -> UltraLowLatencyLiveStreamConfig {
        guard AppConfig.Features.enableUltraLowLatencyLiveV2 else {
            return UltraLowLatencyLiveStreamConfig(id: "", streamKey: "", rtmpURL: "", webrtcURL: nil, latencyMode: .normal, maxBitrateMbps: 6, targetLatencyMs: 3000)
        }
        struct Request: Encodable { let task: String; let creatorUid: String; let latency: String }
        struct Raw: Decodable { let stream_id: String?; let key: String?; let rtmp: String?; let webrtc: String?; let bitrate: Double?; let target_ms: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Request(task: "create_stream", creatorUid: creatorUid, latency: latencyMode.rawValue)
        )
        let cfg = UltraLowLatencyLiveStreamConfig(
            id: r.stream_id ?? UUID().uuidString, streamKey: r.key ?? "",
            rtmpURL: r.rtmp ?? "", webrtcURL: r.webrtc,
            latencyMode: latencyMode, maxBitrateMbps: r.bitrate ?? 6,
            targetLatencyMs: r.target_ms ?? 1000
        )
        config = cfg
        return cfg
    }

    func startStreaming() {
        guard AppConfig.Features.enableUltraLowLatencyLiveV2 else { return }
        isStreaming = true
    }

    func stopStreaming() {
        isStreaming = false
        config = nil
    }

    func optimizeQuality() async throws {
        guard AppConfig.Features.enableUltraLowLatencyLiveV2, isStreaming else { return }
        struct Request: Encodable { let task: String; let latency_ms: Int; let bitrate: Int; let dropped: Int }
        struct Raw: Decodable { let recommended_bitrate: Int?; let use_webrtc: Bool?; let health: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Request(task: "optimize_live", latency_ms: stats.currentLatencyMs, bitrate: stats.bitrateKbps, dropped: stats.droppedFrames)
        )
        useWebRTC = r.use_webrtc ?? false
    }
}
