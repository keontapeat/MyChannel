import Foundation

protocol AutoCompleteProviding {
    func generateSuggestions(query: String, userId: String?, maxSuggestions: Int) async -> [SearchSuggestion]
    func getTrendingSearches(limit: Int) async -> [TrendingSearch]
}

final class DefaultAutoCompleteService: AutoCompleteProviding {
    func generateSuggestions(query: String, userId: String?, maxSuggestions: Int) async -> [SearchSuggestion] {
        guard AppConfig.Features.enableAutocompleteV3 else { return [] }
        struct Req: Encodable { let task: String; let query: String; let userId: String?; let maxSuggestions: Int }
        struct RawS: Decodable { let text: String; let subtitle: String?; let icon: String?; let isAIGenerated: Bool; let score: Double }
        struct Raw: Decodable { let suggestions: [RawS]? }
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict", body: Req(task: "autocomplete_suggestions", query: query, userId: userId, maxSuggestions: maxSuggestions))
            return (r.suggestions ?? []).map {
                SearchSuggestion(id: UUID().uuidString, text: $0.text, subtitle: $0.subtitle, icon: $0.icon ?? "magnifyingglass", isAIGenerated: $0.isAIGenerated, score: $0.score)
            }
        } catch {
            return []
        }
    }

    func getTrendingSearches(limit: Int) async -> [TrendingSearch] {
        guard AppConfig.Features.enableAutocompleteV3 else { return [] }
        struct Req: Encodable { let task: String; let limit: Int }
        struct RawT: Decodable { let term: String; let searchCount: Int; let trendScore: Double; let category: String }
        struct Raw: Decodable { let trending: [RawT]? }
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict", body: Req(task: "trending_searches", limit: limit))
            return (r.trending ?? []).prefix(limit).map {
                TrendingSearch(id: UUID().uuidString, term: $0.term, searchCount: $0.searchCount, trendScore: $0.trendScore, category: $0.category)
            }
        } catch {
            return []
        }
    }
}


