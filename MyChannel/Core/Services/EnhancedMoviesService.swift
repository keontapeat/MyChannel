//
//  EnhancedMoviesService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 🎬 Enterprise Movies Service
// Netflix-level movies platform with ML-powered recommendations
//
// WIRING AUDIT (batch-6):
// - MoviesView hub → FreeCatalogService + MovieLibraryService (primary catalog path)
// - MovieDetailView → MoviePlaybackResolver + GlobalVideoPlayerManager (playback)
// - This service (EnhancedMoviesService) → TMDB + ML Cloud Run agents (premium rows)
// - Fail closed: AppSecrets.tmdbAPIKey empty → hub uses sampleMovies + FreeCatalog only
// - Do not duplicate catalog fetch here until MoviesView migrates to EnhancedMovie model
@MainActor
class EnhancedMoviesService: ObservableObject {
    static let shared = EnhancedMoviesService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var featuredMovies: [EnhancedMovie] = []
    @Published var popularMovies: [EnhancedMovie] = []
    @Published var trendingMovies: [EnhancedMovie] = []
    @Published var recommendedMovies: [EnhancedMovie] = []
    @Published var moviesByGenre: [String: [EnhancedMovie]] = [:]
    @Published var searchResults: [EnhancedMovie] = []
    @Published var watchlist: [EnhancedMovie] = []
    @Published var continueWatching: [WatchProgress] = []
    
    // Performance tracking
    private let cache = NSCache<NSString, NSArray>()
    private var cancellables = Set<AnyCancellable>()
    
    // ML Services Integration
    private let movieRecommendationsURL = "https://movie-recommendations-fkri6ifojq-uc.a.run.app"
    private let contentPersonalizationURL = "https://content-personalization-fkri6ifojq-uc.a.run.app"
    private let movieAnalyticsURL = "https://movie-analytics-fkri6ifojq-uc.a.run.app"
    private let streamingOptimizationURL = "https://streaming-optimization-fkri6ifojq-uc.a.run.app"
    private let movieSearchURL = "https://movie-search-fkri6ifojq-uc.a.run.app"
    private let watchTimePredictonURL = "https://watch-time-predictor-fkri6ifojq-uc.a.run.app"
    private let movieTrendingURL = "https://movie-trending-fkri6ifojq-uc.a.run.app"
    
    // TMDB Integration — fail closed via AppSecrets (no hardcoded keys in source).
    private var tmdbAPIKey: String { AppSecrets.tmdbAPIKey }
    private let tmdbBaseURL = "https://api.themoviedb.org/3"
    
    private init() {
        setupCache()
        startPerformanceTracking()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 2000 // Cache up to 2000 movies
        cache.totalCostLimit = 500 * 1024 * 1024 // 500MB cache limit — poster URLs keyed by tmdb id
    }
    
    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        MonitoringDashboardManager.shared.updateMetric("movies_cache_size", value: Double(cache.totalCostLimit))
        MonitoringDashboardManager.shared.updateMetric("movies_loaded_count", value: Double(featuredMovies.count + popularMovies.count))
    }
    
    // MARK: - Featured Movies
    
    func loadFeaturedMovies(limit: Int = 10) async throws -> [EnhancedMovie] {
        let startTime = Date()
        
        PerformanceMonitoringManager.shared.startTrace(name: "featured_movies_load", attributes: [
            "limit": String(limit)
        ])
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "featured_movies_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
        }
        
        // Check cache first
        let cacheKey = "featured_movies_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedMovie] {
            featuredMovies = cachedResults
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load featured movies from TMDB
            let tmdbMovies = try await loadTMDBMovies(endpoint: "/movie/popular", limit: limit)
            
            // Enhance with ML personalization
            let enhancedMovies = await enhanceMoviesWithML(tmdbMovies, type: "featured")
            
            // Cache results
            cache.setObject(enhancedMovies as NSArray, forKey: cacheKey)
            
            featuredMovies = enhancedMovies
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("featured_movies_loaded", parameters: [
                "count": enhancedMovies.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isLoading = false
            return enhancedMovies
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "FeaturedMoviesLoad",
                severity: .warning
            )
            
            throw error
        }
    }
    
    // MARK: - Popular Movies
    
    func loadPopularMovies(limit: Int = 20) async throws -> [EnhancedMovie] {
        let cacheKey = "popular_movies_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedMovie] {
            popularMovies = cachedResults
            return cachedResults
        }
        
        do {
            let tmdbMovies = try await loadTMDBMovies(endpoint: "/movie/popular", limit: limit)
            let enhancedMovies = await enhanceMoviesWithML(tmdbMovies, type: "popular")
            
            cache.setObject(enhancedMovies as NSArray, forKey: cacheKey)
            popularMovies = enhancedMovies
            
            return enhancedMovies
        } catch {
            throw error
        }
    }
    
    // MARK: - Trending Movies
    
    func loadTrendingMovies(timeWindow: String = "day", limit: Int = 20) async throws -> [EnhancedMovie] {
        let cacheKey = "trending_movies_\(timeWindow)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedMovie] {
            trendingMovies = cachedResults
            return cachedResults
        }
        
        do {
            let tmdbMovies = try await loadTMDBMovies(endpoint: "/trending/movie/\(timeWindow)", limit: limit)
            let enhancedMovies = await enhanceMoviesWithML(tmdbMovies, type: "trending")
            
            cache.setObject(enhancedMovies as NSArray, forKey: cacheKey)
            trendingMovies = enhancedMovies
            
            return enhancedMovies
        } catch {
            throw error
        }
    }
    
    // MARK: - Personalized Recommendations
    
    func loadPersonalizedRecommendations(userId: String, limit: Int = 20) async throws -> [EnhancedMovie] {
        let request = MovieRecommendationRequest(
            userId: userId,
            limit: limit,
            includeWatchHistory: true,
            includePreferences: true,
            diversityFactor: 0.3
        )
        
        let response = try await performMLRequest(
            url: movieRecommendationsURL + "/personalized",
            request: request,
            responseType: MovieRecommendationResponse.self
        )
        
        let movies = try await convertRecommendationsToMovies(response.recommendations)
        recommendedMovies = movies
        
        EnhancedAnalyticsManager.shared.logEvent("personalized_movies_loaded", parameters: [
            "user_id": userId,
            "count": movies.count,
            "recommendation_score": response.averageScore
        ])
        
        return movies
    }
    
    // MARK: - Movies by Genre
    
    func loadMoviesByGenre(genre: String, limit: Int = 20) async throws -> [EnhancedMovie] {
        let cacheKey = "genre_movies_\(genre)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedMovie] {
            return cachedResults
        }
        
        do {
            let genreId = getGenreId(for: genre)
            let tmdbMovies = try await loadTMDBMovies(endpoint: "/discover/movie", parameters: [
                "with_genres": String(genreId),
                "sort_by": "popularity.desc"
            ], limit: limit)
            
            let enhancedMovies = await enhanceMoviesWithML(tmdbMovies, type: "genre")
            
            cache.setObject(enhancedMovies as NSArray, forKey: cacheKey)
            moviesByGenre[genre] = enhancedMovies
            
            return enhancedMovies
        } catch {
            throw error
        }
    }
    
    // MARK: - Movie Search
    
    func searchMovies(query: String, filters: MovieSearchFilters? = nil) async throws -> [EnhancedMovie] {
        guard !query.isEmpty else { return [] }
        
        let request = MovieSearchRequest(
            query: query,
            filters: filters,
            useML: true,
            includeSimilar: true
        )
        
        let response = try await performMLRequest(
            url: movieSearchURL + "/search",
            request: request,
            responseType: MovieSearchResponse.self
        )
        
        let movies = try await convertSearchResultsToMovies(response.results)
        searchResults = movies
        
        EnhancedAnalyticsManager.shared.logEvent("movies_searched", parameters: [
            "query": query,
            "result_count": movies.count,
            "has_filters": filters != nil
        ])
        
        return movies
    }
    
    // MARK: - Watchlist Management
    
    func addToWatchlist(movieId: String, userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("users").document(userId)
            .collection("watchlist").document(movieId).setData([
                "movieId": movieId,
                "addedAt": FieldValue.serverTimestamp(),
                "priority": "normal"
            ])
        
        // Update local watchlist
        if let movie = findMovie(by: movieId) {
            if !watchlist.contains(where: { $0.id == movieId }) {
                watchlist.append(movie)
            }
        }
        
        EnhancedAnalyticsManager.shared.logEvent("movie_added_to_watchlist", parameters: [
            "movie_id": movieId,
            "user_id": userId
        ])
        #endif
    }
    
    func removeFromWatchlist(movieId: String, userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("users").document(userId)
            .collection("watchlist").document(movieId).delete()
        
        // Update local watchlist
        watchlist.removeAll { $0.id == movieId }
        
        EnhancedAnalyticsManager.shared.logEvent("movie_removed_from_watchlist", parameters: [
            "movie_id": movieId,
            "user_id": userId
        ])
        #endif
    }
    
    func loadWatchlist(userId: String) async throws -> [EnhancedMovie] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("users").document(userId)
            .collection("watchlist").getDocuments()
        
        let movieIds = snapshot.documents.map { $0.documentID }
        let movies = await loadMoviesByIds(movieIds)
        
        watchlist = movies
        return movies
        #else
        return []
        #endif
    }
    
    // MARK: - Continue Watching
    
    func loadContinueWatching(userId: String) async throws -> [WatchProgress] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("users").document(userId)
            .collection("watch_progress")
            .whereField("progress", isGreaterThan: 0.05)
            .whereField("progress", isLessThan: 0.95)
            .order(by: "lastWatchedAt", descending: true)
            .limit(to: 10)
            .getDocuments()
        
        let watchProgress = snapshot.documents.compactMap { doc -> WatchProgress? in
            let data = doc.data()
            guard let movieId = data["movieId"] as? String,
                  let progress = data["progress"] as? Double,
                  let lastWatchedAt = (data["lastWatchedAt"] as? Timestamp)?.dateValue() else {
                return nil
            }
            
            return WatchProgress(
                id: "\(userId)_\(movieId)",
                userId: userId,
                videoId: movieId,
                positionSec: data["currentTime"] as? TimeInterval ?? 0,
                durationSec: data["duration"] as? TimeInterval ?? 0,
                completionPct: progress,
                lastWatchedAt: lastWatchedAt
            )
        }
        
        // Load movie details for each progress item
        let enhancedProgress = await withTaskGroup(of: WatchProgress?.self) { group in
            for progress in watchProgress {
                group.addTask {
                    if let _ = await self.loadMovieById(progress.videoId) {
                        // Movie exists, return progress as-is
                        return progress
                    }
                    return nil
                }
            }
            
            var results: [WatchProgress] = []
            for await progress in group {
                if let progress = progress {
                    results.append(progress)
                }
            }
            return results
        }
        
        continueWatching = enhancedProgress
        return enhancedProgress
        #else
        return []
        #endif
    }
    
    // MARK: - TMDB Integration
    
    private func loadTMDBMovies(endpoint: String, parameters: [String: String] = [:], limit: Int = 20) async throws -> [TMDBMovie] {
        guard !tmdbAPIKey.isEmpty else {
            throw MoviesServiceError.tmdbError
        }

        var urlComponents = URLComponents(string: tmdbBaseURL + endpoint)!
        
        var queryItems = [
            URLQueryItem(name: "api_key", value: tmdbAPIKey),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1")
        ]
        
        for (key, value) in parameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw MoviesServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.configured.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            // TMDB rate limit — exponential backoff (batch-7)
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let (retryData, retryResponse) = try await URLSession.configured.data(from: url)
            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  200...299 ~= retryHTTP.statusCode else {
                throw MoviesServiceError.tmdbError
            }
            let tmdbResponse = try JSONDecoder().decode(TMDBResponse.self, from: retryData)
            return Array(tmdbResponse.results.prefix(limit))
        }

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw MoviesServiceError.tmdbError
        }
        
        let tmdbResponse = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return Array(tmdbResponse.results.prefix(limit))
    }
    
    private func enhanceMoviesWithML(_ tmdbMovies: [TMDBMovie], type: String) async -> [EnhancedMovie] {
        guard RemoteConfigManager.shared.isMLEnhancementEnabled else {
            return tmdbMovies.map { convertTMDBToEnhanced($0) }
        }
        
        return await withTaskGroup(of: EnhancedMovie.self) { group in
            for tmdbMovie in tmdbMovies {
                group.addTask {
                    await self.enhanceMovieWithML(tmdbMovie, type: type)
                }
            }
            
            var enhancedMovies: [EnhancedMovie] = []
            for await movie in group {
                enhancedMovies.append(movie)
            }
            
            // Maintain original order
            return tmdbMovies.compactMap { originalMovie in
                enhancedMovies.first { $0.tmdbId == originalMovie.id }
            }
        }
    }
    
    private func enhanceMovieWithML(_ tmdbMovie: TMDBMovie, type: String) async -> EnhancedMovie {
        do {
            let request = MovieEnhancementRequest(
                tmdbId: tmdbMovie.id,
                title: tmdbMovie.title,
                overview: tmdbMovie.overview,
                genres: tmdbMovie.genreIds,
                releaseDate: tmdbMovie.releaseDate,
                voteAverage: tmdbMovie.voteAverage,
                popularity: tmdbMovie.popularity,
                enhancementType: type
            )
            
            let response = try await performMLRequest(
                url: contentPersonalizationURL + "/enhance",
                request: request,
                responseType: MovieEnhancementResponse.self
            )
            
            return EnhancedMovie(
                id: UUID().uuidString,
                tmdbId: tmdbMovie.id,
                title: tmdbMovie.title,
                originalTitle: tmdbMovie.originalTitle,
                overview: tmdbMovie.overview,
                releaseDate: tmdbMovie.releaseDate,
                posterPath: tmdbMovie.posterPath,
                backdropPath: tmdbMovie.backdropPath,
                genreIds: tmdbMovie.genreIds,
                voteAverage: tmdbMovie.voteAverage,
                voteCount: tmdbMovie.voteCount,
                popularity: tmdbMovie.popularity,
                adult: tmdbMovie.adult,
                originalLanguage: tmdbMovie.originalLanguage,
                runtime: response.runtime,
                budget: response.budget,
                revenue: response.revenue,
                genres: response.genres,
                productionCompanies: response.productionCompanies,
                cast: response.cast,
                director: response.director,
                writers: response.writers,
                trailerURL: response.trailerURL,
                streamingProviders: response.streamingProviders,
                personalizedScore: response.personalizedScore,
                recommendationReason: response.recommendationReason,
                similarMovies: response.similarMovies,
                watchPrediction: response.watchPrediction,
                mlInsights: MovieMLInsights(
                    personalizedScore: response.personalizedScore,
                    watchProbability: response.watchPrediction,
                    genreMatch: response.genreMatch,
                    moodMatch: response.moodMatch,
                    qualityScore: response.qualityScore,
                    trendingScore: response.trendingScore,
                    recommendationFactors: response.recommendationFactors
                )
            )
            
        } catch {
            // Return basic movie if ML enhancement fails
            return convertTMDBToEnhanced(tmdbMovie)
        }
    }
    
    private func convertTMDBToEnhanced(_ tmdbMovie: TMDBMovie) -> EnhancedMovie {
        return EnhancedMovie(
            id: UUID().uuidString,
            tmdbId: tmdbMovie.id,
            title: tmdbMovie.title,
            originalTitle: tmdbMovie.originalTitle,
            overview: tmdbMovie.overview,
            releaseDate: tmdbMovie.releaseDate,
            posterPath: tmdbMovie.posterPath,
            backdropPath: tmdbMovie.backdropPath,
            genreIds: tmdbMovie.genreIds,
            voteAverage: tmdbMovie.voteAverage,
            voteCount: tmdbMovie.voteCount,
            popularity: tmdbMovie.popularity,
            adult: tmdbMovie.adult,
            originalLanguage: tmdbMovie.originalLanguage,
            runtime: 0,
            budget: 0,
            revenue: 0,
            genres: [],
            productionCompanies: [],
            cast: [],
            director: "",
            writers: [],
            trailerURL: "",
            streamingProviders: [],
            personalizedScore: 0.5,
            recommendationReason: "",
            similarMovies: [],
            watchPrediction: 0.5,
            mlInsights: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadMovieById(_ movieId: String) async -> EnhancedMovie? {
        // Check all loaded movies first
        let allMovies = featuredMovies + popularMovies + trendingMovies + recommendedMovies
        if let movie = allMovies.first(where: { $0.id == movieId || String($0.tmdbId) == movieId }) {
            return movie
        }
        
        // Load from TMDB if not found
        do {
            let tmdbMovies = try await loadTMDBMovies(endpoint: "/movie/\(movieId)", limit: 1)
            if let tmdbMovie = tmdbMovies.first {
                return await enhanceMovieWithML(tmdbMovie, type: "individual")
            }
        } catch {
            print("Failed to load movie by ID: \(error)")
        }
        
        return nil
    }
    
    private func loadMoviesByIds(_ movieIds: [String]) async -> [EnhancedMovie] {
        return await withTaskGroup(of: EnhancedMovie?.self) { group in
            for movieId in movieIds {
                group.addTask {
                    await self.loadMovieById(movieId)
                }
            }
            
            var movies: [EnhancedMovie] = []
            for await movie in group {
                if let movie = movie {
                    movies.append(movie)
                }
            }
            return movies
        }
    }
    
    private func findMovie(by movieId: String) -> EnhancedMovie? {
        let allMovies = featuredMovies + popularMovies + trendingMovies + recommendedMovies
        return allMovies.first { $0.id == movieId || String($0.tmdbId) == movieId }
    }
    
    private func convertRecommendationsToMovies(_ recommendations: [MovieRecommendation]) async throws -> [EnhancedMovie] {
        let movieIds = recommendations.map { String($0.tmdbId) }
        return await loadMoviesByIds(movieIds)
    }
    
    private func convertSearchResultsToMovies(_ results: [MovieSearchResult]) async throws -> [EnhancedMovie] {
        let movieIds = results.map { String($0.tmdbId) }
        return await loadMoviesByIds(movieIds)
    }
    
    private func getGenreId(for genre: String) -> Int {
        let genreMap: [String: Int] = [
            "Action": 28,
            "Adventure": 12,
            "Animation": 16,
            "Comedy": 35,
            "Crime": 80,
            "Documentary": 99,
            "Drama": 18,
            "Family": 10751,
            "Fantasy": 14,
            "History": 36,
            "Horror": 27,
            "Music": 10402,
            "Mystery": 9648,
            "Romance": 10749,
            "Science Fiction": 878,
            "TV Movie": 10770,
            "Thriller": 53,
            "War": 10752,
            "Western": 37
        ]
        
        return genreMap[genre] ?? 28 // Default to Action
    }
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw MoviesServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw MoviesServiceError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct EnhancedMovie: Identifiable, Codable {
    let id: String
    let tmdbId: Int
    let title: String
    let originalTitle: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let backdropPath: String?
    let genreIds: [Int]
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let adult: Bool
    let originalLanguage: String
    
    // Enhanced details
    let runtime: Int
    let budget: Int
    let revenue: Int
    let genres: [Genre]
    let productionCompanies: [ProductionCompany]
    let cast: [CastMember]
    let director: String
    let writers: [String]
    let trailerURL: String
    let streamingProviders: [StreamingProvider]
    
    // ML Enhancement
    let personalizedScore: Double
    let recommendationReason: String
    let similarMovies: [Int]
    let watchPrediction: Double
    let mlInsights: MovieMLInsights?
    
    // Computed properties
    var fullPosterURL: String {
        guard let posterPath = posterPath else { return "" }
        return "https://image.tmdb.org/t/p/w500\(posterPath)"
    }
    
    var fullBackdropURL: String {
        guard let backdropPath = backdropPath else { return "" }
        return "https://image.tmdb.org/t/p/w1280\(backdropPath)"
    }
    
    var formattedRating: String {
        return String(format: "%.1f", voteAverage)
    }
    
    var formattedRuntime: String {
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var releaseYear: String {
        return String(releaseDate.prefix(4))
    }
    
    var isNewRelease: Bool {
        let releaseYear = Int(self.releaseYear) ?? 0
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - releaseYear <= 1
    }
    
    var qualityBadge: String {
        if voteAverage >= 8.0 { return "🏆 Acclaimed" }
        else if voteAverage >= 7.0 { return "⭐ Highly Rated" }
        else if isNewRelease { return "🆕 New" }
        else if popularity > 100 { return "🔥 Popular" }
        else { return "" }
    }
}

struct MovieWatchProgress: Identifiable, Codable {
    let id = UUID().uuidString
    let movieId: String
    let userId: String
    let progress: Double
    let currentTime: TimeInterval
    let duration: TimeInterval
    let lastWatchedAt: Date
    var movie: EnhancedMovie?
    
    var progressPercentage: String {
        return "\(Int(progress * 100))%"
    }
    
    var remainingTime: String {
        let remaining = duration - currentTime
        let minutes = Int(remaining) / 60
        return "\(minutes) min left"
    }
}

struct MovieMLInsights: Codable {
    let personalizedScore: Double
    let watchProbability: Double
    let genreMatch: Double
    let moodMatch: Double
    let qualityScore: Double
    let trendingScore: Double
    let recommendationFactors: [String]
}

struct Genre: Codable {
    let id: Int
    let name: String
}

struct ProductionCompany: Codable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String
}

struct CastMember: Codable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int
}

struct StreamingProvider: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String
    let displayPriority: Int
    let link: String
}

struct MovieSearchFilters: Codable {
    let genres: [Int]?
    let releaseYear: Int?
    let minRating: Double?
    let maxRuntime: Int?
    let language: String?
    let includeAdult: Bool
}

// MARK: - TMDB Types

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let originalTitle: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let backdropPath: String?
    let genreIds: [Int]
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let adult: Bool
    let originalLanguage: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, adult, popularity
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case genreIds = "genre_ids"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
    }
}

struct TMDBResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - ML Request/Response Types

struct MovieRecommendationRequest: Codable {
    let userId: String
    let limit: Int
    let includeWatchHistory: Bool
    let includePreferences: Bool
    let diversityFactor: Double
}

struct MovieRecommendationResponse: Codable {
    let recommendations: [MovieRecommendation]
    let averageScore: Double
    let diversityScore: Double
}

struct MovieRecommendation: Codable {
    let tmdbId: Int
    let score: Double
    let reason: String
    let confidence: Double
}

struct MovieSearchRequest: Codable {
    let query: String
    let filters: MovieSearchFilters?
    let useML: Bool
    let includeSimilar: Bool
}

struct MovieSearchResponse: Codable {
    let results: [MovieSearchResult]
    let totalResults: Int
    let searchTime: Double
}

struct MovieSearchResult: Codable {
    let tmdbId: Int
    let relevanceScore: Double
    let matchType: String
}

struct MovieEnhancementRequest: Codable {
    let tmdbId: Int
    let title: String
    let overview: String
    let genres: [Int]
    let releaseDate: String
    let voteAverage: Double
    let popularity: Double
    let enhancementType: String
}

struct MovieEnhancementResponse: Codable {
    let runtime: Int
    let budget: Int
    let revenue: Int
    let genres: [Genre]
    let productionCompanies: [ProductionCompany]
    let cast: [CastMember]
    let director: String
    let writers: [String]
    let trailerURL: String
    let streamingProviders: [StreamingProvider]
    let personalizedScore: Double
    let recommendationReason: String
    let similarMovies: [Int]
    let watchPrediction: Double
    let genreMatch: Double
    let moodMatch: Double
    let qualityScore: Double
    let trendingScore: Double
    let recommendationFactors: [String]
}

// MARK: - Error Types

enum MoviesServiceError: LocalizedError {
    case invalidURL
    case tmdbError
    case serverError
    case noResults
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .tmdbError:
            return "TMDB service error"
        case .serverError:
            return "Server error occurred"
        case .noResults:
            return "No results found"
        case .cacheError:
            return "Cache error occurred"
        }
    }
}
