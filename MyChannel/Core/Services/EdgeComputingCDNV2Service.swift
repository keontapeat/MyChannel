//
//  EdgeComputingCDNV2Service.swift
//  MyChannel
//
//  Phase 179: Edge Computing CDN v2.
//  Serverless edge functions, dynamic watermarking, geo-personalization.
//  Uses `cdn-optimizer` Cloud Run.
//

import Foundation

// MARK: - Models

struct EdgeNode: Codable, Identifiable {
    let id: String
    let region: String
    let city: String
    let latencyMs: Int
    let cacheHitRate: Double
    let isHealthy: Bool
}

struct WatermarkConfig: Codable {
    let enabled: Bool
    let text: String?
    let imageURL: URL?
    let position: String
    let opacity: Double
}

struct GeoPersonalization: Codable, Identifiable {
    let id: String
    let region: String
    let preferredCDN: String
    let language: String
    let contentRestrictions: [String]
}

// MARK: - Service

@MainActor
final class EdgeComputingCDNV2Service: ObservableObject {
    static let shared = EdgeComputingCDNV2Service()
    private init() {}

    @Published private(set) var nearestEdge: EdgeNode?
    @Published private(set) var allEdges: [EdgeNode] = []
    @Published var watermarkConfig = WatermarkConfig(enabled: false, text: nil, imageURL: nil, position: "bottomRight", opacity: 0.3)

    func findNearestEdge() async throws {
        guard AppConfig.Features.enableEdgeComputingCDNV2 else { return }
        struct Request: Encodable { let task: String }
        struct RawEdge: Decodable { let id: String; let region: String; let city: String; let latency: Int; let cache_hit: Double; let healthy: Bool }
        struct Raw: Decodable { let edges: [RawEdge]?; let nearest: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer, path: "/predict",
            body: Request(task: "find_edges")
        )
        allEdges = (r.edges ?? []).map {
            EdgeNode(id: $0.id, region: $0.region, city: $0.city,
                    latencyMs: $0.latency, cacheHitRate: $0.cache_hit, isHealthy: $0.healthy)
        }
        nearestEdge = allEdges.first { $0.id == r.nearest } ?? allEdges.min(by: { $0.latencyMs < $1.latencyMs })
    }

    func applyWatermark(videoId: String, config: WatermarkConfig) async throws -> URL? {
        guard AppConfig.Features.enableEdgeComputingCDNV2 else { return nil }
        struct Request: Encodable { let task: String; let videoId: String; let text: String?; let position: String; let opacity: Double }
        struct Raw: Decodable { let watermarked_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer, path: "/predict",
            body: Request(task: "watermark", videoId: videoId, text: config.text, position: config.position, opacity: config.opacity),
            timeout: 30
        )
        return r.watermarked_url.flatMap(URL.init(string:))
    }

    func geoPersonalize(videoId: String) async throws -> GeoPersonalization? {
        guard AppConfig.Features.enableEdgeComputingCDNV2 else { return nil }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let region: String?; let cdn: String?; let language: String?; let restrictions: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer, path: "/predict",
            body: Request(task: "geo_personalize", videoId: videoId)
        )
        return GeoPersonalization(id: UUID().uuidString, region: r.region ?? "",
                                 preferredCDN: r.cdn ?? "", language: r.language ?? "en",
                                 contentRestrictions: r.restrictions ?? [])
    }
}
