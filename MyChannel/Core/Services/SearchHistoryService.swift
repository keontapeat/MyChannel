//
//  SearchHistoryService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI

// 🔥 YouTube-Parity Search History Service
// Manages search history with persistence and clear functionality
@MainActor
class SearchHistoryService: ObservableObject {
    static let shared = SearchHistoryService()
    
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var isEnabled = true
    
    private let maxHistoryItems = 100
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    private let enabledKey = "search_history_enabled"
    
    private init() {
        loadSearchHistory()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Add search to history
    func addSearch(_ query: String, scope: SearchScope = .all) {
        guard isEnabled, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove existing entry if it exists
        searchHistory.removeAll { $0.query.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        let historyItem = SearchHistoryItem(
            id: UUID().uuidString,
            query: trimmedQuery,
            scope: scope,
            timestamp: Date()
        )
        
        searchHistory.insert(historyItem, at: 0)
        
        // Limit history size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    /// Remove specific search from history
    func removeSearch(_ item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveSearchHistory()
    }
    
    /// Clear all search history
    func clearAllHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    /// Toggle search history on/off
    func toggleHistoryEnabled() {
        isEnabled.toggle()
        userDefaults.set(isEnabled, forKey: enabledKey)
        
        if !isEnabled {
            clearAllHistory()
        }
    }
    
    /// Get recent searches (for suggestions)
    func getRecentSearches(limit: Int = 10) -> [String] {
        return Array(searchHistory.prefix(limit).map { $0.query })
    }
    
    /// Search within history
    func searchHistory(query: String) -> [SearchHistoryItem] {
        guard !query.isEmpty else { return searchHistory }
        
        let lowercased = query.lowercased()
        return searchHistory.filter { $0.query.lowercased().contains(lowercased) }
    }
    
    // MARK: - Private Methods
    
    private func loadSearchHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            return
        }
        
        searchHistory = decoded
    }
    
    private func saveSearchHistory() {
        guard let encoded = try? JSONEncoder().encode(searchHistory) else { return }
        userDefaults.set(encoded, forKey: historyKey)
    }
    
    private func loadSettings() {
        isEnabled = userDefaults.object(forKey: enabledKey) as? Bool ?? true
    }
}

// MARK: - Search History Item
struct SearchHistoryItem: Identifiable, Codable {
    let id: String
    let query: String
    let scope: SearchScope
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - SearchScope Codable Extension
extension SearchScope: Codable {}
