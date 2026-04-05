//
//  SearchHistoryService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 🔥 YouTube-Parity Search History Service
// Manages search history with local UserDefaults cache + Firestore cross-device sync
@MainActor
class SearchHistoryService: ObservableObject {
    static let shared = SearchHistoryService()
    
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var isEnabled = true
    
    private let maxHistoryItems = 100
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    private let enabledKey = "search_history_enabled"
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif
    
    private init() {
        loadSearchHistory()
        loadSettings()
    }
    
    // MARK: - Firestore Sync
    
    /// Start listening for cross-device search history updates
    func startListening(userId: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = db.collection("users").document(userId).collection("search_history")
            .order(by: "timestamp", descending: true)
            .limit(to: maxHistoryItems)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let docs = snap?.documents else { return }
                let cloudItems: [SearchHistoryItem] = docs.compactMap { doc in
                    let d = doc.data()
                    guard let query = d["query"] as? String,
                          let ts = (d["timestamp"] as? Timestamp)?.dateValue() else { return nil }
                    let scopeRaw = d["scope"] as? String ?? "all"
                    return SearchHistoryItem(
                        id: doc.documentID,
                        query: query,
                        scope: SearchScope(rawValue: scopeRaw) ?? .all,
                        timestamp: ts
                    )
                }
                // Merge: cloud is source of truth
                Task { @MainActor in
                    self.searchHistory = cloudItems
                    self.saveSearchHistoryLocal()
                }
            }
        #endif
    }
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }
    
    private func syncToFirestore(_ item: SearchHistoryItem) {
        #if canImport(FirebaseFirestore)
        guard let uid = AppState.shared.currentUser?.id, !uid.isEmpty else { return }
        let ref = db.collection("users").document(uid).collection("search_history").document(item.id)
        ref.setData([
            "query": item.query,
            "scope": String(describing: item.scope),
            "timestamp": Timestamp(date: item.timestamp)
        ]) { error in
            if let error = error { print("⚠️ [SearchHistory] Firestore sync error: \(error.localizedDescription)") }
        }
        #endif
    }
    
    private func deleteFromFirestore(_ itemId: String) {
        #if canImport(FirebaseFirestore)
        guard let uid = AppState.shared.currentUser?.id, !uid.isEmpty else { return }
        db.collection("users").document(uid).collection("search_history").document(itemId).delete()
        #endif
    }
    
    private func clearFirestoreHistory() {
        #if canImport(FirebaseFirestore)
        guard let uid = AppState.shared.currentUser?.id, !uid.isEmpty else { return }
        let ref = db.collection("users").document(uid).collection("search_history")
        ref.getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            let batch = self.db.batch()
            docs.forEach { batch.deleteDocument($0.reference) }
            batch.commit(completion: nil)
        }
        #endif
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
        
        saveSearchHistoryLocal()
        syncToFirestore(historyItem)
    }
    
    /// Remove specific search from history
    func removeSearch(_ item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveSearchHistoryLocal()
        deleteFromFirestore(item.id)
    }
    
    /// Clear all search history
    func clearAllHistory() {
        searchHistory.removeAll()
        saveSearchHistoryLocal()
        clearFirestoreHistory()
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
    
    private func saveSearchHistoryLocal() {
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
