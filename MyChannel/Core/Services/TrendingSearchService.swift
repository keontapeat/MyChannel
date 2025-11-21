//
//  TrendingSearchService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// 📈 Trending Search Service
// Tracks and provides trending search terms in real-time
@MainActor
class TrendingSearchService: ObservableObject {
    static let shared = TrendingSearchService()
    
    @Published var trendingSearches: [TrendingSearch] = []
    @Published var isLoading = false
    
    private var listener: ListenerRegistration?
    
    private init() {
        startListening()
    }
    
    // Start real-time listener
    func startListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        
        listener = Firestore.firestore()
            .collection("trending_searches")
            .order(by: "searchCount", descending: true)
            .limit(to: 12)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("🚨 [TrendingSearch] Error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                Task { @MainActor in
                    self.trendingSearches = documents.compactMap { doc in
                        try? doc.data(as: TrendingSearch.self)
                    }
                }
            }
        #else
        // Mock data for preview/testing
        trendingSearches = [
            TrendingSearch(id: "1", term: "SwiftUI", searchCount: 1523, trendScore: 98.5, category: "Development"),
            TrendingSearch(id: "2", term: "iOS 17", searchCount: 1245, trendScore: 95.2, category: "Development"),
            TrendingSearch(id: "3", term: "Xcode", searchCount: 987, trendScore: 89.7, category: "Development"),
            TrendingSearch(id: "4", term: "macOS", searchCount: 876, trendScore: 85.3, category: "Development"),
            TrendingSearch(id: "5", term: "Flutter", searchCount: 654, trendScore: 78.9, category: "Development"),
            TrendingSearch(id: "6", term: "React", searchCount: 543, trendScore: 72.4, category: "Development")
        ]
        #endif
    }
    
    // Track a search (increment count)
    func trackSearch(term: String) async {
        #if canImport(FirebaseFirestore)
        let searchRef = Firestore.firestore()
            .collection("trending_searches")
            .document(term.lowercased().replacingOccurrences(of: " ", with: "_"))
        
        do {
            try await searchRef.setData([
                "term": term,
                "searchCount": FieldValue.increment(Int64(1)),
                "lastSearched": FieldValue.serverTimestamp(),
                "trendScore": 0.0 // Will be calculated by backend
            ], merge: true)
        } catch {
            print("🚨 [TrendingSearch] Failed to track: \(error)")
        }
        #endif
    }
    
    deinit {
        listener?.remove()
    }
}

// MARK: - Models
struct TrendingSearch: Identifiable, Codable {
    let id: String
    let term: String
    let searchCount: Int
    let trendScore: Double
    let category: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, term, searchCount, trendScore, category
    }
}




