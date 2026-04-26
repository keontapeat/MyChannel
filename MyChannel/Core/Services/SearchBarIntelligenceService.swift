//
//  SearchBarIntelligenceService.swift
//  MyChannel
//
//  Phase 281: Search Bar Intelligence — smart placeholder text,
//  search intent detection, auto-correction, type switching.
//

import Foundation

struct SearchIntent: Codable {
    let type: String
    let confidence: Double
    let correctedQuery: String?
}

@MainActor
final class SearchBarIntelligenceService: ObservableObject {
    static let shared = SearchBarIntelligenceService()
    private init() {}
    @Published private(set) var placeholder: String = "Search videos, creators, live"
    @Published private(set) var lastIntent: SearchIntent?

    func updatePlaceholder(timeOfDay: String) {
        guard AppConfig.Features.enableSearchBarIntelligence else { return }
        placeholder = timeOfDay == "night" ? "Search relaxing videos, live streams" : "Search videos, creators, live"
    }

    func detectIntent(query: String) async throws {
        struct Req: Encodable { let task: String; let query: String }
        struct Raw: Decodable { let type: String; let confidence: Double; let corrected: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict", body: Req(task: "search_intent", query: query))
        lastIntent = SearchIntent(type: r.type, confidence: r.confidence, correctedQuery: r.corrected)
    }
}
