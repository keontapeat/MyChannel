//
//  SearchRelevanceEngineService.swift
//  MyChannel
//
//  Phase 286: Search Relevance Engine — BM25+ scoring, semantic similarity,
//  click-through feedback, relevance feedback loop, query expansion.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct SearchRelevanceResult: Codable, Identifiable {
    let id: String
    let contentId: String
    let lexicalScore: Double
    let semanticScore: Double
    let feedbackBoost: Double
    let finalScore: Double
    let explanation: String
}

@MainActor
final class SearchRelevanceEngineService: ObservableObject {
    static let shared = SearchRelevanceEngineService()
    private init() {}

    @Published private(set) var results: [SearchRelevanceResult] = []
    @Published private(set) var expandedTerms: [String] = []

    func rank(query: String, candidateIds: [String]) async throws {
        guard AppConfig.Features.enableSearchRelevanceEngine else { return }
        struct Req: Encodable { let task: String; let query: String; let candidates: [String] }
        struct RawR: Decodable { let id: String; let contentId: String; let lexical: Double; let semantic: Double; let feedback: Double; let finalScore: Double; let explanation: String }
        struct Raw: Decodable { let results: [RawR]?; let expanded: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Req(task: "search_relevance_rank", query: query, candidates: candidateIds), timeout: 30
        )
        results = (r.results ?? []).map {
            SearchRelevanceResult(id: $0.id, contentId: $0.contentId, lexicalScore: $0.lexical, semanticScore: $0.semantic, feedbackBoost: $0.feedback, finalScore: $0.finalScore, explanation: $0.explanation)
        }
        expandedTerms = r.expanded ?? []
    }

    func topContentIds(limit: Int = 20) -> [String] {
        Array(results.sorted { $0.finalScore > $1.finalScore }.prefix(limit).map(\ .contentId))
    }
}
