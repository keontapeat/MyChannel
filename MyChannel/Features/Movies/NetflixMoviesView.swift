//
//  NetflixMoviesView.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 🎬 Netflix-Professional Movies Interface
// Industry-leading movies platform with enterprise backend
struct NetflixMoviesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var moviesService = EnhancedMoviesService.shared
    @State private var searchText = ""
    @State private var selectedCategory: MovieCategory = .popular
    @State private var selectedGenre: String = "All"
    @State private var showingSearch = false
    @State private var showingFilters = false
    @State private var selectedMovie: EnhancedMovie?
    @State private var showingMovieDetails = false
    @State private var isRefreshing = false
    
    private let genres = ["All", "Action", "Comedy", "Drama", "Horror", "Romance", "Sci-Fi", "Thriller", "Animation", "Documentary"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Netflix-style dark background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Hero Section
                        if let featuredMovie = moviesService.featuredMovies.first {
                            heroSection(featuredMovie)
                        }
                        
                        // Quick Access Bar
                        quickAccessBar
                        
                        // Continue Watching
                        if !moviesService.continueWatching.isEmpty {
                            continueWatchingSection
                        }
                        
                        // Personalized Recommendations
                        if !moviesService.recommendedMovies.isEmpty {
                            movieRowSection(
                                title: "Recommended for You",
                                movies: moviesService.recommendedMovies,
                                style: .large
                            )
                        }
                        
                        // Trending Now
                        if !moviesService.trendingMovies.isEmpty {
                            movieRowSection(
                                title: "🔥 Trending Now",
                                movies: moviesService.trendingMovies,
                                style: .medium
                            )
                        }
                        
                        // Popular Movies
                        if !moviesService.popularMovies.isEmpty {
                            movieRowSection(
                                title: "Popular Movies",
                                movies: moviesService.popularMovies,
                                style: .medium
                            )
                        }
                        
                        // Genre-based Sections
                        ForEach(Array(moviesService.moviesByGenre.keys.sorted()), id: \.self) { genre in
                            if let movies = moviesService.moviesByGenre[genre], !movies.isEmpty {
                                movieRowSection(
                                    title: genre,
                                    movies: movies,
                                    style: .small
                                )
                            }
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 100)
                    }
                }
                .refreshable {
                    await refreshContent()
                }
                
                // Search overlay
                if showingSearch {
                    searchOverlay
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadInitialContent()
            }
            .sheet(item: $selectedMovie) { movie in
                MovieDetailsSheet(movie: movie)
                    .environmentObject(moviesService)
            }
        }
    }
    
    // MARK: - Hero Section
    
    private func heroSection(_ movie: EnhancedMovie) -> some View {
        ZStack(alignment: .bottom) {
            // Background image
            AsyncImage(url: URL(string: movie.fullBackdropURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(height: 500)
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 500)
            
            // Content overlay
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                
                // Top navigation
                HStack {
                    Button(action: {}) {
                        Image("MC")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: { showingSearch.toggle() }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Movie info
                VStack(alignment: .leading, spacing: 12) {
                    // Netflix Original badge
                    if movie.isNewRelease {
                        HStack {
                            Text("N")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.red)
                                .cornerRadius(2)
                            
                            Text("ORIGINAL")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                        }
                    }
                    
                    // Title
                    Text(movie.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    // Metadata
                    HStack(spacing: 8) {
                        Text(movie.releaseYear)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 4, height: 4)
                        
                        Text(movie.formattedRuntime)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 4, height: 4)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            
                            Text(movie.formattedRating)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // Description
                    Text(movie.overview)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                        .padding(.vertical, 4)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Play button
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white)
                            .cornerRadius(6)
                        }
                        
                        // My List button
                        Button(action: {
                            Task {
                                await toggleWatchlist(movie)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16))
                                
                                Text("My List")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(6)
                        }
                        
                        // Info button
                        Button(action: {
                            selectedMovie = movie
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Quick Access Bar
    
    private var quickAccessBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(MovieCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        Task {
                            await loadCategoryContent(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.black)
    }
    
    // MARK: - Continue Watching Section
    
    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue Watching")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(moviesService.continueWatching) { progress in
                        ContinueWatchingCard(progress: progress) {
                            // Resume watching
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Movie Row Section
    
    private func movieRowSection(title: String, movies: [EnhancedMovie], style: MovieCardStyle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    // Show all movies in category
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(movies) { movie in
                        MovieCard(movie: movie, style: style) {
                            selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Overlay
    
    private var searchOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    showingSearch = false
                }
            
            VStack(spacing: 0) {
                // Search header
                HStack {
                    Button("Cancel") {
                        showingSearch = false
                        searchText = ""
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Search")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 60) // Balance
                }
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Search movies, actors, directors...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .onSubmit {
                            Task {
                                await searchMovies()
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            moviesService.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Search results
                if !moviesService.searchResults.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                            ForEach(moviesService.searchResults) { movie in
                                MovieCard(movie: movie, style: .small) {
                                    selectedMovie = movie
                                    showingSearch = false
                                }
                            }
                        }
                        .padding()
                    }
                } else if !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No results found")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Try different keywords")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadInitialContent() async {
        isRefreshing = true
        
        do {
            async let featured = moviesService.loadFeaturedMovies()
            async let popular = moviesService.loadPopularMovies()
            async let trending = moviesService.loadTrendingMovies()
            
            if let userId = appState.currentUser?.id {
                async let recommended = moviesService.loadPersonalizedRecommendations(userId: userId)
                async let continueWatching = moviesService.loadContinueWatching(userId: userId)
                async let watchlist = moviesService.loadWatchlist(userId: userId)
                
                let _ = try await (featured, popular, trending, recommended, continueWatching, watchlist)
            } else {
                let _ = try await (featured, popular, trending)
            }
            
            // Load genre-based content
            for genre in ["Action", "Comedy", "Drama", "Horror"] {
                let _ = try await moviesService.loadMoviesByGenre(genre: genre)
            }
            
        } catch {
            print("Failed to load initial content: \(error)")
        }
        
        isRefreshing = false
    }
    
    private func refreshContent() async {
        await loadInitialContent()
        HapticManager.shared.impact(style: .light)
    }
    
    private func loadCategoryContent(_ category: MovieCategory) async {
        switch category {
        case .popular:
            let _ = try? await moviesService.loadPopularMovies()
        case .trending:
            let _ = try? await moviesService.loadTrendingMovies()
        case .forYou:
            if let userId = appState.currentUser?.id {
                let _ = try? await moviesService.loadPersonalizedRecommendations(userId: userId)
            }
        }
    }
    
    private func searchMovies() async {
        guard !searchText.isEmpty else { return }
        
        do {
            let _ = try await moviesService.searchMovies(query: searchText)
        } catch {
            print("Search failed: \(error)")
        }
    }
    
    private func toggleWatchlist(_ movie: EnhancedMovie) async {
        guard let userId = appState.currentUser?.id else { return }
        
        do {
            if moviesService.watchlist.contains(where: { $0.id == movie.id }) {
                try await moviesService.removeFromWatchlist(movieId: movie.id, userId: userId)
            } else {
                try await moviesService.addToWatchlist(movieId: movie.id, userId: userId)
            }
        } catch {
            print("Watchlist toggle failed: \(error)")
        }
    }
}

// MARK: - Supporting Views

enum MovieCategory: String, CaseIterable {
    case popular = "Popular"
    case trending = "Trending"
    case forYou = "For You"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .popular: return "flame"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .forYou: return "person.crop.circle"
        }
    }
}

enum MovieCardStyle {
    case small, medium, large
    
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 120, height: 180)
        case .medium: return CGSize(width: 140, height: 210)
        case .large: return CGSize(width: 160, height: 240)
        }
    }
}

struct CategoryButton: View {
    let category: MovieCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.red : Color.white.opacity(0.2))
            )
            .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MovieCard: View {
    let movie: EnhancedMovie
    let style: MovieCardStyle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Poster
                AsyncImage(url: URL(string: movie.fullPosterURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                .frame(width: style.size.width, height: style.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Quality badge
                    Group {
                        if !movie.qualityBadge.isEmpty {
                            Text(movie.qualityBadge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(4)
                                .padding(6)
                        }
                    },
                    alignment: .topTrailing
                )
                
                if style != .small {
                    // Title
                    Text(movie.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(width: style.size.width, alignment: .leading)
                    
                    // Rating and year
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(movie.formattedRating)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(movie.releaseYear)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: style.size.width)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContinueWatchingCard: View {
    let progress: WatchProgress
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottom) {
                    // Poster
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Progress bar
                    VStack(spacing: 4) {
                        ProgressView(value: progress.completionPct)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .scaleEffect(y: 2)
                        
                        HStack {
                            Text("\(Int(max(0, progress.durationSec - progress.positionSec)))s left")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(Int(progress.completionPct * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                }
                
                Text(progress.videoId)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MovieDetailsSheet: View {
    let movie: EnhancedMovie
    @EnvironmentObject private var moviesService: EnhancedMoviesService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero image
                    AsyncImage(url: URL(string: movie.fullBackdropURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and metadata
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text(movie.releaseYear)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(movie.formattedRuntime)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                    
                                    Text(movie.formattedRating)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                            
                            Button(action: {}) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                    Text("My List")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Description
                        Text(movie.overview)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(4)
                        
                        // Cast and crew
                        if !movie.cast.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cast")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(movie.cast.prefix(5).map { $0.name }.joined(separator: ", "))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        if !movie.director.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Director")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(movie.director)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        // Genres
                        if !movie.genres.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Genres")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack {
                                    ForEach(movie.genres.prefix(3), id: \.id) { genre in
                                        Text(genre.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(12)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    NetflixMoviesView()
        .environmentObject(AppState())
}
