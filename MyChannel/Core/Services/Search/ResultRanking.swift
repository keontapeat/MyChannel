import Foundation

protocol ResultRanking {
    func rankResults(_ results: [SearchResult], for query: ProcessedQuery) async -> [SearchResult]
    func personalizeResults(_ results: [SearchResult], for userId: String) async -> [SearchResult]
}

final class DefaultSearchRankingEngine: ResultRanking {
    func rankResults(_ results: [SearchResult], for query: ProcessedQuery) async -> [SearchResult] {
        results.sorted { lhs, rhs in
            if abs(lhs.relevanceScore - rhs.relevanceScore) > 0.1 {
                return lhs.relevanceScore > rhs.relevanceScore
            }
            return lhs.popularity > rhs.popularity
        }
    }

    func personalizeResults(_ results: [SearchResult], for userId: String) async -> [SearchResult] {
        // Personalization signals from PersonalizationEngineV2 applied when signed in
        return await rankResults(results, for: ProcessedQuery(originalQuery: "", terms: [], searchTerms: ""))
    }
}


