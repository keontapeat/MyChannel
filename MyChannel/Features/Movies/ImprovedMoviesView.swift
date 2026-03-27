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
    @State private var selectedMovie: EnhancedMovie?
    @State private var selectedTab: MoviesTab = .popular
    @State private var showFilters = false
    @State private var searchText = ""
    @State private var searchResults: [EnhancedMovie] = []
    @State private var isSearching = false
    @State private var activeFilters = MovieFilters()

    /// Pre-loaded movies from Home row (avoids double-fetching)
    var initialMovies: [EnhancedMovie] = []
    
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
    
    private var currentMovies: [EnhancedMovie] {
        if !searchText.isEmpty {
            return searchResults
        }
        
        var movies: [EnhancedMovie]
        switch selectedTab {
        case .popular:
            movies = moviesService.popularMovies.isEmpty ? initialMovies : moviesService.popularMovies
        case .trending:
            movies = moviesService.trendingMovies
        case .forYou:
            movies = moviesService.recommendedMovies
        case .watchlist:
            movies = moviesService.watchlist
        case .recent:
            movies = moviesService.continueWatching.compactMap { _ in nil } // placeholder
        }
        
        // Apply active filters
        if let minRating = activeFilters.minimumRating {
            movies = movies.filter { $0.voteAverage >= minRating }
        }
        
        return movies
    }
    
    private var hasActiveFilters: Bool {
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
        .fullScreenCover(item: $selectedMovie) { _ in
            EmptyView()
        }
        .sheet(isPresented: $showFilters) {
            MovieFiltersSheet(filters: $activeFilters)
        }
        .task {
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
        EmptyView()
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
    private func contextMenuItems(for movie: EnhancedMovie) -> some View {
        Button {
            selectedMovie = movie
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Button {
            if moviesService.watchlist.contains(where: { $0.id == movie.id }) {
                moviesService.watchlist.removeAll { $0.id == movie.id }
            } else {
                moviesService.watchlist.append(movie)
            }
        } label: {
            Label(
                moviesService.watchlist.contains(where: { $0.id == movie.id }) ? "Remove from Watchlist" : "Add to Watchlist",
                systemImage: moviesService.watchlist.contains(where: { $0.id == movie.id }) ? "heart.slash" : "heart"
            )
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
        do {
            try await moviesService.loadPopularMovies()
            try await moviesService.loadTrendingMovies()
        } catch {
            print("[ImprovedMoviesView] Load error: \(error)")
        }
    }
    
    private func refreshData() async {
        do {
            try await moviesService.loadPopularMovies()
            try await moviesService.loadTrendingMovies()
        } catch {
            print("[ImprovedMoviesView] Refresh error: \(error)")
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        searchResults = (moviesService.popularMovies + moviesService.trendingMovies)
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
        isSearching = false
    }
}

// MARK: - Enhanced Movie Card

struct EnhancedMovieCard: View {
    let movie: EnhancedMovie
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
        AsyncImage(url: URL(string: movie.fullPosterURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
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
            }
        }
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
                if moviesService.watchlist.contains(where: { $0.id == movie.id }) {
                    moviesService.watchlist.removeAll { $0.id == movie.id }
                } else {
                    moviesService.watchlist.append(movie)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: moviesService.watchlist.contains(where: { $0.id == movie.id }) ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(moviesService.watchlist.contains(where: { $0.id == movie.id }) ? .red : .white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    private var qualityBadges: some View {
        HStack(spacing: 6) {
            if !movie.trailerURL.isEmpty {
                badge(text: "TRAILER", color: AppTheme.Colors.primary)
            }
            badge(text: "HD", color: .green)
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
                
                Text(String(format: "%.1f", movie.voteAverage))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text(movie.originalLanguage.uppercased())
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
    
    @State private var minimumRating: Double = 0
    @State private var minimumYear: Int = 1920
    @State private var sortBy: MovieSortOption = .popular
    
    private let yearRange = Array(stride(from: 2025, through: 1920, by: -5))
    
    var body: some View {
        NavigationStack {
            List {
                
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
                        filters.minimumRating = minimumRating > 0 ? minimumRating : nil
                        filters.minimumYear = minimumYear > 1920 ? minimumYear : nil
                        filters.sortBy = sortBy
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .onAppear {
                minimumRating = filters.minimumRating ?? 0
                minimumYear = filters.minimumYear ?? 1920
                sortBy = filters.sortBy
            }
        }
    }
}

// MARK: - Movie Filters Model
struct MovieFilters {
    var minimumRating: Double?
    var minimumYear: Int?
    var sortBy: MovieSortOption = .popular
}

enum MovieSortOption: String, CaseIterable {
    case popular = "Popular"
    case newest = "Newest"
    case rating = "Rating"
    case title = "Title"
    
    var displayName: String { rawValue }
}

#Preview("Improved Movies View") {
    ImprovedMoviesView()
        .environmentObject(AppState())
}
