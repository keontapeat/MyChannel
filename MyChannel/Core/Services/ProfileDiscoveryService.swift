//
//  ProfileDiscoveryService.swift
//  MyChannel
//
//  Phase 248: Similar Channels & Creator Discovery.
//  "Similar creators" recommendations, genre-based discovery,
//  collab suggestions, audience overlap analysis.
//  Uses `audience-segmentation-ai` + `creator-discovery-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct SimilarCreator: Codable, Identifiable {
    let id: String
    let creatorId: String
    let displayName: String
    let username: String
    let profileImageURL: String?
    let subscriberCount: Int
    let similarityScore: Double
    let overlapPct: Double
    let primaryCategory: String
}

struct CollabSuggestion: Codable, Identifiable {
    let id: String
    let creatorA: String
    let creatorB: String
    let reason: String
    let potentialReach: Int
    let confidence: Double
}

// MARK: - Service

@MainActor
final class ProfileDiscoveryService: ObservableObject {
    static let shared = ProfileDiscoveryService()
    private init() {}

    @Published private(set) var similarCreators: [SimilarCreator] = []
    @Published private(set) var collabSuggestions: [CollabSuggestion] = []

    func fetchSimilarCreators(creatorId: String, limit: Int = 10) async throws {
        guard AppConfig.Features.enableProfileDiscovery else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let limit: Int }
        struct RawC: Decodable { let id: String; let name: String; let username: String; let image: String?; let subs: Int; let similarity: Double; let overlap: Double; let category: String }
        struct Raw: Decodable { let creators: [RawC]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorDiscoveryAI, path: "/predict",
            body: Req(task: "fetch_similar_creators", creatorId: creatorId, limit: limit)
        )
        similarCreators = (r.creators ?? []).map {
            SimilarCreator(id: $0.id, creatorId: $0.id, displayName: $0.name, username: $0.username,
                           profileImageURL: $0.image, subscriberCount: $0.subs,
                           similarityScore: $0.similarity, overlapPct: $0.overlap, primaryCategory: $0.category)
        }
    }

    func fetchCollabSuggestions(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileDiscovery else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawS: Decodable { let id: String; let creator_a: String; let creator_b: String; let reason: String; let reach: Int; let confidence: Double }
        struct Raw: Decodable { let suggestions: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Req(task: "fetch_collab_suggestions", creatorId: creatorId), timeout: 30
        )
        collabSuggestions = (r.suggestions ?? []).map {
            CollabSuggestion(id: $0.id, creatorA: $0.creator_a, creatorB: $0.creator_b,
                             reason: $0.reason, potentialReach: $0.reach, confidence: $0.confidence)
        }
    }

    func fetchAudienceOverlap(creatorA: String, creatorB: String) async throws -> Double {
        guard AppConfig.Features.enableProfileDiscovery else { return 0 }
        struct Req: Encodable { let task: String; let creatorA: String; let creatorB: String }
        struct Raw: Decodable { let overlap: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Req(task: "fetch_audience_overlap", creatorA: creatorA, creatorB: creatorB)
        )
        return r.overlap ?? 0
    }
}
