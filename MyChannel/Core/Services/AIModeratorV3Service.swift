//
//  AIModeratorV3Service.swift
//  MyChannel
//
//  Phase 194: AI Content Moderator v3.
//  Nuanced context moderation, cultural sensitivity, appeal auto-review.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct V3ModerationResult: Codable, Identifiable {
    let id: String
    let contentId: String
    let contentType: String
    let decision: ModerationDecision
    let categories: [ModerationCategory]
    let culturalContext: String?
    let confidence: Double
    let requiresHumanReview: Bool
}

enum ModerationDecision: String, Codable { case approved, flagged, removed, ageRestricted, needsReview }

struct ModerationCategory: Codable, Identifiable {
    let id: String
    let name: String
    let score: Double
    let threshold: Double
}

// MARK: - Service

@MainActor
final class AIModeratorV3Service: ObservableObject {
    static let shared = AIModeratorV3Service()
    private init() {}

    @Published private(set) var recentDecisions: [V3ModerationResult] = []
    @Published var isProcessing: Bool = false

    func moderateContent(contentId: String, contentType: String, text: String? = nil) async throws -> V3ModerationResult {
        guard AppConfig.Features.enableAIModeratorV3 else {
            return V3ModerationResult(id: contentId, contentId: contentId, contentType: contentType,
                                  decision: .approved, categories: [], culturalContext: nil,
                                  confidence: 1, requiresHumanReview: false)
        }
        isProcessing = true; defer { isProcessing = false }
        struct Request: Encodable { let task: String; let contentId: String; let type: String; let text: String? }
        struct RawCat: Decodable { let name: String; let score: Double; let threshold: Double }
        struct Raw: Decodable { let decision: String?; let categories: [RawCat]?; let cultural: String?; let confidence: Double?; let human: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "moderate_v3", contentId: contentId, type: contentType, text: text), timeout: 15
        )
        let result = V3ModerationResult(
            id: UUID().uuidString, contentId: contentId, contentType: contentType,
            decision: ModerationDecision(rawValue: r.decision ?? "approved") ?? .approved,
            categories: (r.categories ?? []).map {
                ModerationCategory(id: UUID().uuidString, name: $0.name, score: $0.score, threshold: $0.threshold)
            },
            culturalContext: r.cultural, confidence: r.confidence ?? 1,
            requiresHumanReview: r.human ?? false
        )
        recentDecisions.append(result)
        return result
    }

    func autoReviewAppeal(appealId: String) async throws -> ModerationDecision {
        guard AppConfig.Features.enableAIModeratorV3 else { return .approved }
        struct Request: Encodable { let task: String; let appealId: String }
        struct Raw: Decodable { let decision: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "auto_review_appeal", appealId: appealId)
        )
        return ModerationDecision(rawValue: r.decision ?? "needsReview") ?? .needsReview
    }
}
