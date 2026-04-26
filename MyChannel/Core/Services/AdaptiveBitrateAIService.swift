//
//  AdaptiveBitrateAIService.swift
//  MyChannel
//
//  Phase 158: Adaptive Bitrate Intelligence.
//  ML-driven ABR, predictive buffer, network-aware quality.
//  Uses `cdn-optimizer` Cloud Run.
//

import Foundation
import Network

// MARK: - Models

struct NetworkCondition: Equatable {
    var bandwidth: Double       // Mbps estimated
    var latencyMs: Int
    var isExpensive: Bool       // cellular
    var isConstrained: Bool     // low data mode
    var connectionType: String  // "wifi", "cellular", "ethernet"
}

struct BitrateDecision: Codable, Identifiable {
    let id: String
    let recommendedQuality: String   // "360p", "720p", etc.
    let maxBitrateMbps: Double
    let bufferTargetSec: Double
    let reason: String
    let confidence: Double
}

struct BufferHealth: Equatable {
    var currentBufferSec: Double
    var targetBufferSec: Double
    var rebufferCount: Int
    var lastRebufferTime: Date?
}

// MARK: - Service

@MainActor
final class AdaptiveBitrateAIService: ObservableObject {
    static let shared = AdaptiveBitrateAIService()
    private init() {}

    @Published var network = NetworkCondition(bandwidth: 50, latencyMs: 30, isExpensive: false, isConstrained: false, connectionType: "wifi")
    @Published var lastDecision: BitrateDecision?
    @Published var bufferHealth = BufferHealth(currentBufferSec: 0, targetBufferSec: 10, rebufferCount: 0, lastRebufferTime: nil)
    @Published var isMonitoring: Bool = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "abr.monitor")

    func startMonitoring() {
        guard AppConfig.Features.enableAdaptiveBitrateAI else { return }
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.network.isExpensive = path.isExpensive
                self?.network.isConstrained = path.isConstrained
                if path.usesInterfaceType(.wifi) { self?.network.connectionType = "wifi" }
                else if path.usesInterfaceType(.cellular) { self?.network.connectionType = "cellular" }
                else if path.usesInterfaceType(.wiredEthernet) { self?.network.connectionType = "ethernet" }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        monitor.cancel()
        isMonitoring = false
    }

    func decideBitrate(videoId: String) async throws -> BitrateDecision {
        guard AppConfig.Features.enableAdaptiveBitrateAI else {
            return BitrateDecision(id: "", recommendedQuality: "720p", maxBitrateMbps: 5, bufferTargetSec: 10, reason: "default", confidence: 1)
        }
        struct Request: Encodable { let task: String; let videoId: String; let bandwidth: Double; let latency: Int; let connection: String; let rebuffers: Int }
        struct Raw: Decodable { let quality: String?; let bitrate: Double?; let buffer: Double?; let reason: String?; let confidence: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer, path: "/predict",
            body: Request(task: "adaptive_bitrate", videoId: videoId, bandwidth: network.bandwidth,
                         latency: network.latencyMs, connection: network.connectionType,
                         rebuffers: bufferHealth.rebufferCount)
        )
        let decision = BitrateDecision(
            id: UUID().uuidString, recommendedQuality: r.quality ?? "720p",
            maxBitrateMbps: r.bitrate ?? 5, bufferTargetSec: r.buffer ?? 10,
            reason: r.reason ?? "", confidence: r.confidence ?? 0.8
        )
        lastDecision = decision
        bufferHealth.targetBufferSec = decision.bufferTargetSec
        return decision
    }

    func reportRebuffer() {
        bufferHealth.rebufferCount += 1
        bufferHealth.lastRebufferTime = Date()
    }

    func updateBufferLevel(_ seconds: Double) {
        bufferHealth.currentBufferSec = seconds
    }

    func estimateBandwidth(_ bytesReceived: Int64, durationSec: Double) {
        guard durationSec > 0 else { return }
        let mbps = Double(bytesReceived) * 8.0 / 1_000_000.0 / durationSec
        network.bandwidth = network.bandwidth * 0.7 + mbps * 0.3 // EWMA
    }
}
