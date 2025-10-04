import Foundation
import NaturalLanguage

protocol QueryProcessing {
    func processQuery(_ query: String) async -> ProcessedQuery
    func processNaturalLanguageQuery(_ query: String) async -> ProcessedQuery
    func inferFilters(from query: String) async -> SearchFilters
}

final class DefaultQueryProcessor: QueryProcessing {
    func processQuery(_ query: String) async -> ProcessedQuery {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = cleanedQuery.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])
        let filteredTerms = terms.filter { !stopWords.contains($0) && !$0.isEmpty }
        return ProcessedQuery(originalQuery: query, terms: filteredTerms, searchTerms: filteredTerms.joined(separator: " "))
    }

    func processNaturalLanguageQuery(_ query: String) async -> ProcessedQuery {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        var entities: [String] = []
        var keywords: [String] = []
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag != nil { entities.append(String(query[tokenRange])) }
            return true
        }
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, [.noun, .verb, .adjective].contains(tag) { keywords.append(String(query[tokenRange])) }
            return true
        }
        let combinedTerms = Array(Set(entities + keywords)).filter { !$0.isEmpty }
        return ProcessedQuery(originalQuery: query, terms: combinedTerms, searchTerms: combinedTerms.joined(separator: " "))
    }

    func inferFilters(from query: String) async -> SearchFilters {
        var filters = SearchFilters()
        let q = query.lowercased()
        if q.contains("short") { filters.duration = .short }
        else if q.contains("long") { filters.duration = .long }
        if q.contains("today") || q.contains("recent") { filters.uploadDate = .today }
        else if q.contains("week") { filters.uploadDate = .thisWeek }
        else if q.contains("month") { filters.uploadDate = .thisMonth }
        let categoryKeywords: [String: VideoCategory] = [
            "music": .music, "gaming": .gaming, "education": .education, "news": .news, "sports": .sports, "comedy": .entertainment, "tech": .technology, "technology": .technology
        ]
        for (keyword, category) in categoryKeywords where q.contains(keyword) { filters.category = category; break }
        return filters
    }
}


