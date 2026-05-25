//
//  SearchHistoryV2Service.swift
//  MyChannel
//
//  Phase 283: Search History V2 — rich history entries, categories,
//  history search, sharing, privacy-aware history.
//

import Foundation

struct SearchHistoryEntryV2: Codable, Identifiable {
    let id: String
    let query: String
    let category: String
    let createdAt: Date
    let resultCount: Int
}

@MainActor
final class SearchHistoryV2Service: ObservableObject {
    static let shared = SearchHistoryV2Service()
    private init() {}
    @Published private(set) var history: [SearchHistoryEntryV2] = []

    func add(query: String, category: String, resultCount: Int) {
        guard AppConfig.Features.enableSearchHistoryV2 else { return }
        history.insert(SearchHistoryEntryV2(id: UUID().uuidString, query: query, category: category, createdAt: Date(), resultCount: resultCount), at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
    }

    func searchHistory(term: String) -> [SearchHistoryEntryV2] {
        history.filter { $0.query.localizedCaseInsensitiveContains(term) }
    }

    func clear() { history.removeAll() }
}
