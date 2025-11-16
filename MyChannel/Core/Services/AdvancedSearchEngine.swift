import Foundation
import NaturalLanguage
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct SemanticSearchResult: Codable {
    let contentId: String
    let title: String
    let description: String
    let semanticScore: Double
    let keywordMatches: [String]
    let entityMatches: [String]
    let conceptMatches: [String]
}

// Using SearchSuggestion from AdvancedSearchService.swift

struct TypoCorrection: Codable {
    let original: String
    let corrected: String
    let confidence: Double
    let source: CorrectionSource
    
    enum CorrectionSource: String, Codable {
        case dictionary, userBehavior, semantic, phonetic
    }
}

@MainActor
final class AdvancedSearchEngine: ObservableObject {
    static let shared = AdvancedSearchEngine()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private let semanticEmbeddings: [String: [Double]] = [:]
    private let popularQueries: [String: Double] = [:]
    private let commonTypos: [String: String] = [
        "youtub": "youtube",
        "musik": "music",
        "gamming": "gaming",
        "tecnology": "technology",
        "recepie": "recipe",
        "toturial": "tutorial"
    ]
    
    func search(query: String, userId: String?, filters: SearchFilters, limit: Int = 50) async -> [SearchResult] {
        // 1. Typo correction
        let correctedQuery = await correctTypos(query: query)
        
        // 2. Semantic expansion
        let expandedTerms = await expandSemanticTerms(query: correctedQuery.corrected)
        
        // 3. Multi-modal search
        let results = await performMultiModalSearch(
            query: correctedQuery.corrected,
            expandedTerms: expandedTerms,
            userId: userId,
            filters: filters,
            limit: limit
        )
        
        // 4. Personalization and ranking
        let personalizedResults = await personalizeResults(results, userId: userId, query: correctedQuery.corrected)
        
        // 5. Log search for future improvements
        await logSearchQuery(
            original: query,
            corrected: correctedQuery.corrected,
            userId: userId,
            resultCount: personalizedResults.count
        )
        
        return personalizedResults
    }
    
    func getSuggestions(query: String, userId: String?, limit: Int = 10) async -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // 1. Typo corrections
        if query.count >= 3 {
            let correction = await correctTypos(query: query)
            if correction.original != correction.corrected {
                suggestions.append(SearchSuggestion(
                    id: UUID().uuidString,
                    text: correction.corrected,
                    subtitle: "Did you mean?",
                    icon: "text.magnifyingglass",
                    isAIGenerated: true,
                    score: 0.95
                ))
            }
        }
        
        // 2. Query completions
        let completions = await getQueryCompletions(prefix: query, userId: userId)
        suggestions += completions.prefix(limit - suggestions.count)
        
        // 3. Trending suggestions
        if suggestions.count < limit {
            let trending = await getTrendingSuggestions(relatedTo: query)
            suggestions += trending.prefix(limit - suggestions.count)
        }
        
        // 4. Personalized suggestions
        if let userId = userId, suggestions.count < limit {
            let personalized = await getPersonalizedSuggestions(query: query, userId: userId)
            suggestions += personalized.prefix(limit - suggestions.count)
        }
        
        return Array(suggestions.prefix(limit))
    }
    
    func buildSemanticIndex(videos: [Video]) async {
        #if canImport(FirebaseFirestore)
        do {
            let batch = db.batch()
            
            for video in videos {
                let embedding = await generateEmbedding(text: video.title + " " + video.description)
                let concepts = await extractConcepts(text: video.title + " " + video.description)
                let entities = await extractEntities(text: video.title + " " + video.description)
                
                let searchDoc = db.collection("search_index").document(video.id)
                batch.setData([
                    "title": video.title,
                    "description": video.description,
                    "tags": video.tags,
                    "category": video.category.rawValue,
                    "creator": video.creator.displayName,
                    "embedding": embedding,
                    "concepts": concepts,
                    "entities": entities,
                    "popularity": calculatePopularityScore(video),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], forDocument: searchDoc)
            }
            
            try await batch.commit()
        } catch { }
        #endif
    }
    
    private func correctTypos(query: String) async -> TypoCorrection {
        let words = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var correctedWords: [String] = []
        var hasCorrectionCandidate = false
        
        for word in words {
            if let correction = commonTypos[word] {
                correctedWords.append(correction)
                hasCorrectionCandidate = true
            } else if word.count >= 4 {
                // Check for phonetic similarities
                let phoneticCorrection = await findPhoneticMatch(word: word)
                correctedWords.append(phoneticCorrection ?? word)
                if phoneticCorrection != nil { hasCorrectionCandidate = true }
            } else {
                correctedWords.append(word)
            }
        }
        
        let correctedQuery = correctedWords.joined(separator: " ")
        
        return TypoCorrection(
            original: query,
            corrected: correctedQuery,
            confidence: hasCorrectionCandidate ? 0.8 : 1.0,
            source: .dictionary
        )
    }
    
    private func expandSemanticTerms(query: String) async -> [String] {
        // Generate semantically similar terms
        let synonyms: [String: [String]] = [
            "music": ["songs", "audio", "sound", "beats", "melody"],
            "video": ["clip", "movie", "film", "content"],
            "funny": ["hilarious", "comedy", "humor", "jokes"],
            "tutorial": ["guide", "howto", "lesson", "walkthrough"],
            "gaming": ["games", "gameplay", "esports", "streaming"]
        ]
        
        var expandedTerms: [String] = [query]
        let words = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if let wordSynonyms = synonyms[word] {
                expandedTerms += wordSynonyms.prefix(2)
            }
        }
        
        return Array(Set(expandedTerms)) // Remove duplicates
    }
    
    private func performMultiModalSearch(query: String, expandedTerms: [String], userId: String?, filters: SearchFilters, limit: Int) async -> [SearchResult] {
        var allResults: [SearchResult] = []
        
        #if canImport(FirebaseFirestore)
        do {
            // 1. Full-text search in Firestore
            var videoQuery: Query = db.collection("search_index")
            
            // Apply filters
            if let category = filters.category {
                videoQuery = videoQuery.whereField("category", isEqualTo: category.rawValue)
            }
            
            let snapshot = try await videoQuery.limit(to: limit * 2).getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                let title = data["title"] as? String ?? ""
                let description = data["description"] as? String ?? ""
                let tags = data["tags"] as? [String] ?? []
                
                // Calculate relevance score
                let relevanceScore = calculateRelevanceScore(
                    query: query,
                    expandedTerms: expandedTerms,
                    title: title,
                    description: description,
                    tags: tags
                )
                
                if relevanceScore > 0.1 {
                    let video = Video(
                        id: doc.documentID,
                        title: title,
                        description: description,
                        thumbnailURL: data["thumbnailURL"] as? String ?? "",
                        videoURL: data["videoURL"] as? String ?? "",
                        duration: data["duration"] as? TimeInterval ?? 0,
                        viewCount: data["viewCount"] as? Int ?? 0,
                        likeCount: data["likeCount"] as? Int ?? 0,
                        creator: AppState.shared.currentUser ?? User.defaultUser,
                        category: VideoCategory(rawValue: data["category"] as? String ?? "") ?? .entertainment
                    )
                    
                    allResults.append(.video(VideoSearchResult(
                        video: video,
                        relevanceScore: relevanceScore,
                        matchingFields: getMatchingFields(query: query, title: title, description: description),
                        highlights: []
                    )))
                }
            }
        } catch { }
        #endif
        
        // 2. Semantic search using embeddings
        let semanticResults = await performSemanticSearch(query: query, limit: limit)
        allResults += semanticResults
        
        // 3. Remove duplicates and rank
        var seen = Set<String>()
        let deduplicatedResults = allResults.filter { result in
            let id = getResultId(result)
            return seen.insert(id).inserted
        }
        
        return Array(deduplicatedResults.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(limit))
    }
    
    private func performSemanticSearch(query: String, limit: Int) async -> [SearchResult] {
        // Generate query embedding
        let queryEmbedding = await generateEmbedding(text: query)
        
        // Find similar content using vector similarity
        // In production, would use vector database like Pinecone or Weaviate
        var results: [SearchResult] = []
        
        // Mock semantic search results
        let mockResults = Video.sampleVideos.prefix(limit / 2)
        for video in mockResults {
            let semanticScore = Double.random(in: 0.5...0.9)
            results.append(.video(VideoSearchResult(
                video: video,
                relevanceScore: semanticScore,
                matchingFields: ["semantic"],
                highlights: []
            )))
        }
        
        return results
    }
    
    private func calculateRelevanceScore(query: String, expandedTerms: [String], title: String, description: String, tags: [String]) -> Double {
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let allSearchTerms = Set(queryTerms + expandedTerms.flatMap { $0.components(separatedBy: .whitespacesAndNewlines) })
        
        var score = 0.0
        
        // Title matching (highest weight)
        let titleScore = calculateTextScore(text: title.lowercased(), terms: Array(allSearchTerms))
        score += titleScore * 0.4
        
        // Description matching
        let descScore = calculateTextScore(text: description.lowercased(), terms: Array(allSearchTerms))
        score += descScore * 0.2
        
        // Tag matching (exact matches)
        let tagScore = calculateTagScore(tags: tags.map { $0.lowercased() }, terms: Array(allSearchTerms))
        score += tagScore * 0.3
        
        // Fuzzy matching bonus
        let fuzzyScore = calculateFuzzyScore(text: (title + " " + description).lowercased(), terms: Array(allSearchTerms))
        score += fuzzyScore * 0.1
        
        return min(1.0, score)
    }
    
    private func calculateTextScore(text: String, terms: [String]) -> Double {
        let matchedTerms = terms.filter { text.contains($0) }
        return terms.isEmpty ? 0 : Double(matchedTerms.count) / Double(terms.count)
    }
    
    private func calculateTagScore(tags: [String], terms: [String]) -> Double {
        let matchedTerms = terms.filter { term in
            tags.contains { tag in tag.contains(term) || term.contains(tag) }
        }
        return terms.isEmpty ? 0 : Double(matchedTerms.count) / Double(terms.count)
    }
    
    private func calculateFuzzyScore(text: String, terms: [String]) -> Double {
        var totalScore = 0.0
        
        for term in terms {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            let bestMatch = words.compactMap { word in
                levenshteinDistance(word, term)
            }.min() ?? Int.max
            
            if bestMatch <= 2 && term.count >= 4 {
                totalScore += max(0, 1.0 - Double(bestMatch) / Double(term.count))
            }
        }
        
        return terms.isEmpty ? 0 : totalScore / Double(terms.count)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let empty = Array<Int>(repeating: 0, count: str2.count)
        var last = Array(0...str2.count)
        
        for (i, char1) in str1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in str2.enumerated() {
                current[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        
        return last.last ?? 0
    }
    
    private func generateEmbedding(text: String) async -> [Double] {
        // Mock embedding generation - in production would use ML model
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.enumerated().map { index, word in
            Double(word.count + index) / 100.0
        }.prefix(512).map { $0 } // 512-dim embedding
    }
    
    private func extractConcepts(text: String) async -> [String] {
        // Extract high-level concepts using NLP
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var concepts: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                concepts.append(String(text[range]))
            }
            return true
        }
        
        return Array(Set(concepts)) // Remove duplicates
    }
    
    private func extractEntities(text: String) async -> [String] {
        // Extract named entities
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var entities: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, [.personalName, .placeName, .organizationName].contains(tag) {
                entities.append(String(text[range]))
            }
            return true
        }
        
        return Array(Set(entities))
    }
    
    private func getQueryCompletions(prefix: String, userId: String?) async -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        #if canImport(FirebaseFirestore)
        do {
            // Get popular queries that start with prefix
            let querySnapshot = try await db.collection("search_analytics")
                .whereField("query", isGreaterThanOrEqualTo: prefix.lowercased())
                .whereField("query", isLessThan: prefix.lowercased() + "z")
                .order(by: "count", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            for doc in querySnapshot.documents {
                let data = doc.data()
                let query = data["query"] as? String ?? ""
                let count = data["count"] as? Int ?? 0
                let category = data["category"] as? String
                
                suggestions.append(SearchSuggestion(
                    id: UUID().uuidString,
                    text: query,
                    subtitle: nil,
                    icon: "magnifyingglass",
                    isAIGenerated: false,
                    score: 0.8
                ))
            }
        } catch { }
        #endif
        
        // Fallback completions
        if suggestions.isEmpty {
            let fallbackCompletions = [
                prefix + " tutorial",
                prefix + " review",
                prefix + " 2024",
                "best " + prefix,
                prefix + " tips"
            ]
            
            suggestions = fallbackCompletions.map { completion in
                SearchSuggestion(
                    id: UUID().uuidString,
                    text: completion,
                    subtitle: nil,
                    icon: "magnifyingglass",
                    isAIGenerated: false,
                    score: 0.7
                )
            }
        }
        
        return suggestions
    }
    
    private func getTrendingSuggestions(relatedTo query: String) async -> [SearchSuggestion] {
        // Get trending searches related to the query
        #if canImport(FirebaseFirestore)
        do {
            let trendingSnapshot = try await db.collection("trending_searches")
                .order(by: "popularity", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            return trendingSnapshot.documents.compactMap { doc in
                let data = doc.data()
                let trendingQuery = data["query"] as? String ?? ""
                let popularity = data["popularity"] as? Double ?? 0
                
                // Check if trending query is related to input query
                if isQueryRelated(trendingQuery, to: query) {
                    return SearchSuggestion(
                        id: UUID().uuidString,
                        text: trendingQuery,
                        subtitle: "Trending",
                        icon: "flame.fill",
                        isAIGenerated: false,
                        score: 0.85
                    )
                }
                return nil
            }
        } catch { }
        #endif
        
        return []
    }
    
    private func getPersonalizedSuggestions(query: String, userId: String) async -> [SearchSuggestion] {
        // Get suggestions based on user's watch history and preferences
        let history = await HistoryService.shared.fetch(userId: userId, limit: 50)
        let preferredCategories = Array(Set(history.map { $0.category.rawValue }))
        
        var suggestions: [SearchSuggestion] = []
        
        for category in preferredCategories.prefix(3) {
            suggestions.append(SearchSuggestion(
                id: UUID().uuidString,
                text: "\(query) \(category)",
                subtitle: "Related",
                icon: "link",
                isAIGenerated: false,
                score: 0.75
            ))
        }
        
        return suggestions
    }
    
    private func personalizeResults(_ results: [SearchResult], userId: String?, query: String) async -> [SearchResult] {
        guard let userId = userId else {
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        }
        
        // Get user preferences
        let history = await HistoryService.shared.fetch(userId: userId, limit: 100)
        let preferredCategories = Set(history.map { $0.category })
        let preferredCreators = Set(history.map { $0.creator.id })
        
        // Boost scores based on preferences
        let boostedResults = results.map { result -> SearchResult in
            var boostedResult = result
            
            if case .video(var videoResult) = result {
                var score = videoResult.relevanceScore
                
                // Category preference boost
                if preferredCategories.contains(videoResult.video.category) {
                    score += 0.1
                }
                
                // Creator preference boost
                if preferredCreators.contains(videoResult.video.creator.id) {
                    score += 0.15
                }
                
                // Recency boost for fresh content
                let daysSinceUpload = Date().timeIntervalSince(videoResult.video.createdAt) / 86400
                if daysSinceUpload <= 7 {
                    score += 0.05
                }
                
                let updatedVideoResult = VideoSearchResult(
                    video: videoResult.video,
                    relevanceScore: min(1.0, score),
                    matchingFields: videoResult.matchingFields,
                    highlights: videoResult.highlights
                )
                boostedResult = .video(updatedVideoResult)
            }
            
            return boostedResult
        }
        
        return boostedResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func findPhoneticMatch(word: String) async -> String? {
        // Simple phonetic matching using Soundex-like algorithm
        let phoneticMap: [String: String] = [
            "nite": "night",
            "lite": "light",
            "kool": "cool",
            "grate": "great"
        ]
        
        return phoneticMap[word]
    }
    
    private func isQueryRelated(_ query1: String, to query2: String) -> Bool {
        let words1 = Set(query1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(query2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? false : Double(intersection.count) / Double(union.count) > 0.3
    }
    
    private func calculatePopularityScore(_ video: Video) -> Double {
        let viewScore = min(1.0, Double(video.viewCount) / 1_000_000)
        let likeScore = min(1.0, Double(video.likeCount) / 10_000)
        let recencyScore = max(0, 1.0 - Date().timeIntervalSince(video.createdAt) / (365 * 24 * 3600))
        
        return (viewScore * 0.5) + (likeScore * 0.3) + (recencyScore * 0.2)
    }
    
    private func getMatchingFields(query: String, title: String, description: String) -> [String] {
        var fields: [String] = []
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        if queryTerms.allSatisfy({ title.lowercased().contains($0) }) {
            fields.append("title")
        }
        
        if queryTerms.allSatisfy({ description.lowercased().contains($0) }) {
            fields.append("description")
        }
        
        return fields
    }
    
    private func getResultId(_ result: SearchResult) -> String {
        switch result {
        case .video(let videoResult): return videoResult.video.id
        case .creator(let creatorResult): return creatorResult.creator.id
        case .playlist(let playlistResult): return playlistResult.playlist.id
        case .liveStream(let liveResult): return liveResult.video.id
        }
    }
    
    private func logSearchQuery(original: String, corrected: String, userId: String?, resultCount: Int) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("search_analytics").document().setData([
                "originalQuery": original,
                "correctedQuery": corrected,
                "userId": userId as Any,
                "resultCount": resultCount,
                "timestamp": FieldValue.serverTimestamp()
            ])
            
            // Update query popularity
            let queryRef = db.collection("search_popularity").document(corrected.lowercased())
            try await queryRef.setData([
                "query": corrected.lowercased(),
                "count": FieldValue.increment(Int64(1)),
                "lastSearched": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
}
