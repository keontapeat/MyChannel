//
//  VideoPlaybackReadinessService.swift
//  MyChannel
//
//  Video playback readiness: pre-buffer check, quality selection,
//  stream health assessment. Uses `cdn-optimizer-v2` Cloud Run.
//

import Foundation

struct PlaybackReadiness: Codable {
    let videoId: String
    let isReady: Bool
    let recommendedQuality: String
    let bufferHealthPct: Double
    let estimatedStartDelayMs: Double
    let cdnRegion: String
}

struct StreamHealthCheck: Codable {
    let videoId: String
    let bitrate: Double
    let fps: Double
    let droppedFrames: Int
    let latencyMs: Double
    let status: StreamStatus
    enum StreamStatus: String, Codable { case excellent, good, degraded, poor }
}

@MainActor
final class VideoPlaybackReadinessService: ObservableObject {
    static let shared = VideoPlaybackReadinessService()
    private init() {}
    @Published private(set) var readiness: [String: PlaybackReadiness] = [:]

    func checkReadiness(videoId: String, userBandwidth: Double?) async throws -> PlaybackReadiness {
        struct Req: Encodable { let task: String; let videoId: String; let bandwidth: Double? }
        struct Raw: Decodable { let ready: Bool?; let quality: String?; let buffer: Double?; let delay: Double?; let region: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict",
            body: Req(task: "check_playback_readiness", videoId: videoId, bandwidth: userBandwidth))
        let result = PlaybackReadiness(videoId: videoId, isReady: r.ready ?? true,
            recommendedQuality: r.quality ?? "720p", bufferHealthPct: r.buffer ?? 100,
            estimatedStartDelayMs: r.delay ?? 0, cdnRegion: r.region ?? "us")
        readiness[videoId] = result; return result
    }

    func checkStreamHealth(videoId: String) async throws -> StreamHealthCheck {
        struct Req: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let bitrate: Double?; let fps: Double?; let dropped: Int?; let latency: Double?; let status: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict",
            body: Req(task: "check_stream_health", videoId: videoId))
        return StreamHealthCheck(videoId: videoId, bitrate: r.bitrate ?? 0, fps: r.fps ?? 30,
            droppedFrames: r.dropped ?? 0, latencyMs: r.latency ?? 0,
            status: .init(rawValue: r.status ?? "good") ?? .good)
    }

    func selectQuality(bandwidth: Double) -> String {
        switch bandwidth {
        case 0..<1_500_000: return "360p"
        case 1_500_000..<3_000_000: return "480p"
        case 3_000_000..<6_000_000: return "720p"
        case 6_000_000..<15_000_000: return "1080p"
        default: return "1080p"
        }
    }
}
