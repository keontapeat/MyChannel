//
//  AuthenticityGraphService.swift
//  MyChannel
//
//  Phase 237: Trust & Authenticity Graph.
//  Creator verification, provenance confidence, impersonation detection,
//  AI-generated asset labeling.
//  Uses `trust-safety-ai` + `deepfake-detector-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct AuthenticityScore: Codable, Identifiable {
    let id: String
    let entityId: String
    let entityType: EntityType
    let overallScore: Double
    let provenanceConfidence: Double
    let isVerified: Bool
    let flags: [String]
    let checkedAt: Date

    enum EntityType: String, Codable { case creator, video, image, audio }
}

struct ImpersonationMatch: Codable, Identifiable {
    let id: String
    let suspectId: String
    let realId: String
    let similarity: Double
    let status: String
    let detectedAt: Date
}

struct AILabelResult: Codable, Identifiable {
    let id: String
    let assetId: String
    let assetType: String
    let isAIGenerated: Bool
    let confidence: Double
    let model: String
    let labeledAt: Date
}

// MARK: - Service

@MainActor
final class AuthenticityGraphService: ObservableObject {
    static let shared = AuthenticityGraphService()
    private init() {}

    @Published private(set) var scores: [AuthenticityScore] = []
    @Published private(set) var impersonations: [ImpersonationMatch] = []
    @Published private(set) var aiLabels: [AILabelResult] = []

    func checkAuthenticity(entityId: String, type: AuthenticityScore.EntityType) async throws -> AuthenticityScore {
        guard AppConfig.Features.enableAuthenticityGraph else {
            return AuthenticityScore(id: "", entityId: entityId, entityType: type, overallScore: 0,
                                      provenanceConfidence: 0, isVerified: false, flags: [], checkedAt: Date())
        }
        struct Req: Encodable { let task: String; let entityId: String; let type: String }
        struct Raw: Decodable { let id: String; let score: Double?; let provenance: Double?; let verified: Bool?; let flags: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Req(task: "check_authenticity", entityId: entityId, type: type.rawValue)
        )
        let result = AuthenticityScore(id: r.id, entityId: entityId, entityType: type,
                                        overallScore: r.score ?? 0, provenanceConfidence: r.provenance ?? 0,
                                        isVerified: r.verified ?? false, flags: r.flags ?? [], checkedAt: Date())
        scores.append(result)
        return result
    }

    func detectImpersonation(creatorId: String) async throws {
        guard AppConfig.Features.enableAuthenticityGraph else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawImp: Decodable { let id: String; let suspect: String; let real: String; let similarity: Double; let status: String; let detected: String? }
        struct Raw: Decodable { let matches: [RawImp]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Req(task: "detect_impersonation", creatorId: creatorId), timeout: 30
        )
        impersonations = (r.matches ?? []).map {
            ImpersonationMatch(id: $0.id, suspectId: $0.suspect, realId: $0.real, similarity: $0.similarity,
                                status: $0.status, detectedAt: $0.detected.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }

    func labelAIAsset(assetId: String, assetType: String) async throws -> AILabelResult {
        guard AppConfig.Features.enableAuthenticityGraph else {
            return AILabelResult(id: "", assetId: assetId, assetType: assetType, isAIGenerated: false, confidence: 0, model: "", labeledAt: Date())
        }
        struct Req: Encodable { let task: String; let assetId: String; let assetType: String }
        struct Raw: Decodable { let id: String; let ai: Bool?; let confidence: Double?; let model: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .deepfakeDetector, path: "/predict",
            body: Req(task: "label_ai_asset", assetId: assetId, assetType: assetType), timeout: 30
        )
        let result = AILabelResult(id: r.id, assetId: assetId, assetType: assetType,
                                    isAIGenerated: r.ai ?? false, confidence: r.confidence ?? 0,
                                    model: r.model ?? "", labeledAt: Date())
        aiLabels.append(result)
        return result
    }
}
