//
//  BrandSafetyService.swift
//  MyChannel
//
//  Phase 169: Brand Safety Suite.
//  Advertiser controls, content classification, brand suitability scores.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct BrandSafetyScore: Codable, Identifiable {
    let id: String        // videoId
    let overallScore: Double
    let categories: [ContentCategory]
    let flags: [SafetyFlag]
    let suitabilityTier: String
}

struct ContentCategory: Codable, Identifiable {
    let id: String
    let name: String
    let confidence: Double
    let isSensitive: Bool
}

struct SafetyFlag: Codable, Identifiable {
    let id: String
    let type: String
    let severity: String
    let timestampSec: Double?
    let description: String
}

struct AdvertiserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let blockedCategories: [String]
    let minSafetyScore: Double
    let preferredTier: String
}

// MARK: - Service

@MainActor
final class BrandSafetyService: ObservableObject {
    static let shared = BrandSafetyService()
    private init() {}

    @Published private(set) var safetyScore: BrandSafetyScore?
    @Published private(set) var isScanning: Bool = false

    func analyzeContent(videoId: String) async throws -> BrandSafetyScore {
        guard AppConfig.Features.enableBrandSafety else {
            return BrandSafetyScore(id: videoId, overallScore: 1, categories: [], flags: [], suitabilityTier: "standard")
        }
        isScanning = true
        defer { isScanning = false }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawCat: Decodable { let name: String; let confidence: Double; let sensitive: Bool }
        struct RawFlag: Decodable { let type: String; let severity: String; let timestamp: Double?; let desc: String }
        struct Raw: Decodable { let score: Double?; let categories: [RawCat]?; let flags: [RawFlag]?; let tier: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "brand_safety", videoId: videoId), timeout: 30
        )
        let result = BrandSafetyScore(
            id: videoId, overallScore: r.score ?? 1,
            categories: (r.categories ?? []).map {
                ContentCategory(id: UUID().uuidString, name: $0.name, confidence: $0.confidence, isSensitive: $0.sensitive)
            },
            flags: (r.flags ?? []).map {
                SafetyFlag(id: UUID().uuidString, type: $0.type, severity: $0.severity, timestampSec: $0.timestamp, description: $0.desc)
            },
            suitabilityTier: r.tier ?? "standard"
        )
        safetyScore = result
        return result
    }

    func isSuitableForAdvertiser(videoId: String, advertiser: AdvertiserProfile) -> Bool {
        guard let score = safetyScore, score.id == videoId else { return false }
        return score.overallScore >= advertiser.minSafetyScore
    }
}
