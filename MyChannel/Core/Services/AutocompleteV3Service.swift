//
//  AutocompleteV3Service.swift
//  MyChannel
//
//  Phase 282: Autocomplete V3 — prefix matching, semantic completion,
//  trending suggestions, personalized suggestions, zero-query suggestions.
//

import Foundation

struct AutocompleteSuggestion: Codable, Identifiable {
    let id: String
    let text: String
    let source: String
    let score: Double
}

@MainActor
final class AutocompleteV3Service: ObservableObject {
    static let shared = AutocompleteV3Service()
    private init() {}
    @Published private(set) var suggestions: [AutocompleteSuggestion] = []

    func fetch(query: String, userId: String?) async throws {
        guard AppConfig.Features.enableAutocompleteV3 else { return }
        struct Req: Encodable { let task: String; let query: String; let userId: String? }
        struct RawS: Decodable { let text: String; let source: String; let score: Double }
        struct Raw: Decodable { let suggestions: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict", body: Req(task: "autocomplete_v3", query: query, userId: userId))
        suggestions = (r.suggestions ?? []).map { AutocompleteSuggestion(id: UUID().uuidString, text: $0.text, source: $0.source, score: $0.score) }
    }
}
