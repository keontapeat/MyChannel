import Foundation

protocol AutoCompleteProviding {
    func generateSuggestions(query: String, userId: String?, maxSuggestions: Int) async -> [SearchSuggestion]
    func getTrendingSearches(limit: Int) async -> [TrendingSearch]
}

final class DefaultAutoCompleteService: AutoCompleteProviding {
    func generateSuggestions(query: String, userId: String?, maxSuggestions: Int) async -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        let completions = [
            query + " tutorial",
            query + " review",
            query + " music",
            query + " funny",
            query + " 2024"
        ].prefix(maxSuggestions / 2)
        for completion in completions {
            suggestions.append(SearchSuggestion(id: UUID().uuidString, text: completion, subtitle: nil, icon: "magnifyingglass", isAIGenerated: false, score: 0.8))
        }
        let related = ["best " + query, query + " tips", "how to " + query, query + " guide"].prefix(maxSuggestions - suggestions.count)
        for relatedQuery in related {
            suggestions.append(SearchSuggestion(id: UUID().uuidString, text: relatedQuery, subtitle: nil, icon: "star.fill", isAIGenerated: true, score: 0.9))
        }
        return suggestions
    }

    func getTrendingSearches(limit: Int) async -> [TrendingSearch] {
        [
            TrendingSearch(id: UUID().uuidString, term: "funny cats", searchCount: 12000, trendScore: 1.2, category: "Entertainment"),
            TrendingSearch(id: UUID().uuidString, term: "cooking tutorial", searchCount: 8500, trendScore: 0.05, category: "Food"),
            TrendingSearch(id: UUID().uuidString, term: "new music", searchCount: 9800, trendScore: 0.8, category: "Music"),
            TrendingSearch(id: UUID().uuidString, term: "gaming", searchCount: 15200, trendScore: -0.15, category: "Gaming"),
            TrendingSearch(id: UUID().uuidString, term: "tech review", searchCount: 7300, trendScore: 0.45, category: "Technology")
        ].prefix(limit).map { $0 }
    }
}


