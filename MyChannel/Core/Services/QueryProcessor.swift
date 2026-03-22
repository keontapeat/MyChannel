//
//  QueryProcessor.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import NaturalLanguage

// 🔥 YouTube-Parity Query Processor
// Handles all YouTube search operators and advanced query parsing
class QueryProcessor {
    
    // MARK: - Search Operators
    
    /// Process query with YouTube-style operators
    func processQuery(_ query: String) async -> ProcessedQuery {
        let originalQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse operators
        let parsedQuery = parseSearchOperators(originalQuery)
        
        // Extract search terms (excluding operators)
        let searchTerms = extractSearchTerms(from: parsedQuery)
        
        // Tokenize remaining terms
        let terms = tokenizeQuery(searchTerms)
        
        return ProcessedQuery(
            originalQuery: originalQuery,
            terms: terms,
            searchTerms: searchTerms,
            operators: parsedQuery.operators,
            filters: parsedQuery.inferredFilters
        )
    }
    
    /// Process natural language queries
    func processNaturalLanguageQuery(_ query: String) async -> ProcessedQuery {
        let baseQuery = await processQuery(query)
        
        // Use NLP to understand intent
        let intent = analyzeQueryIntent(query)
        let entities = extractEntities(from: query)
        
        return ProcessedQuery(
            originalQuery: baseQuery.originalQuery,
            terms: baseQuery.terms,
            searchTerms: baseQuery.searchTerms,
            operators: baseQuery.operators,
            filters: baseQuery.filters,
            intent: intent,
            entities: entities
        )
    }
    
    /// Infer filters from natural language
    func inferFilters(from query: String) async -> SearchFilters {
        var filters = SearchFilters()
        let lowercased = query.lowercased()
        
        // Duration inference
        if lowercased.contains("short") || lowercased.contains("brief") {
            filters.duration = .short
        } else if lowercased.contains("long") {
            filters.duration = .long
        }
        
        // Upload date inference
        if lowercased.contains("today") || lowercased.contains("recent") {
            filters.uploadDate = .today
        } else if lowercased.contains("this week") {
            filters.uploadDate = .thisWeek
        } else if lowercased.contains("this month") {
            filters.uploadDate = .thisMonth
        }
        
        // Content type inference
        if lowercased.contains("channel") || lowercased.contains("creator") {
            filters.contentType = .channel
        } else if lowercased.contains("playlist") {
            filters.contentType = .playlist
        } else if lowercased.contains("live") || lowercased.contains("streaming") {
            filters.contentType = .live
        }
        
        // Feature inference
        if lowercased.contains("4k") {
            filters.features.insert(.fourK)
        }
        if lowercased.contains("hd") || lowercased.contains("high definition") {
            filters.features.insert(.hd)
        }
        if lowercased.contains("subtitle") || lowercased.contains("cc") {
            filters.features.insert(.subtitles)
        }
        
        return filters
    }
    
    // MARK: - Private Methods
    
    private func parseSearchOperators(_ query: String) -> ParsedQuery {
        var operators: [SearchOperator] = []
        var remainingQuery = query
        var inferredFilters = SearchFilters()
        
        // Parse quoted phrases
        let quotedPhrases = extractQuotedPhrases(from: query)
        for phrase in quotedPhrases {
            operators.append(.exactPhrase(phrase))
            remainingQuery = remainingQuery.replacingOccurrences(of: "\"\(phrase)\"", with: "")
        }
        
        // Parse exclusions (minus operator)
        let exclusions = extractExclusions(from: remainingQuery)
        for exclusion in exclusions {
            operators.append(.exclude(exclusion))
            remainingQuery = remainingQuery.replacingOccurrences(of: "-\(exclusion)", with: "")
        }
        
        // Parse field-specific searches
        let fieldOperators = extractFieldOperators(from: remainingQuery)
        for fieldOp in fieldOperators {
            operators.append(fieldOp.operator)
            remainingQuery = remainingQuery.replacingOccurrences(of: fieldOp.originalText, with: "")
            
            // Apply to filters
            switch fieldOp.operator {
            case .channel(let channelName):
                // Could set a channel filter if we had one
                break
            case .duration(let duration):
                if duration.lowercased().contains("short") {
                    inferredFilters.duration = .short
                } else if duration.lowercased().contains("long") {
                    inferredFilters.duration = .long
                }
            case .uploadDate(let date):
                if date.lowercased().contains("today") {
                    inferredFilters.uploadDate = .today
                } else if date.lowercased().contains("week") {
                    inferredFilters.uploadDate = .thisWeek
                } else if date.lowercased().contains("month") {
                    inferredFilters.uploadDate = .thisMonth
                }
            default:
                break
            }
        }
        
        return ParsedQuery(
            processedQuery: remainingQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            operators: operators,
            inferredFilters: inferredFilters
        )
    }
    
    private func extractQuotedPhrases(from query: String) -> [String] {
        var phrases: [String] = []
        let pattern = "\"([^\"]*)\""
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: query) {
                    phrases.append(String(query[range]))
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return phrases
    }
    
    private func extractExclusions(from query: String) -> [String] {
        var exclusions: [String] = []
        let words = query.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if word.hasPrefix("-") && word.count > 1 {
                exclusions.append(String(word.dropFirst()))
            }
        }
        
        return exclusions
    }
    
    private func extractFieldOperators(from query: String) -> [(operator: SearchOperator, originalText: String)] {
        var operators: [(SearchOperator, String)] = []
        
        // Define field patterns
        let patterns: [(String, (String) -> SearchOperator)] = [
            ("intitle:", { SearchOperator.title($0) }),
            ("title:", { SearchOperator.title($0) }),
            ("channel:", { SearchOperator.channel($0) }),
            ("@", { SearchOperator.channel($0) }),
            ("duration:", { SearchOperator.duration($0) }),
            ("date:", { SearchOperator.uploadDate($0) }),
            ("after:", { SearchOperator.uploadDate($0) }),
            ("before:", { SearchOperator.uploadDate($0) }),
            ("site:", { SearchOperator.site($0) }),
            ("filetype:", { SearchOperator.fileType($0) }),
            ("category:", { SearchOperator.category($0) }),
            ("#", { SearchOperator.hashtag($0) })
        ]
        
        for (pattern, operatorBuilder) in patterns {
            let regex = try? NSRegularExpression(pattern: "\(NSRegularExpression.escapedPattern(for: pattern))([^\\s]+)")
            let matches = regex?.matches(in: query, range: NSRange(query.startIndex..., in: query)) ?? []
            
            for match in matches {
                if let fullRange = Range(match.range, in: query),
                   let valueRange = Range(match.range(at: 1), in: query) {
                    let fullText = String(query[fullRange])
                    let value = String(query[valueRange])
                    operators.append((operatorBuilder(value), fullText))
                }
            }
        }
        
        return operators
    }
    
    private func extractSearchTerms(from parsedQuery: ParsedQuery) -> String {
        return parsedQuery.processedQuery
    }
    
    private func tokenizeQuery(_ query: String) -> [String] {
        return query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
    
    private func analyzeQueryIntent(_ query: String) -> QueryIntent {
        let lowercased = query.lowercased()
        
        if lowercased.contains("how to") || lowercased.contains("tutorial") {
            return .tutorial
        } else if lowercased.contains("review") || lowercased.contains("vs") {
            return .review
        } else if lowercased.contains("music") || lowercased.contains("song") {
            return .music
        } else if lowercased.contains("news") || lowercased.contains("breaking") {
            return .news
        } else if lowercased.contains("funny") || lowercased.contains("comedy") {
            return .entertainment
        } else {
            return .general
        }
    }
    
    private func extractEntities(from query: String) -> [QueryEntity] {
        var entities: [QueryEntity] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = query
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entity = String(query[range])
                switch tag {
                case .personalName:
                    entities.append(.person(entity))
                case .placeName:
                    entities.append(.location(entity))
                case .organizationName:
                    entities.append(.organization(entity))
                default:
                    break
                }
            }
            return true
        }
        
        return entities
    }
}

// MARK: - Supporting Types

struct ParsedQuery {
    let processedQuery: String
    let operators: [SearchOperator]
    let inferredFilters: SearchFilters
}

struct ProcessedQuery {
    let originalQuery: String
    let terms: [String]
    let searchTerms: String
    let operators: [SearchOperator]
    let filters: SearchFilters
    let intent: QueryIntent?
    let entities: [QueryEntity]?
    
    init(originalQuery: String, terms: [String], searchTerms: String, operators: [SearchOperator] = [], filters: SearchFilters = SearchFilters(), intent: QueryIntent? = nil, entities: [QueryEntity]? = nil) {
        self.originalQuery = originalQuery
        self.terms = terms
        self.searchTerms = searchTerms
        self.operators = operators
        self.filters = filters
        self.intent = intent
        self.entities = entities
    }
}

enum SearchOperator {
    case exactPhrase(String)
    case exclude(String)
    case title(String)
    case channel(String)
    case duration(String)
    case uploadDate(String)
    case site(String)
    case fileType(String)
    case category(String)
    case hashtag(String)
}

enum QueryIntent {
    case tutorial
    case review
    case music
    case news
    case entertainment
    case general
}

enum QueryEntity {
    case person(String)
    case location(String)
    case organization(String)
}
