//
//  SearchFiltersV3Service.swift
//  MyChannel
//
//  Phase 284: Search Filters V3 — advanced combinations, presets,
//  persistence, suggestions, explainability.
//

import Foundation

struct SearchFilterPreset: Codable, Identifiable {
    let id: String
    let name: String
    let filters: [String: String]
}

@MainActor
final class SearchFiltersV3Service: ObservableObject {
    static let shared = SearchFiltersV3Service()
    private init() {}
    @Published private(set) var activeFilters: [String: String] = [:]
    @Published private(set) var presets: [SearchFilterPreset] = []

    func setFilter(key: String, value: String) {
        guard AppConfig.Features.enableSearchFiltersV3 else { return }
        activeFilters[key] = value
    }

    func clearFilter(key: String) { activeFilters.removeValue(forKey: key) }
    func clearAll() { activeFilters.removeAll() }

    func savePreset(name: String) {
        presets.append(SearchFilterPreset(id: UUID().uuidString, name: name, filters: activeFilters))
    }
}
