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
            suggestions.append(SearchSuggestion(type: .queryCompletion, text: completion, highlightRange: 0..<query.count))
        }
        let related = ["best " + query, query + " tips", "how to " + query, query + " guide"].prefix(maxSuggestions - suggestions.count)
        for relatedQuery in related {
            suggestions.append(SearchSuggestion(type: .relatedSearch, text: relatedQuery, highlightRange: nil))
        }
        return suggestions
    }

    func getTrendingSearches(limit: Int) async -> [TrendingSearch] {
        [
            TrendingSearch(query: "funny cats", trend: .rising, changePercentage: 120),
            TrendingSearch(query: "cooking tutorial", trend: .stable, changePercentage: 5),
            TrendingSearch(query: "new music", trend: .rising, changePercentage: 80),
            TrendingSearch(query: "gaming", trend: .falling, changePercentage: -15),
            TrendingSearch(query: "tech review", trend: .rising, changePercentage: 45)
        ].prefix(limit).map { $0 }
    }
}


