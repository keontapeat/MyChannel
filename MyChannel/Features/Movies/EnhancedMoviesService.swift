//
//  EnhancedMoviesService.swift
//  MyChannel
//
//  Enhanced movies service with caching, offline support, and improved streaming
//

import Foundation
import SwiftUI

@MainActor
class EnhancedMoviesService: ObservableObject {
    static let shared = EnhancedMoviesService()
    
    @Published var popularMovies: [FreeMovie] = []
    @Published var trendingMovies: [FreeMovie] = []
    @Published var recentlyWatched: [FreeMovie] = []
    @Published var watchlist: [FreeMovie] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let cache = MovieCache()
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Seed popular movies from pre-loaded Home data (avoids double-fetching)
    func seedPopular(_ movies: [FreeMovie]) {
        guard popularMovies.isEmpty, !movies.isEmpty else { return }
        popularMovies = movies
    }
    
    func loadPopularMovies(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        
        if !forceRefresh, let cached = cache.getPopularMovies(), !cached.isEmpty {
            popularMovies = cached
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let movies = try await fetchPopularMovies()
            popularMovies = movies
            cache.setPopularMovies(movies)
        } catch {
            self.error = error.localizedDescription
            // Fallback to sample data
            popularMovies = FreeMovie.sampleMovies
        }
        
        isLoading = false
    }
    
    func loadTrendingMovies() async {
        do {
            let movies = try await TMDBService.shared.fetchPopularWithTrailersUS(page: 1, limit: 20)
            trendingMovies = movies.filter { $0.trailerURL != nil }
            cache.setTrendingMovies(trendingMovies)
        } catch {
            print("Failed to load trending movies: \(error)")
            trendingMovies = Array(FreeMovie.sampleMovies.prefix(10))
        }
    }
    
    func searchMovies(query: String, filters: MovieFilters = MovieFilters()) async -> [FreeMovie] {
        do {
            let results = await FreeCatalogService.shared.searchAll(query: query, limitPerSource: 15)
            return applyFilters(results, filters: filters)
        } catch {
            print("Search failed: \(error)")
            return []
        }
    }
    
    func addToWatchlist(_ movie: FreeMovie) {
        if !watchlist.contains(where: { $0.id == movie.id }) {
            watchlist.append(movie)
            saveWatchlist()
        }
    }
    
    func removeFromWatchlist(_ movie: FreeMovie) {
        watchlist.removeAll { $0.id == movie.id }
        saveWatchlist()
    }
    
    func isInWatchlist(_ movie: FreeMovie) -> Bool {
        watchlist.contains { $0.id == movie.id }
    }
    
    func addToRecentlyWatched(_ movie: FreeMovie) {
        recentlyWatched.removeAll { $0.id == movie.id }
        recentlyWatched.insert(movie, at: 0)
        if recentlyWatched.count > 20 {
            recentlyWatched = Array(recentlyWatched.prefix(20))
        }
        saveRecentlyWatched()
    }
    
    // MARK: - Private Methods
    
    private func fetchPopularMovies() async throws -> [FreeMovie] {
        // Try multiple sources for better content variety
        async let tmdbMovies = TMDBService.shared.fetchPopularWithTrailersUS(page: 1, limit: 25)
        async let freeMovies = TMDBService.shared.fetchFreeWithAdsMoviesUS(page: 1, limit: 15)
        
        let (tmdb, free) = try await (tmdbMovies, freeMovies)
        
        // Combine and deduplicate
        var combined = tmdb + free
        var seen = Set<String>()
        combined = combined.filter { seen.insert($0.id).inserted }
        
        // Sort by quality and recency
        combined.sort { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            if lhs.imdbRating != rhs.imdbRating { return lhs.imdbRating > rhs.imdbRating }
            return lhs.trailerURL != nil && rhs.trailerURL == nil
        }
        
        return Array(combined.prefix(30))
    }
    
    private func applyFilters(_ movies: [FreeMovie], filters: MovieFilters) -> [FreeMovie] {
        var filtered = movies
        
        if let genre = filters.genre {
            filtered = filtered.filter { $0.genre.contains(genre) }
        }
        
        if let source = filters.streamingSource {
            filtered = filtered.filter { $0.streamingSource == source }
        }
        
        if let minRating = filters.minimumRating {
            filtered = filtered.filter { $0.imdbRating >= minRating }
        }
        
        if let minYear = filters.minimumYear {
            filtered = filtered.filter { $0.year >= minYear }
        }
        
        return filtered
    }
    
    private func loadCachedData() {
        if let data = userDefaults.data(forKey: "watchlist"),
           let decoded = try? JSONDecoder().decode([FreeMovie].self, from: data) {
            watchlist = decoded
        }
        
        if let data = userDefaults.data(forKey: "recentlyWatched"),
           let decoded = try? JSONDecoder().decode([FreeMovie].self, from: data) {
            recentlyWatched = decoded
        }
    }
    
    private func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(watchlist) {
            userDefaults.set(encoded, forKey: "watchlist")
        }
    }
    
    private func saveRecentlyWatched() {
        if let encoded = try? JSONEncoder().encode(recentlyWatched) {
            userDefaults.set(encoded, forKey: "recentlyWatched")
        }
    }
}

// MARK: - Supporting Types

struct MovieFilters {
    var genre: FreeMovie.MovieGenre?
    var streamingSource: FreeMovie.StreamingSource?
    var minimumRating: Double?
    var minimumYear: Int?
    var sortBy: MovieSortOption = .popular
}

enum MovieSortOption: String, CaseIterable {
    case popular = "popular"
    case newest = "newest"
    case rating = "rating"
    case alphabetical = "alphabetical"
    
    var displayName: String {
        switch self {
        case .popular: return "🔥 Popular"
        case .newest: return "🆕 Newest"
        case .rating: return "⭐ Rating"
        case .alphabetical: return "🔤 A-Z"
        }
    }
}

// MARK: - Movie Cache

private class MovieCache {
    private let cache = NSCache<NSString, NSArray>()
    private let expirationTime: TimeInterval = 3600 // 1 hour
    private let userDefaults = UserDefaults.standard
    
    init() {
        cache.countLimit = 50
        cache.totalCostLimit = 1024 * 1024 * 10 // 10MB
    }
    
    func getPopularMovies() -> [FreeMovie]? {
        let key = "popular_movies"
        if let cached = cache.object(forKey: key as NSString) as? [FreeMovie] {
            return cached
        }
        
        // Try persistent cache
        if let timestamp = userDefaults.object(forKey: "\(key)_timestamp") as? Date,
           Date().timeIntervalSince(timestamp) < expirationTime,
           let data = userDefaults.data(forKey: key),
           let movies = try? JSONDecoder().decode([FreeMovie].self, from: data) {
            cache.setObject(movies as NSArray, forKey: key as NSString)
            return movies
        }
        
        return nil
    }
    
    func setPopularMovies(_ movies: [FreeMovie]) {
        let key = "popular_movies"
        cache.setObject(movies as NSArray, forKey: key as NSString)
        
        // Persist to UserDefaults
        if let data = try? JSONEncoder().encode(movies) {
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: "\(key)_timestamp")
        }
    }
    
    func getTrendingMovies() -> [FreeMovie]? {
        let key = "trending_movies"
        return cache.object(forKey: key as NSString) as? [FreeMovie]
    }
    
    func setTrendingMovies(_ movies: [FreeMovie]) {
        let key = "trending_movies"
        cache.setObject(movies as NSArray, forKey: key as NSString)
    }
}

// MARK: - Movie Recommendations Engine

extension EnhancedMoviesService {
    func getRecommendations(basedOn movie: FreeMovie) -> [FreeMovie] {
        let allMovies = popularMovies + trendingMovies
        
        // Find similar movies based on genre, year, and rating
        let similar = allMovies.filter { candidate in
            candidate.id != movie.id &&
            !Set(candidate.genre).intersection(Set(movie.genre)).isEmpty &&
            abs(candidate.year - movie.year) <= 5 &&
            abs(candidate.imdbRating - movie.imdbRating) <= 2.0
        }
        
        return Array(similar.prefix(6))
    }
    
    func getPersonalizedRecommendations() -> [FreeMovie] {
        guard !recentlyWatched.isEmpty else {
            return Array(popularMovies.prefix(10))
        }
        
        // Analyze user preferences from recently watched
        let preferredGenres = Set(recentlyWatched.flatMap { $0.genre })
        let averageRating = recentlyWatched.map { $0.imdbRating }.reduce(0, +) / Double(recentlyWatched.count)
        
        let allMovies = popularMovies + trendingMovies
        let recommended = allMovies.filter { movie in
            !recentlyWatched.contains { $0.id == movie.id } &&
            !Set(movie.genre).intersection(preferredGenres).isEmpty &&
            movie.imdbRating >= averageRating - 1.0
        }
        
        return Array(recommended.prefix(15))
    }
}
