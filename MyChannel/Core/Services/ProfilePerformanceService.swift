//
//  ProfilePerformanceService.swift
//  MyChannel
//
//  Phase 260: Profile Performance & Rendering Optimization.
//  Lazy image loading, diffable data sources, memory-efficient scrolling,
//  pre-warming, render pipeline optimization.
//  Uses `cdn-optimizer-v2` + `auto-scaler` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfilePerformanceMetrics: Codable {
    let creatorId: String
    let firstContentfulPaintMs: Double
    let timeToInteractiveMs: Double
    let memoryUsageMB: Double
    let scrollFPS: Double
    let imageCacheHitRate: Double
    let measuredAt: Date
}

struct PreWarmConfig: Codable {
    let creatorId: String
    let prefetchImageCount: Int
    let prefetchVideoCount: Int
    let cacheTTLSeconds: Int
    let enableDiffableDataSource: Bool
    let enableLazyImageLoading: Bool
}

struct RenderOptimization: Codable, Identifiable {
    let id: String
    let creatorId: String
    let technique: String
    let beforeMs: Double
    let afterMs: Double
    let appliedAt: Date
}

// MARK: - Service

@MainActor
final class ProfilePerformanceService: ObservableObject {
    static let shared = ProfilePerformanceService()
    private init() {}

    @Published private(set) var metrics: ProfilePerformanceMetrics?
    @Published private(set) var preWarmConfig: PreWarmConfig?
    @Published private(set) var optimizations: [RenderOptimization] = []

    func measurePerformance(creatorId: String) async throws {
        guard AppConfig.Features.enableProfilePerformance else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let fcp: Double?; let tti: Double?; let memory: Double?; let fps: Double?; let cache_hit: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizerv2, path: "/predict",
            body: Req(task: "measure_profile_performance", creatorId: creatorId)
        )
        metrics = ProfilePerformanceMetrics(creatorId: creatorId, firstContentfulPaintMs: r.fcp ?? 0,
                                              timeToInteractiveMs: r.tti ?? 0, memoryUsageMB: r.memory ?? 0,
                                              scrollFPS: r.fps ?? 60, imageCacheHitRate: r.cache_hit ?? 0, measuredAt: Date())
    }

    func fetchPreWarmConfig(creatorId: String) async throws {
        guard AppConfig.Features.enableProfilePerformance else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let prefetch_images: Int?; let prefetch_videos: Int?; let cache_ttl: Int?; let diffable: Bool?; let lazy_images: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizerv2, path: "/predict",
            body: Req(task: "fetch_prewarm_config", creatorId: creatorId)
        )
        preWarmConfig = PreWarmConfig(creatorId: creatorId, prefetchImageCount: r.prefetch_images ?? 6,
                                        prefetchVideoCount: r.prefetch_videos ?? 2, cacheTTLSeconds: r.cache_ttl ?? 3600,
                                        enableDiffableDataSource: r.diffable ?? true, enableLazyImageLoading: r.lazy_images ?? true)
    }

    func applyOptimization(creatorId: String, technique: String) async throws -> RenderOptimization {
        guard AppConfig.Features.enableProfilePerformance else {
            return RenderOptimization(id: "", creatorId: creatorId, technique: technique, beforeMs: 0, afterMs: 0, appliedAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let technique: String }
        struct Raw: Decodable { let id: String; let before: Double?; let after: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "apply_render_optimization", creatorId: creatorId, technique: technique)
        )
        let opt = RenderOptimization(id: r.id, creatorId: creatorId, technique: technique,
                                       beforeMs: r.before ?? 0, afterMs: r.after ?? 0, appliedAt: Date())
        optimizations.append(opt)
        return opt
    }

    func fetchOptimalImageSize(creatorId: String, viewWidth: CGFloat) async throws -> String {
        guard AppConfig.Features.enableProfilePerformance else { return "medium" }
        struct Req: Encodable { let task: String; let creatorId: String; let width: Double }
        struct Raw: Decodable { let size: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizerv2, path: "/predict",
            body: Req(task: "fetch_optimal_image_size", creatorId: creatorId, width: Double(viewWidth))
        )
        return r.size ?? "medium"
    }
}
