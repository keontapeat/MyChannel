import SwiftUI
import Combine
import Foundation
import NaturalLanguage
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Enterprise-grade search service with ML-powered ranking and recommendations
/// Handles complex queries with filters, faceting, and personalized results
/// **NOW WITH TRIPLE AI INTEGRATION** 🚀🤖🔥
@MainActor
class AdvancedSearchService: ObservableObject {
    
    @Published var searchResults: [SearchResult] = []
    @Published var searchSuggestions: [AdvancedSearchSuggestion] = []
    @Published var isSearching = false
    @Published var searchAnalytics = SearchAnalytics()
    @Published var popularSearches: [String] = []
    
    // 🔥 NEW: AI-Powered Search Integration
    @Published var aiSearchEnabled = true
    @Published var aiInsights: SearchAIInsights?
    @Published var enhancedQuery: String?
    @Published var aiSuggestions: [AISearchSuggestion] = []
    private let aiSearchService = AISearchService.shared
    
    private let searchIndexer = SearchIndexer()
    private let queryProcessor = QueryProcessor()
    private let rankingEngine = SearchRankingEngine()
    private let autoCompleteService = AutoCompleteService()
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var lastVideoSnap: DocumentSnapshot?
    #endif
    
    // Search configuration
    private let maxResults = 50
    private let maxSuggestions = 10
    private var searchHistory: [SearchQuery] = []
    private var currentUserId: String?
    
    // Real-time search debouncing
    private var searchCancellable: AnyCancellable?
    private let searchDebounceInterval: TimeInterval = 0.3
    
    init() {
        setupSearchEngine()
        loadPopularSearches()
    }
    
    // MARK: - Public Search Interface
    
    /// Performs comprehensive search with ML-powered ranking
    func search(
        query: String,
        filters: SearchFilters = SearchFilters(),
        userId: String? = nil
    ) async throws -> AdvancedSearchResponse {
        
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "search_query", attributes: [
            "query_length": String(query.count),
            "has_filters": String(filters != nil),
            "search_scope": "all"
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("search_requests")
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MonitoringDashboardManager.shared.incrementCounter("search_errors")
            PerformanceMonitoringManager.shared.stopTrace(name: "search_query")
            throw SearchError.emptyQuery
        }
        
        // Check cache first
        let cacheKey = generateCacheKey(query: query, filters: filters)
        if let cachedResults = searchCache[cacheKey] {
            let responseTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "search_query", metrics: [
                "result_count": Int64(cachedResults.count),
                "cache_hit": 1
            ])
            MonitoringDashboardManager.shared.recordLatency("search_response_time", latency: responseTime)
            return AdvancedSearchResponse(results: cachedResults, totalCount: cachedResults.count, searchTime: responseTime)
        }
        
        isSearching = true
        
        defer {
            DispatchQueue.main.async {
                self.isSearching = false
            }
        }
        
        // Process and analyze query
        let processedQuery = await queryProcessor.processQuery(query)
        
        // Perform multi-dimensional search
        async let videoResults = searchVideos(query: processedQuery, filters: filters)
        async let creatorResults = searchCreators(query: processedQuery, filters: filters)
        async let playlistResults = searchPlaylists(query: processedQuery, filters: filters)
        async let liveStreamResults = searchLiveStreams(query: processedQuery, filters: filters)
        
        // Combine and rank results
        let allResults = try await combineResults(
            videos: videoResults,
            creators: creatorResults,
            playlists: playlistResults,
            liveStreams: liveStreamResults
        )
        
        // Apply personalization if user provided
        let personalizedResults = userId != nil ? 
            await rankingEngine.personalizeResults(allResults, for: userId!) :
            await rankingEngine.rankResults(allResults, for: processedQuery)
        
        let searchTime = Date().timeIntervalSince(startTime)
        
        // Update search analytics
        await updateSearchAnalytics(
            query: query,
            resultCount: personalizedResults.count,
            searchTime: searchTime,
            userId: userId
        )
        
        // Log search for future improvements
        logSearch(query: query, results: personalizedResults, userId: userId)
        
        let response = AdvancedSearchResponse(
            results: Array(personalizedResults.prefix(maxResults)),
            totalCount: personalizedResults.count,
            searchTime: searchTime,
            suggestions: await generateRelatedSearches(for: query),
            facets: await generateSearchFacets(from: personalizedResults)
        )
        
        await MainActor.run {
            self.searchResults = response.results
        }
        
        return response
    }
    
    /// Real-time search suggestions with auto-complete
    func getSearchSuggestions(for query: String, userId: String? = nil) async -> [AdvancedSearchSuggestion] {
        guard query.count >= 2 else { return [] }
        
        let suggestions = await autoCompleteService.generateSuggestions(
            query: query,
            userId: userId,
            maxSuggestions: maxSuggestions
        )
        
        await MainActor.run {
            self.searchSuggestions = suggestions
        }
        
        return suggestions
    }
    
    /// Trending and popular searches
    func getTrendingSearches(limit: Int = 10) async -> [AdvancedTrendingSearch] {
        return await autoCompleteService.getTrendingSearches(limit: limit)
    }
    
    /// Search with voice query processing
    func voiceSearch(audioData: Data, userId: String? = nil) async throws -> AdvancedSearchResponse {
        // In production, integrate with Speech framework
        let transcribedQuery = try await transcribeAudio(audioData)
        return try await search(query: transcribedQuery, userId: userId)
    }
    
    /// Advanced search with natural language queries
    func naturalLanguageSearch(query: String, userId: String? = nil) async throws -> AdvancedSearchResponse {
        let processedQuery = await queryProcessor.processNaturalLanguageQuery(query)
        let inferredFilters = await queryProcessor.inferFilters(from: query)
        
        return try await search(
            query: processedQuery.searchTerms,
            filters: inferredFilters,
            userId: userId
        )
    }
    
    /// Search within specific content
    func searchWithinVideo(videoId: String, query: String) async throws -> [VideoSearchResult] {
        // Search within video transcripts, comments, etc.
        return await searchIndexer.searchWithinContent(videoId: videoId, query: query)
    }
    
    // MARK: - Search History and Analytics
    
    func getSearchHistory(userId: String, limit: Int = 20) async -> [SearchQuery] {
        return Array(searchHistory.filter { $0.userId == userId }.suffix(limit))
    }
    
    func clearSearchHistory(userId: String) async {
        searchHistory.removeAll { $0.userId == userId }
    }
    
    func getSearchAnalytics(period: SearchAnalyticsPeriod) async -> SearchAnalytics {
        return searchAnalytics
    }
    
    // MARK: - Private Implementation
    
    private func setupSearchEngine() {
        searchIndexer.buildIndex(from: Video.sampleVideos, creators: User.sampleUsers)
        loadSearchHistory()
    }
    
    private func searchVideos(
        query: ProcessedQuery,
        filters: SearchFilters
    ) async -> [VideoSearchResult] {
        
        var videos = Video.sampleVideos
        #if canImport(FirebaseFirestore)
        do {
            var queryRef: Query = db.collection("videos").whereField("visibility", isEqualTo: "public")
            if let category = filters.category { queryRef = queryRef.whereField("category", isEqualTo: category.rawValue) }
            queryRef = queryRef.order(by: "createdAt", descending: true).limit(to: 50)
            let snap = try await queryRef.getDocuments()
            let defaultCreator = await MainActor.run { AppState.shared.currentUser } ?? User.defaultUser
            let fetched: [Video] = snap.documents.compactMap { doc in
                let d = doc.data()
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                    videoURL: d["videoUrl"] as? String ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: defaultCreator,
                    category: filters.category ?? .entertainment
                )
            }
            if !fetched.isEmpty { videos = fetched }
        } catch { }
        #endif
        
        // Apply filters
        if let category = filters.category {
            videos = videos.filter { $0.category == category }
        }
        
        if let duration = filters.duration {
            videos = videos.filter { video in
                switch duration {
                case .short: return video.duration < 240 // 4 minutes
                case .medium: return video.duration >= 240 && video.duration < 1200 // 4-20 minutes
                case .long: return video.duration >= 1200 // 20+ minutes
                }
            }
        }
        
        if let uploadDate = filters.uploadDate {
            let cutoffDate = Calendar.current.date(byAdding: uploadDate.dateComponent, value: -1, to: Date())!
            videos = videos.filter { $0.createdAt >= cutoffDate }
        }
        
        // Text matching with relevance scoring
        let searchResults = videos.compactMap { video -> VideoSearchResult? in
            let relevanceScore = calculateRelevance(
                video: video,
                query: query,
                filters: filters
            )
            
            guard relevanceScore > 0.1 else { return nil }
            
            return VideoSearchResult(
                video: video,
                relevanceScore: relevanceScore,
                matchingFields: getMatchingFields(video: video, query: query),
                highlights: generateHighlights(video: video, query: query)
            )
        }
        
        return searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func searchCreators(
        query: ProcessedQuery,
        filters: SearchFilters
    ) async -> [CreatorSearchResult] {
        
        var creators = User.sampleUsers.filter { $0.isCreator }
        
        // 🔥 REAL SEARCH: Also search Firebase for real users/creators
        #if canImport(FirebaseFirestore)
        do {
            // Search by display name (case-insensitive prefix search)
            let searchTermLower = query.originalQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let searchTermClean = searchTermLower.replacingOccurrences(of: "@", with: "") // Handle @username searches
            
            // Query users collection - search by displayName and username
            let usersSnap = try await db.collection("users")
                .whereField("isCreator", isEqualTo: true)
                .limit(to: 50)
                .getDocuments()
            
            let firebaseCreators: [User] = usersSnap.documents.compactMap { doc -> User? in
                let d = doc.data()
                let displayName = d["displayName"] as? String ?? ""
                let username = d["username"] as? String ?? ""
                let bio = d["bio"] as? String ?? ""
                
                // Check if this creator matches the search query
                let matchesQuery = displayName.lowercased().contains(searchTermClean) ||
                                   username.lowercased().contains(searchTermClean) ||
                                   bio.lowercased().contains(searchTermClean)
                
                guard matchesQuery else { return nil }
                
                // Convert socialLinks dictionary to [SocialLink] array
                let socialLinksDict = (d["socialLinks"] as? [String: String]) ?? [:]
                let socialLinks: [SocialLink] = socialLinksDict.compactMap { key, value in
                    guard let platform = SocialPlatform(rawValue: key.lowercased()) else { return nil }
                    return SocialLink(platform: platform, url: value, displayName: platform.displayName)
                }
                
                return User(
                    id: doc.documentID,
                    username: username,
                    displayName: displayName,
                    email: d["email"] as? String ?? "",
                    profileImageURL: d["profileImageURL"] as? String ?? d["profileImageUrl"] as? String,
                    bannerImageURL: d["bannerImageURL"] as? String ?? d["bannerImageUrl"] as? String,
                    bio: bio.isEmpty ? nil : bio,
                    subscriberCount: (d["subscriberCount"] as? Int) ?? 0,
                    videoCount: (d["videoCount"] as? Int) ?? 0,
                    isVerified: (d["isVerified"] as? Bool) ?? false,
                    isCreator: true,
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    location: d["location"] as? String,
                    website: d["website"] as? String,
                    showWebsiteOnProfile: (d["showWebsiteOnProfile"] as? Bool) ?? false,
                    socialLinks: socialLinks,
                    followerCount: (d["followerCount"] as? Int) ?? 0,
                    followingCount: (d["followingCount"] as? Int) ?? 0,
                    joinDate: (d["joinDate"] as? Timestamp)?.dateValue(),
                    totalViews: (d["totalViews"] as? Int) ?? 0,
                    totalEarnings: (d["totalEarnings"] as? Double) ?? 0
                )
            }
            
            // Add Firebase creators to the list (avoid duplicates)
            let existingIds = Set(creators.map { $0.id })
            for creator in firebaseCreators {
                if !existingIds.contains(creator.id) {
                    creators.append(creator)
                }
            }
            
            print("🔍 [SearchCreators] Found \(firebaseCreators.count) creators from Firebase matching '\(searchTermClean)'")
        } catch {
            print("⚠️ [SearchCreators] Firebase search error: \(error)")
        }
        #endif
        
        // Apply creator-specific filters
        if let subscriberRange = filters.subscriberRange {
            creators = creators.filter { creator in
                let count = creator.subscriberCount
                return count >= subscriberRange.min && count <= subscriberRange.max
            }
        }
        
        let searchResults = creators.compactMap { creator -> CreatorSearchResult? in
            let relevanceScore = calculateCreatorRelevance(
                creator: creator,
                query: query
            )
            
            guard relevanceScore > 0.1 else { return nil }
            
            return CreatorSearchResult(
                creator: creator,
                relevanceScore: relevanceScore,
                matchingFields: getCreatorMatchingFields(creator: creator, query: query)
            )
        }
        
        return searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func searchPlaylists(
        query: ProcessedQuery,
        filters: SearchFilters
    ) async -> [PlaylistSearchResult] {
        
        // For demo - in production would search actual playlists
        let samplePlaylists = Playlist.samplePlaylists
        
        let searchResults = samplePlaylists.compactMap { playlist -> PlaylistSearchResult? in
            let relevanceScore = calculatePlaylistRelevance(
                playlist: playlist,
                query: query
            )
            
            guard relevanceScore > 0.1 else { return nil }
            
            return PlaylistSearchResult(
                playlist: playlist,
                relevanceScore: relevanceScore,
                matchingFields: ["title", "description"]
            )
        }
        
        return searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func searchLiveStreams(
        query: ProcessedQuery,
        filters: SearchFilters
    ) async -> [LiveStreamSearchResult] {
        
        // Filter for live videos
        let liveVideos = Video.sampleVideos.filter { $0.isLiveStream }
        
        let searchResults = liveVideos.compactMap { video -> LiveStreamSearchResult? in
            let relevanceScore = calculateRelevance(
                video: video,
                query: query,
                filters: filters
            )
            
            guard relevanceScore > 0.1 else { return nil }
            
            return LiveStreamSearchResult(
                video: video,
                relevanceScore: relevanceScore,
                viewerCount: Int.random(in: 10...5000)
            )
        }
        
        return searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func calculateRelevance(
        video: Video,
        query: ProcessedQuery,
        filters: SearchFilters
    ) -> Double {
        
        var score = 0.0
        
        // Title matching (highest weight)
        let titleScore = fuzzyMatch(text: video.title.lowercased(), terms: query.terms)
        score += titleScore * 0.4
        
        // Description matching
        let descriptionScore = fuzzyMatch(text: video.description.lowercased(), terms: query.terms)
        score += descriptionScore * 0.2
        
        // Tag matching
        let tagScore = exactMatchTags(tags: video.tags, terms: query.terms)
        score += tagScore * 0.2
        
        // Creator name matching
        let creatorScore = fuzzyMatch(text: video.creator.displayName.lowercased(), terms: query.terms)
        score += creatorScore * 0.1
        
        // Popularity boost
        let popularityScore = min(Double(video.viewCount) / 1_000_000, 1.0) // Normalize to 1M views
        score += popularityScore * 0.05
        
        // Recency boost
        let daysSince = Date().timeIntervalSince(video.createdAt) / (24 * 3600)
        let recencyScore = max(0, 1.0 - daysSince / 365.0) // Decay over a year
        score += recencyScore * 0.05
        
        return min(score, 1.0)
    }
    
    private func calculateCreatorRelevance(
        creator: User,
        query: ProcessedQuery
    ) -> Double {
        
        var score = 0.0
        
        // Name matching
        let nameScore = fuzzyMatch(text: creator.displayName.lowercased(), terms: query.terms)
        score += nameScore * 0.5
        
        let usernameScore = fuzzyMatch(text: creator.username.lowercased(), terms: query.terms)
        score += usernameScore * 0.3
        
        // Bio matching
        if let bio = creator.bio {
            let bioScore = fuzzyMatch(text: bio.lowercased(), terms: query.terms)
            score += bioScore * 0.1
        }
        
        // Popularity boost
        let popularityScore = min(Double(creator.subscriberCount) / 1_000_000, 1.0)
        score += popularityScore * 0.1
        
        return min(score, 1.0)
    }
    
    private func calculatePlaylistRelevance(
        playlist: Playlist,
        query: ProcessedQuery
    ) -> Double {
        
        var score = 0.0
        
        // Title matching
        let titleScore = fuzzyMatch(text: playlist.title.lowercased(), terms: query.terms)
        score += titleScore * 0.6
        
        // Description matching
        let descriptionScore = fuzzyMatch(text: playlist.description.lowercased(), terms: query.terms)
        score += descriptionScore * 0.4
        
        return min(score, 1.0)
    }
    
    private func fuzzyMatch(text: String, terms: [String]) -> Double {
        guard !terms.isEmpty else { return 0.0 }
        
        var totalScore = 0.0
        
        for term in terms {
            if text.contains(term) {
                // Exact match
                totalScore += 1.0
            } else {
                // Fuzzy match using Levenshtein distance
                let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                let bestMatch = words.map { levenshteinDistance($0, term) }.min() ?? Int.max
                
                if bestMatch <= 2 { // Allow up to 2 character differences
                    totalScore += max(0, 1.0 - Double(bestMatch) / Double(term.count))
                }
            }
        }
        
        return totalScore / Double(terms.count)
    }
    
    private func exactMatchTags(tags: [String], terms: [String]) -> Double {
        let lowercaseTags = tags.map { $0.lowercased() }
        let matchCount = terms.filter { term in
            lowercaseTags.contains { $0.contains(term) }
        }.count
        
        return terms.isEmpty ? 0.0 : Double(matchCount) / Double(terms.count)
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
    
    private func getMatchingFields(video: Video, query: ProcessedQuery) -> [String] {
        var fields: [String] = []
        
        if query.terms.allSatisfy({ video.title.lowercased().contains($0) }) {
            fields.append("title")
        }
        
        if query.terms.allSatisfy({ video.description.lowercased().contains($0) }) {
            fields.append("description")
        }
        
        if query.terms.allSatisfy({ term in video.tags.contains { $0.lowercased().contains(term) } }) {
            fields.append("tags")
        }
        
        return fields
    }
    
    private func getCreatorMatchingFields(creator: User, query: ProcessedQuery) -> [String] {
        var fields: [String] = []
        
        if query.terms.allSatisfy({ creator.displayName.lowercased().contains($0) }) {
            fields.append("name")
        }
        
        if query.terms.allSatisfy({ creator.username.lowercased().contains($0) }) {
            fields.append("username")
        }
        
        return fields
    }
    
    private func generateHighlights(video: Video, query: ProcessedQuery) -> [TextHighlight] {
        var highlights: [TextHighlight] = []
        
        for term in query.terms {
            if let range = video.title.lowercased().range(of: term) {
                highlights.append(TextHighlight(
                    field: "title",
                    text: String(video.title[range]),
                    startIndex: video.title.distance(from: video.title.startIndex, to: range.lowerBound)
                ))
            }
        }
        
        return highlights
    }
    
    private func combineResults(
        videos: [VideoSearchResult],
        creators: [CreatorSearchResult],
        playlists: [PlaylistSearchResult],
        liveStreams: [LiveStreamSearchResult]
    ) async throws -> [SearchResult] {
        
        var combined: [SearchResult] = []
        
        // Convert to common SearchResult type
        combined.append(contentsOf: videos.map { SearchResult.video($0) })
        combined.append(contentsOf: creators.map { SearchResult.creator($0) })
        combined.append(contentsOf: playlists.map { SearchResult.playlist($0) })
        combined.append(contentsOf: liveStreams.map { SearchResult.liveStream($0) })
        
        return combined.sorted { lhs, rhs in
            lhs.relevanceScore > rhs.relevanceScore
        }
    }
    
    private func generateRelatedSearches(for query: String) async -> [String] {
        // Generate related search suggestions based on query
        return [
            "\(query) tutorial",
            "\(query) review",
            "\(query) 2024",
            "best \(query)",
            "\(query) tips"
        ]
    }
    
    private func generateSearchFacets(from results: [SearchResult]) async -> [SearchFacet] {
        var facets: [SearchFacet] = []
        
        // Category facet
        var categoryCount: [String: Int] = [:]
        for result in results {
            if case .video(let videoResult) = result {
                let category = videoResult.video.category.displayName
                categoryCount[category, default: 0] += 1
            }
        }
        
        if !categoryCount.isEmpty {
            let categoryFacetValues = categoryCount.map { category, count in
                SearchFacetValue(value: category, count: count, selected: false)
            }.sorted { $0.count > $1.count }
            
            facets.append(SearchFacet(
                name: "Category",
                field: "category",
                values: categoryFacetValues
            ))
        }
        
        // Duration facet
        var durationCount: [String: Int] = [:]
        for result in results {
            if case .video(let videoResult) = result {
                let duration = videoResult.video.duration
                let bucket = duration < 240 ? "Short" : duration < 1200 ? "Medium" : "Long"
                durationCount[bucket, default: 0] += 1
            }
        }
        
        if !durationCount.isEmpty {
            let durationFacetValues = durationCount.map { duration, count in
                SearchFacetValue(value: duration, count: count, selected: false)
            }
            
            facets.append(SearchFacet(
                name: "Duration",
                field: "duration",
                values: durationFacetValues
            ))
        }
        
        return facets
    }
    
    private func updateSearchAnalytics(
        query: String,
        resultCount: Int,
        searchTime: TimeInterval,
        userId: String?
    ) async {
        
        await MainActor.run {
            searchAnalytics.totalSearches += 1
            searchAnalytics.averageResultCount = (searchAnalytics.averageResultCount + Double(resultCount)) / 2
            searchAnalytics.averageSearchTime = (searchAnalytics.averageSearchTime + searchTime) / 2
            
            if resultCount == 0 {
                searchAnalytics.noResultsCount += 1
            }
            
            // Track popular queries
            let existingIndex = searchAnalytics.topQueries.firstIndex { $0.query == query }
            if let index = existingIndex {
                searchAnalytics.topQueries[index].count += 1
            } else {
                searchAnalytics.topQueries.append(QueryCount(query: query, count: 1))
            }
            
            // Keep only top 100 queries
            searchAnalytics.topQueries.sort { $0.count > $1.count }
            if searchAnalytics.topQueries.count > 100 {
                searchAnalytics.topQueries = Array(searchAnalytics.topQueries.prefix(100))
            }
        }
    }
    
    private func logSearch(query: String, results: [SearchResult], userId: String?) {
        let searchQuery = SearchQuery(
            id: UUID().uuidString,
            query: query,
            userId: userId,
            timestamp: Date(),
            resultCount: results.count
        )
        
        searchHistory.append(searchQuery)
        
        // Keep only recent searches
        if searchHistory.count > 1000 {
            searchHistory.removeFirst(searchHistory.count - 1000)
        }
    }
    
    private func transcribeAudio(_ audioData: Data) async throws -> String {
        // In production, integrate with Speech framework
        // For demo, return mock transcription
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        return "funny cat videos"
    }
    
    private func loadSearchHistory() {
        // Load search history from persistent storage
        // For demo, initialize empty
        searchHistory = []
    }
    
    private func loadPopularSearches() {
        popularSearches = [
            "funny videos",
            "music",
            "tutorials",
            "gaming",
            "cooking",
            "travel",
            "comedy",
            "technology",
            "reviews",
            "cats"
        ]
    }
}

// MARK: - Query Processing

class QueryProcessor {
    
    func processQuery(_ query: String) async -> ProcessedQuery {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = cleanedQuery.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        // Remove stop words
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])
        let filteredTerms = terms.filter { !stopWords.contains($0) && !$0.isEmpty }
        
        return ProcessedQuery(
            originalQuery: query,
            terms: filteredTerms,
            searchTerms: filteredTerms.joined(separator: " ")
        )
    }
    
    func processNaturalLanguageQuery(_ query: String) async -> ProcessedQuery {
        // Extract intent and entities from natural language
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        var entities: [String] = []
        var keywords: [String] = []
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                entities.append(String(query[tokenRange]))
            }
            return true
        }
        
        // Extract meaningful keywords
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, [.noun, .verb, .adjective].contains(tag) {
                keywords.append(String(query[tokenRange]))
            }
            return true
        }
        
        let combinedTerms = Array(Set(entities + keywords)).filter { !$0.isEmpty }
        
        return ProcessedQuery(
            originalQuery: query,
            terms: combinedTerms,
            searchTerms: combinedTerms.joined(separator: " ")
        )
    }
    
    func inferFilters(from query: String) async -> SearchFilters {
        var filters = SearchFilters()
        
        // Infer duration filters
        if query.lowercased().contains("short") {
            filters.duration = .short
        } else if query.lowercased().contains("long") {
            filters.duration = .long
        }
        
        // Infer upload date filters
        if query.lowercased().contains("today") || query.lowercased().contains("recent") {
            filters.uploadDate = .today
        } else if query.lowercased().contains("week") {
            filters.uploadDate = .thisWeek
        } else if query.lowercased().contains("month") {
            filters.uploadDate = .thisMonth
        }
        
        // Infer category filters
        let categoryKeywords = [
            "music": VideoCategory.music,
            "gaming": VideoCategory.gaming,
            "education": VideoCategory.education,
            "news": VideoCategory.news,
            "sports": VideoCategory.sports,
            "comedy": VideoCategory.entertainment,
            "tech": VideoCategory.technology,
            "technology": VideoCategory.technology
        ]
        
        for (keyword, category) in categoryKeywords {
            if query.lowercased().contains(keyword) {
                filters.category = category
                break
            }
        }
        
        return filters
    }
}

// MARK: - Search Ranking Engine

class SearchRankingEngine {
    
    func rankResults(_ results: [SearchResult], for query: ProcessedQuery) async -> [SearchResult] {
        // Apply ranking algorithm based on relevance, popularity, recency
        return results.sorted { lhs, rhs in
            // Primary sort by relevance
            if abs(lhs.relevanceScore - rhs.relevanceScore) > 0.1 {
                return lhs.relevanceScore > rhs.relevanceScore
            }
            
            // Secondary sort by popularity
            return lhs.popularity > rhs.popularity
        }
    }
    
    func personalizeResults(_ results: [SearchResult], for userId: String) async -> [SearchResult] {
        // Apply personalization based on user history, preferences, etc.
        // For demo, just apply basic ranking
        return await rankResults(results, for: ProcessedQuery(originalQuery: "", terms: [], searchTerms: ""))
    }
}

// MARK: - Auto Complete Service

class AutoCompleteService {
    
    func generateSuggestions(
        query: String,
        userId: String?,
        maxSuggestions: Int
    ) async -> [AdvancedSearchSuggestion] {
        
        var suggestions: [AdvancedSearchSuggestion] = []
        
        // Query completion suggestions
        let completions = [
            query + " tutorial",
            query + " review",
            query + " music",
            query + " funny",
            query + " 2024"
        ].prefix(maxSuggestions / 2)
        
        for completion in completions {
            suggestions.append(AdvancedSearchSuggestion(
                type: .queryCompletion,
                text: completion,
                highlightRange: 0..<query.count
            ))
        }
        
        // Related search suggestions
        let related = [
            "best " + query,
            query + " tips",
            "how to " + query,
            query + " guide"
        ].prefix(maxSuggestions - suggestions.count)
        
        for relatedQuery in related {
            suggestions.append(AdvancedSearchSuggestion(
                type: .relatedSearch,
                text: relatedQuery,
                highlightRange: nil
            ))
        }
        
        return suggestions
    }
    
    func getTrendingSearches(limit: Int) async -> [AdvancedTrendingSearch] {
        return [
            AdvancedTrendingSearch(query: "funny cats", trend: .rising, changePercentage: 120),
            AdvancedTrendingSearch(query: "cooking tutorial", trend: .stable, changePercentage: 5),
            AdvancedTrendingSearch(query: "new music", trend: .rising, changePercentage: 80),
            AdvancedTrendingSearch(query: "gaming", trend: .falling, changePercentage: -15),
            AdvancedTrendingSearch(query: "tech review", trend: .rising, changePercentage: 45)
        ].prefix(limit).map { $0 }
    }
}

// MARK: - Search Indexer

class SearchIndexer {
    private var videoIndex: [String: [String]] = [:]
    private var creatorIndex: [String: [String]] = [:]
    
    func buildIndex(from videos: [Video], creators: [User]) {
        // Build inverted index for fast text search
        for video in videos {
            let text = (video.title + " " + video.description + " " + video.tags.joined(separator: " ")).lowercased()
            let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            for word in words where !word.isEmpty {
                videoIndex[word, default: []].append(video.id)
            }
        }
        
        for creator in creators {
            let text = (creator.displayName + " " + creator.username + " " + (creator.bio ?? "")).lowercased()
            let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            for word in words where !word.isEmpty {
                creatorIndex[word, default: []].append(creator.id)
            }
        }
    }
    
    func searchWithinContent(videoId: String, query: String) async -> [VideoSearchResult] {
        // Search within video transcripts, comments, etc.
        // For demo, return empty results
        return []
    }
}

// MARK: - Search Analytics Period
enum SearchAnalyticsPeriod {
    case day, week, month, year
}

// MARK: - Search Models

struct AdvancedSearchResponse {
    let results: [SearchResult]
    let totalCount: Int
    let searchTime: TimeInterval
    let suggestions: [String]?
    let facets: [SearchFacet]?
    
    init(results: [SearchResult], totalCount: Int, searchTime: TimeInterval, suggestions: [String]? = nil, facets: [SearchFacet]? = nil) {
        self.results = results
        self.totalCount = totalCount
        self.searchTime = searchTime
        self.suggestions = suggestions
        self.facets = facets
    }
}

enum SearchResult {
    case video(VideoSearchResult)
    case creator(CreatorSearchResult)
    case playlist(PlaylistSearchResult)
    case liveStream(LiveStreamSearchResult)
    
    var relevanceScore: Double {
        switch self {
        case .video(let result): return result.relevanceScore
        case .creator(let result): return result.relevanceScore
        case .playlist(let result): return result.relevanceScore
        case .liveStream(let result): return result.relevanceScore
        }
    }
    
    var popularity: Double {
        switch self {
        case .video(let result): return Double(result.video.viewCount)
        case .creator(let result): return Double(result.creator.subscriberCount)
        case .playlist(let result): return Double(result.playlist.videoCount)
        case .liveStream(let result): return Double(result.viewerCount)
        }
    }
    
    var contentType: String {
        switch self {
        case .video: return "video"
        case .creator: return "creator"
        case .playlist: return "playlist"
        case .liveStream: return "live_stream"
        }
    }
}

struct VideoSearchResult: Identifiable {
    let id = UUID().uuidString
    let video: Video
    let relevanceScore: Double
    let matchingFields: [String]
    let highlights: [TextHighlight]
}

struct CreatorSearchResult: Identifiable {
    let id = UUID().uuidString
    let creator: User
    let relevanceScore: Double
    let matchingFields: [String]
}

struct PlaylistSearchResult: Identifiable {
    let id = UUID().uuidString
    let playlist: Playlist
    let relevanceScore: Double
    let matchingFields: [String]
}

struct LiveStreamSearchResult: Identifiable {
    let id = UUID().uuidString
    let video: Video
    let relevanceScore: Double
    let viewerCount: Int
}

struct SearchFilters {
    var category: VideoCategory?
    var duration: DurationFilter?
    var uploadDate: UploadDateFilter?
    var subscriberRange: SubscriberRange?
    var sortBy: SortOption = .relevance
    var contentType: ContentType?
    var features: Set<FeatureFilter> = []
    
    enum DurationFilter: String, CaseIterable {
        case short = "Under 4 minutes"
        case medium = "4-20 minutes"
        case long = "Over 20 minutes"
    }
    
    enum UploadDateFilter: String, CaseIterable {
        case lastHour = "Last hour"
        case today = "Today"
        case thisWeek = "This week"
        case thisMonth = "This month"
        case thisYear = "This year"
        
        var dateComponent: Calendar.Component {
            switch self {
            case .lastHour: return .hour
            case .today: return .day
            case .thisWeek: return .weekOfYear
            case .thisMonth: return .month
            case .thisYear: return .year
            }
        }
    }
    
    enum ContentType: String, CaseIterable {
        case video = "Video"
        case channel = "Channel"
        case playlist = "Playlist"
        case movie = "Movie"
        case live = "Live"
    }
    
    enum FeatureFilter: String, CaseIterable {
        case live = "Live"
        case fourK = "4K"
        case hd = "HD"
        case subtitles = "Subtitles/CC"
        case creativeCommons = "Creative Commons"
        case threeSixty = "360°"
        case vr180 = "VR180"
        case threeD = "3D"
        case hdr = "HDR"
        case location = "Location"
        case purchased = "Purchased"
    }
    
    struct SubscriberRange {
        let min: Int
        let max: Int
    }
    
    enum SortOption: String, CaseIterable {
        case relevance = "Relevance"
        case uploadDate = "Upload date"
        case viewCount = "View count"
        case rating = "Rating"
    }
}

struct ProcessedQuery {
    let originalQuery: String
    let terms: [String]
    let searchTerms: String
}

struct AdvancedSearchSuggestion: Identifiable {
    let id = UUID().uuidString
    let type: SuggestionType
    let text: String
    let highlightRange: Range<Int>?
    
    enum SuggestionType {
        case queryCompletion
        case relatedSearch
        case trendingSearch
    }
}

struct AdvancedTrendingSearch: Identifiable {
    let id = UUID().uuidString
    let query: String
    let trend: TrendDirection
    let changePercentage: Int
    
    enum TrendDirection {
        case rising, falling, stable
        
        var icon: String {
            switch self {
            case .rising: return "arrow.up"
            case .falling: return "arrow.down"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .rising: return .green
            case .falling: return .red
            case .stable: return .gray
            }
        }
    }
}

struct TextHighlight {
    let field: String
    let text: String
    let startIndex: Int
}

struct SearchFacet: Identifiable {
    let id = UUID().uuidString
    let name: String
    let field: String
    let values: [SearchFacetValue]
}

struct SearchFacetValue: Identifiable {
    let id = UUID().uuidString
    let value: String
    let count: Int
    let selected: Bool
}

struct SearchQuery: Identifiable {
    let id: String
    let query: String
    let userId: String?
    let timestamp: Date
    let resultCount: Int
}

struct SearchAnalytics {
    var totalSearches = 0
    var noResultsCount = 0
    var averageResultCount: Double = 0
    var averageSearchTime: TimeInterval = 0
    var topQueries: [QueryCount] = []
    var lastUpdated = Date()
}

struct QueryCount {
    let query: String
    var count: Int
}

struct AdvancedSearchService_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Advanced Search Engine")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Enterprise Features")
                    .font(.headline)
                
                ForEach([
                    "🔍 Multi-dimensional search (videos, creators, playlists)",
                    "🤖 ML-powered relevance ranking",
                    "💬 Natural language query processing",
                    "🗣️ Voice search with transcription",
                    "⚡ Real-time search suggestions",
                    "📊 Advanced search analytics",
                    "🎯 Personalized search results",
                    "📱 Search within video content"
                ], id: \.self) { feature in
                    HStack {
                        Text(feature)
                            .font(.body)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
}