//
//  SearchSuggestionService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI

// 🤖 Search Suggestion Service
// Generates smart search suggestions using AI and fuzzy matching
@MainActor
class SearchSuggestionService: ObservableObject {
    static let shared = SearchSuggestionService()
    
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isGenerating = false
    
    private init() {}
    
    // Generate suggestions for query
    func generateSuggestions(for query: String) async -> [SearchSuggestion] {
        guard query.count >= 2 else { return [] }
        
        isGenerating = true
        defer { isGenerating = false }
        
        var suggestions: [SearchSuggestion] = []
        
        // 1. Parse search operators
        if query.contains(":") {
            suggestions.append(contentsOf: parseOperators(query))
        }
        
        // 2. Parse @ mentions
        if query.contains("@") {
            suggestions.append(contentsOf: parseChannelMentions(query))
        }
        
        // 3. Parse # hashtags
        if query.contains("#") {
            suggestions.append(contentsOf: parseHashtags(query))
        }
        
        // 4. Fuzzy match with recent searches
        suggestions.append(contentsOf: await fuzzyMatchRecentSearches(query))
        
        // 5. AI-generated suggestions (using Claude)
        suggestions.append(contentsOf: await generateAISuggestions(query))
        
        // 6. Trending suggestions
        suggestions.append(contentsOf: await matchTrendingSearches(query))
        
        // Deduplicate and limit
        let uniqueSuggestions = Array(Set(suggestions))
        return Array(uniqueSuggestions.prefix(10))
    }
    
    // MARK: - Search Operators
    private func parseOperators(_ query: String) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        let operators = [
            "title:", "channel:", "date:", "duration:", "quality:", 
            "category:", "views:", "likes:", "live:", "premiere:"
        ]
        
        for op in operators {
            if query.lowercased().hasPrefix(op.lowercased()) {
                let example = query.replacingOccurrences(of: op, with: op + "example")
                suggestions.append(SearchSuggestion(
                    id: UUID().uuidString,
                    text: example,
                    subtitle: "Search by \(op.replacingOccurrences(of: ":", with: ""))",
                    icon: "magnifyingglass",
                    isAIGenerated: false,
                    score: 1.0
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - Channel Mentions
    private func parseChannelMentions(_ query: String) -> [SearchSuggestion] {
        guard query.contains("@") else { return [] }
        
        // Extract @mention
        let components = query.components(separatedBy: "@")
        guard components.count > 1 else { return [] }
        
        let mention = components.last ?? ""
        
        // Generate suggestions
        return [
            SearchSuggestion(
                id: UUID().uuidString,
                text: "@\(mention)",
                subtitle: "Search videos from @\(mention)",
                icon: "person.circle.fill",
                isAIGenerated: false,
                score: 0.9
            )
        ]
    }
    
    // MARK: - Hashtags
    private func parseHashtags(_ query: String) -> [SearchSuggestion] {
        guard query.contains("#") else { return [] }
        
        // Extract #hashtag
        let components = query.components(separatedBy: "#")
        guard components.count > 1 else { return [] }
        
        let hashtag = components.last ?? ""
        
        return [
            SearchSuggestion(
                id: UUID().uuidString,
                text: "#\(hashtag)",
                subtitle: "Search by hashtag",
                icon: "number",
                isAIGenerated: false,
                score: 0.9
            )
        ]
    }
    
    // MARK: - Fuzzy Match
    private func fuzzyMatchRecentSearches(_ query: String) async -> [SearchSuggestion] {
        // Load recent searches from UserDefaults
        guard let recentSearches = UserDefaults.standard.array(forKey: "recent_searches") as? [String] else {
            return []
        }
        
        // Fuzzy match
        return recentSearches
            .filter { $0.lowercased().contains(query.lowercased()) }
            .prefix(3)
            .map { search in
                SearchSuggestion(
                    id: UUID().uuidString,
                    text: search,
                    subtitle: "Recent search",
                    icon: "clock.arrow.circlepath",
                    isAIGenerated: false,
                    score: 0.8
                )
            }
    }
    
    // MARK: - AI Suggestions (Claude)
    private func generateAISuggestions(_ query: String) async -> [SearchSuggestion] {
        // Only generate AI suggestions for queries 3+ characters
        guard query.count >= 3 else { return [] }
        
        // Use Claude to generate smart suggestions
        let prompt = """
        Given the search query: "\(query)"
        
        Generate 3 smart search suggestions that a user might be looking for.
        Consider:
        - Related topics
        - Common misspellings
        - Similar queries
        - Popular variations
        
        Return only the suggestions, one per line, no explanations.
        """
        
        do {
            // TODO: Integrate with AI service (Claude/OpenAI) for AI-powered suggestions
            // For now, return empty array until ClaudeService is implemented
            return []
            
            // Commented out until ClaudeService is available:
            // let suggestions = try await ClaudeService.shared.generateText(prompt: prompt)
            // let lines = suggestions.components(separatedBy: "\n")
            //     .filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
            //     .prefix(3)
            // 
            // return lines.map { suggestion in
            //     SearchSuggestion(
            //         id: UUID().uuidString,
            //         text: suggestion.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            //         subtitle: "AI suggestion",
            //         icon: "sparkles",
            //         isAIGenerated: true,
            //         score: 0.95
            //     )
            // }
        } catch {
            print("🚨 [AI Suggestions] Error: \(error)")
            return []
        }
    }
    
    // MARK: - Trending Matches
    private func matchTrendingSearches(_ query: String) async -> [SearchSuggestion] {
        let trending = await TrendingSearchService.shared.trendingSearches
        
        return trending
            .filter { $0.term.lowercased().contains(query.lowercased()) }
            .prefix(2)
            .map { trend in
                SearchSuggestion(
                    id: trend.id,
                    text: trend.term,
                    subtitle: "Trending · \(trend.searchCount) searches",
                    icon: "chart.line.uptrend.xyaxis",
                    isAIGenerated: false,
                    score: 0.85
                )
            }
    }
}

// MARK: - Models
struct SearchSuggestion: Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
    let icon: String
    let isAIGenerated: Bool
    let score: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text.lowercased())
    }
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        lhs.text.lowercased() == rhs.text.lowercased()
    }
}

