//
//  ImprovedMoviesView.swift
//  MyChannel
//
//  Enhanced movies view with better UX and performance
//

import SwiftUI

struct ImprovedMoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var moviesService = EnhancedMoviesService.shared
    @State private var selectedMovie: FreeMovie?
    @State private var selectedTab: MoviesTab = .popular
    @State private var showFilters = false
    @State private var searchText = ""
    @State private var searchResults: [FreeMovie] = []
    @State private var isSearching = false
    @State private var selectedGenre: FreeMovie.MovieGenre? = nil
    @State private var activeFilters = MovieFilters()

    /// Pre-loaded movies from Home row (avoids double-fetching)
    var initialMovies: [FreeMovie] = []
    
    enum MoviesTab: String, CaseIterable {
        case popular = "Popular"
        case trending = "Trending"
        case forYou = "For You"
        case watchlist = "Watchlist"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .popular: return "flame.fill"
            case .trending: return "chart.line.uptrend.xyaxis"
            case .forYou: return "sparkles"
            case .watchlist: return "heart.fill"
            case .recent: return "clock.fill"
            }
        }
    }
    
    private var currentMovies: [FreeMovie] {
        if !searchText.isEmpty {
            return searchResults
        }
        
        var movies: [FreeMovie]
        switch selectedTab {
        case .popular:
            movies = moviesService.popularMovies.isEmpty ? initialMovies : moviesService.popularMovies
        case .trending:
            movies = moviesService.trendingMovies
        case .forYou:
            movies = moviesService.getPersonalizedRecommendations()
        case .watchlist:
            movies = moviesService.watchlist
        case .recent:
            movies = moviesService.recentlyWatched
        }
        
        // Apply genre filter if selected
        if let genre = selectedGenre {
            movies = movies.filter { $0.genre.contains(genre) }
        }
        
        // Apply active filters
        if let source = activeFilters.streamingSource {
            movies = movies.filter { $0.streamingSource == source }
        }
        if let minRating = activeFilters.minimumRating {
            movies = movies.filter { $0.imdbRating >= minRating }
        }
        if let minYear = activeFilters.minimumYear {
            movies = movies.filter { $0.year >= minYear }
        }
        
        return movies
    }
    
    private var hasActiveFilters: Bool {
        selectedGenre != nil || activeFilters.streamingSource != nil ||
        activeFilters.minimumRating != nil || activeFilters.minimumYear != nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                tabNavigation
                genreChips
                
                if moviesService.isLoading && currentMovies.isEmpty {
                    loadingView
                } else if let error = moviesService.error, currentMovies.isEmpty {
                    errorView(error)
                } else {
                    moviesGrid
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
                .onDisappear {
                    moviesService.addToRecentlyWatched(movie)
                }
        }
        .sheet(isPresented: $showFilters) {
            MovieFiltersSheet(filters: $activeFilters)
        }
        .task {
            // Seed from pre-loaded Home data so user sees content instantly
            if moviesService.popularMovies.isEmpty && !initialMovies.isEmpty {
                moviesService.seedPopular(initialMovies)
            }
            await loadInitialData()
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                performSearch(query: newValue)
            } else {
                searchResults = []
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .buttonStyle(PressableScaleStyle())
            
            Spacer()
            
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.system(size: 20))
                    Text("Movies")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                Text("\(currentMovies.count) available")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showFilters = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.primary)
                        if hasActiveFilters {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(PressableScaleStyle())
                
                if hasActiveFilters {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedGenre = nil
                            activeFilters = MovieFilters()
                        }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(PressableScaleStyle())
                }
                
                Button(action: { Task { await refreshData() } }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)
                .font(.system(size: 16))
            
            TextField("Search movies, actors, directors...", text: $searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !searchText.isEmpty {
                Button {
                    withAnimation(AppTheme.AnimationPresets.quick) {
                        searchText = ""
                        searchResults = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Tab Navigation
    
    private var tabNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(MoviesTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(AppTheme.AnimationPresets.easeInOut) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundColor(selectedTab == tab ? .white : AppTheme.Colors.textSecondary)
                        .background(
                            selectedTab == tab ? 
                            AppTheme.Colors.primary : 
                            AppTheme.Colors.surface,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedTab == tab ? 
                                    Color.clear : 
                                    AppTheme.Colors.divider.opacity(0.5), 
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Genre Chips
    
    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedGenre = nil
                    }
                    HapticManager.shared.selection()
                } label: {
                    Text("All")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selectedGenre == nil ? .white : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selectedGenre == nil ? AppTheme.Colors.primary.opacity(0.8) : AppTheme.Colors.surface)
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedGenre == nil ? Color.clear : AppTheme.Colors.divider.opacity(0.4),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                
                ForEach(FreeMovie.MovieGenre.allCases, id: \.self) { genre in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedGenre = selectedGenre == genre ? nil : genre
                        }
                        HapticManager.shared.selection()
                    } label: {
                        Text(genre.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedGenre == genre ? .white : AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(selectedGenre == genre ? AppTheme.Colors.primary.opacity(0.8) : AppTheme.Colors.surface)
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedGenre == genre ? Color.clear : AppTheme.Colors.divider.opacity(0.4),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Movies Grid
    
    private var moviesGrid: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width - 40
            let spacing: CGFloat = 16
            let columns = adaptiveColumns(for: containerWidth, spacing: spacing)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(currentMovies) { movie in
                        EnhancedMovieCard(movie: movie) {
                            selectedMovie = movie
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        .contextMenu {
                            contextMenuItems(for: movie)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if currentMovies.isEmpty && !moviesService.isLoading {
                    emptyStateView
                        .padding(.top, 60)
                }
                
                Color.clear.frame(height: 20)
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading movies...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("Unable to load movies")
                .font(.title3.bold())
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task { await refreshData() }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.primary, in: Capsule())
            .buttonStyle(PressableScaleStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == .watchlist ? "heart" : "film.stack")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateMessage: String {
        if selectedGenre != nil {
            return "No movies in this genre\nTry a different filter"
        }
        switch selectedTab {
        case .popular: return "No popular movies found"
        case .trending: return "No trending movies available"
        case .forYou: return "Watch some movies first\nWe'll learn your taste"
        case .watchlist: return "Your watchlist is empty\nAdd movies to watch later"
        case .recent: return "No recently watched movies\nStart watching to see them here"
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems(for movie: FreeMovie) -> some View {
        Button {
            selectedMovie = movie
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Button {
            if moviesService.isInWatchlist(movie) {
                moviesService.removeFromWatchlist(movie)
            } else {
                moviesService.addToWatchlist(movie)
            }
        } label: {
            Label(
                moviesService.isInWatchlist(movie) ? "Remove from Watchlist" : "Add to Watchlist",
                systemImage: moviesService.isInWatchlist(movie) ? "heart.slash" : "heart"
            )
        }
        
        ShareLink(item: URL(string: movie.streamURL) ?? URL(fileURLWithPath: "/")) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
    
    // MARK: - Helper Methods
    
    private func adaptiveColumns(for width: CGFloat, spacing: CGFloat) -> [GridItem] {
        let minItemWidth: CGFloat = 140
        let maxItemWidth: CGFloat = 200
        
        let availableWidth = width - spacing
        let itemCount = max(2, Int(availableWidth / (minItemWidth + spacing)))
        let itemWidth = min(maxItemWidth, (availableWidth - CGFloat(itemCount - 1) * spacing) / CGFloat(itemCount))
        
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: itemCount)
    }
    
    private func loadInitialData() async {
        await moviesService.loadPopularMovies()
        await moviesService.loadTrendingMovies()
    }
    
    private func refreshData() async {
        await moviesService.loadPopularMovies(forceRefresh: true)
        await moviesService.loadTrendingMovies()
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            let results = await moviesService.searchMovies(query: query)
            await MainActor.run {
                withAnimation(AppTheme.AnimationPresets.easeInOut) {
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Enhanced Movie Card

struct EnhancedMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    @StateObject private var moviesService = EnhancedMoviesService.shared
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    posterImage
                    
                    VStack {
                        HStack {
                            Spacer()
                            watchlistButton
                        }
                        Spacer()
                        qualityBadges
                    }
                    .padding(8)
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
                
                movieInfo
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
    
    private var posterImage: some View {
        MultiSourceAsyncImage(
            urls: movie.posterCandidates,
            content: { image in
                image
                    .resizable()
                    .scaledToFill()
            },
            placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    )
                    .shimmer(active: true)
            }
        )
        .overlay(
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var watchlistButton: some View {
        Button {
            withAnimation(AppTheme.AnimationPresets.bouncy) {
                if moviesService.isInWatchlist(movie) {
                    moviesService.removeFromWatchlist(movie)
                } else {
                    moviesService.addToWatchlist(movie)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: moviesService.isInWatchlist(movie) ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(moviesService.isInWatchlist(movie) ? .red : .white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    private var qualityBadges: some View {
        HStack(spacing: 6) {
            if movie.trailerURL != nil {
                badge(text: "TRAILER", color: AppTheme.Colors.primary)
            }
            badge(text: "HD", color: .green)
            badge(text: "\(movie.year)", color: .blue)
        }
    }
    
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var movieInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(movie.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
                
                Text("\(movie.imdbRating, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text(movie.streamingSource.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.primary.opacity(0.1), in: Capsule())
            }
        }
    }
}

// MARK: - Movie Filters Sheet

struct MovieFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: MovieFilters
    
    @State private var selectedSource: FreeMovie.StreamingSource?
    @State private var minimumRating: Double = 0
    @State private var minimumYear: Int = 1920
    @State private var sortBy: MovieSortOption = .popular
    
    private let yearRange = Array(stride(from: 2025, through: 1920, by: -5))
    
    var body: some View {
        NavigationStack {
            List {
                // Streaming Source
                Section {
                    Button {
                        withAnimation { selectedSource = nil }
                    } label: {
                        HStack {
                            Text("Any Source")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSource == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    
                    ForEach(FreeMovie.StreamingSource.allCases, id: \.self) { source in
                        Button {
                            withAnimation { selectedSource = source }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(source.color)
                                    .frame(width: 10, height: 10)
                                Text(source.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Streaming Source")
                }
                
                // Minimum Rating
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum Rating")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                                Text(minimumRating > 0 ? String(format: "%.1f+", minimumRating) : "Any")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        Slider(value: $minimumRating, in: 0...9, step: 0.5)
                            .tint(AppTheme.Colors.primary)
                    }
                } header: {
                    Text("Rating")
                }
                
                // Minimum Year
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("From Year")
                            Spacer()
                            Text(minimumYear > 1920 ? "\(minimumYear)+" : "Any")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Picker("Year", selection: $minimumYear) {
                            Text("Any").tag(1920)
                            ForEach(yearRange, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                } header: {
                    Text("Release Year")
                }
                
                // Sort
                Section {
                    ForEach(MovieSortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation { sortBy = option }
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortBy == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Sort By")
                }
                
                // Reset
                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            selectedSource = nil
                            minimumRating = 0
                            minimumYear = 1920
                            sortBy = .popular
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset All Filters")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filters.streamingSource = selectedSource
                        filters.minimumRating = minimumRating > 0 ? minimumRating : nil
                        filters.minimumYear = minimumYear > 1920 ? minimumYear : nil
                        filters.sortBy = sortBy
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .onAppear {
                selectedSource = filters.streamingSource
                minimumRating = filters.minimumRating ?? 0
                minimumYear = filters.minimumYear ?? 1920
                sortBy = filters.sortBy
            }
        }
    }
}

#Preview("Improved Movies View") {
    ImprovedMoviesView()
        .environmentObject(AppState())
}
