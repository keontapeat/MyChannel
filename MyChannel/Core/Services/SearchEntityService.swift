//
//  SearchEntityService.swift
//  MyChannel
//
//  Phase 289: Search Entity Recognition — creator resolution, topic extraction,
//  named entity linking, entity cards, knowledge graph queries.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

struct SearchEntity: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let confidence: Double
    let linkedId: String?
    let summary: String?
}

@MainActor
final class SearchEntityService: ObservableObject {
    static let shared = SearchEntityService()
    private init() {}

    @Published private(set) var entities: [SearchEntity] = []

    func extract(from query: String) async throws {
        guard AppConfig.Features.enableSearchEntity else { return }
        struct Req: Encodable { let task: String; let query: String }
        struct RawE: Decodable { let name: String; let type: String; let confidence: Double; let linkedId: String?; let summary: String? }
        struct Raw: Decodable { let entities: [RawE]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict", body: Req(task: "search_entities", query: query))
        entities = (r.entities ?? []).map {
            SearchEntity(id: UUID().uuidString, name: $0.name, type: $0.type, confidence: $0.confidence, linkedId: $0.linkedId, summary: $0.summary)
        }
    }

    func topEntity() -> SearchEntity? {
        entities.max { $0.confidence < $1.confidence }
    }
}
