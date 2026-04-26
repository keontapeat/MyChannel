//
//  ContentProvenanceService.swift
//  MyChannel
//
//  Phase 189: Content Provenance & C2PA.
//  C2PA signing, origin tracking, deepfake detection.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProvenanceRecord: Codable, Identifiable {
    let id: String
    let videoId: String
    let originDevice: String
    let capturedAt: Date
    let editHistory: [EditStep]
    let c2paSignature: String?
    let isVerified: Bool
}

struct EditStep: Codable, Identifiable {
    let id: String
    let action: String
    let tool: String
    let timestamp: Date
}

struct ProvenanceDeepfakeAnalysis: Codable, Identifiable {
    let id: String
    let videoId: String
    let isDeepfake: Bool
    let confidence: Double
    let suspiciousRegions: [String]
    let analyzedAt: Date
}

// MARK: - Service

@MainActor
final class ContentProvenanceService: ObservableObject {
    static let shared = ContentProvenanceService()
    private init() {}

    @Published private(set) var provenance: ProvenanceRecord?
    @Published private(set) var deepfakeResult: ProvenanceDeepfakeAnalysis?

    func loadProvenance(videoId: String) async throws {
        guard AppConfig.Features.enableContentProvenance else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawEdit: Decodable { let action: String; let tool: String }
        struct Raw: Decodable { let device: String?; let signature: String?; let verified: Bool?; let edits: [RawEdit]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "provenance", videoId: videoId)
        )
        provenance = ProvenanceRecord(
            id: videoId, videoId: videoId, originDevice: r.device ?? "unknown",
            capturedAt: Date(), editHistory: (r.edits ?? []).map {
                EditStep(id: UUID().uuidString, action: $0.action, tool: $0.tool, timestamp: Date())
            },
            c2paSignature: r.signature, isVerified: r.verified ?? false
        )
    }

    func detectDeepfake(videoId: String) async throws -> ProvenanceDeepfakeAnalysis {
        guard AppConfig.Features.enableContentProvenance else {
            return ProvenanceDeepfakeAnalysis(id: videoId, videoId: videoId, isDeepfake: false, confidence: 0, suspiciousRegions: [], analyzedAt: Date())
        }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let deepfake: Bool?; let confidence: Double?; let regions: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "deepfake_detect", videoId: videoId), timeout: 30
        )
        let result = ProvenanceDeepfakeAnalysis(
            id: videoId, videoId: videoId, isDeepfake: r.deepfake ?? false,
            confidence: r.confidence ?? 0, suspiciousRegions: r.regions ?? [], analyzedAt: Date()
        )
        deepfakeResult = result
        return result
    }
}
