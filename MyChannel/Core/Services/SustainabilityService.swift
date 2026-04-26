//
//  SustainabilityService.swift
//  MyChannel
//
//  Phase 119: Sustainability & Cost Efficiency.
//  Carbon-aware transcoding, media cache optimization, compute right-sizing.
//  Uses `auto-scaler` + `cdn-optimizer` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CarbonReport: Codable {
    let totalCO2Grams: Double
    let transcodingCO2: Double
    let storageCO2: Double
    let cdnCO2: Double
    let computeCO2: Double
    let periodStart: Date
    let periodEnd: Date
}

struct RightSizingRecommendation: Codable, Identifiable {
    let id: String
    let service: String
    let currentSize: String
    let recommendedSize: String
    let monthlySavingsUSD: Double
    let reason: String
}

struct CDNCacheOptimization: Codable {
    let currentHitRate: Double
    let projectedHitRate: Double
    let evictionCandidateCount: Int
    let estimatedSavingsGB: Double
}

struct TranscodeEfficiencyReport: Codable {
    let totalJobsAnalyzed: Int
    let avgCPUUtilization: Double
    let wastedComputePercent: Double
    let carbonAwareSchedulingEnabled: Bool
}

// MARK: - Service

@MainActor
final class SustainabilityService: ObservableObject {
    static let shared = SustainabilityService()
    private init() {}

    @Published private(set) var carbonReport: CarbonReport?
    @Published private(set) var rightSizingRecs: [RightSizingRecommendation] = []
    @Published private(set) var cacheOptimization: CDNCacheOptimization?
    @Published private(set) var transcodeEfficiency: TranscodeEfficiencyReport?

    func computeCarbonScore() async throws {
        guard AppConfig.Features.enableSustainability else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable {
            let total_co2: Double?; let transcode_co2: Double?; let storage_co2: Double?
            let cdn_co2: Double?; let compute_co2: Double?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "carbon_report")
        )
        carbonReport = CarbonReport(
            totalCO2Grams: r.total_co2 ?? 0,
            transcodingCO2: r.transcode_co2 ?? 0,
            storageCO2: r.storage_co2 ?? 0,
            cdnCO2: r.cdn_co2 ?? 0,
            computeCO2: r.compute_co2 ?? 0,
            periodStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            periodEnd: Date()
        )
    }

    func rightSizeCompute() async throws {
        guard AppConfig.Features.enableSustainability else { return }
        struct Request: Encodable { let task: String }
        struct RawRec: Decodable {
            let service: String; let current: String; let recommended: String
            let savings_usd: Double; let reason: String
        }
        struct Raw: Decodable { let recommendations: [RawRec]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "right_size")
        )
        rightSizingRecs = (r.recommendations ?? []).map {
            RightSizingRecommendation(id: UUID().uuidString, service: $0.service, currentSize: $0.current, recommendedSize: $0.recommended, monthlySavingsUSD: $0.savings_usd, reason: $0.reason)
        }
    }

    func optimizeMediaCache() async throws {
        guard AppConfig.Features.enableSustainability else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable { let hit_rate: Double?; let projected: Double?; let evictions: Int?; let savings_gb: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer,
            path: "/predict",
            body: Request(task: "cache_optimize")
        )
        cacheOptimization = CDNCacheOptimization(
            currentHitRate: r.hit_rate ?? 0,
            projectedHitRate: r.projected ?? 0,
            evictionCandidateCount: r.evictions ?? 0,
            estimatedSavingsGB: r.savings_gb ?? 0
        )
    }

    func analyzeTranscoding() async throws {
        guard AppConfig.Features.enableSustainability else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable { let jobs: Int?; let avg_cpu: Double?; let wasted: Double?; let carbon_aware: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "transcode_efficiency")
        )
        transcodeEfficiency = TranscodeEfficiencyReport(
            totalJobsAnalyzed: r.jobs ?? 0,
            avgCPUUtilization: r.avg_cpu ?? 0,
            wastedComputePercent: r.wasted ?? 0,
            carbonAwareSchedulingEnabled: r.carbon_aware ?? false
        )
    }
}
