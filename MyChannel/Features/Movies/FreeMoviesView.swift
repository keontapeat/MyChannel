import SwiftUI

struct FreeMoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGenre: FreeMovie.MovieGenre = .action
    @State private var selectedSource: FreeMovie.StreamingSource? = nil
    @State private var searchText: String = ""
    @State private var sortBy: SortOption = .popular
    @State private var showAllGenres: Bool = true
    @State private var selectedMovie: FreeMovie? = nil
    @State private var remoteMovies: [FreeMovie] = []
    @State private var isFetching: Bool = false
    @State private var page: Int = 1
    
    enum SortOption: String, CaseIterable {
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
    
    private var allMovies: [FreeMovie] {
        // Prefer remote results; fall back to samples only if empty
        if !remoteMovies.isEmpty { return remoteMovies }
        return FreeMovie.sampleMovies
    }
    
    private var filteredMovies: [FreeMovie] {
        var movies = allMovies
        
        if !showAllGenres {
            movies = movies.filter { $0.genre.contains(selectedGenre) }
        }
        
        if let source = selectedSource {
            movies = movies.filter { $0.streamingSource == source }
        }
        
        if !searchText.isEmpty {
            movies = movies.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.overview.localizedCaseInsensitiveContains(searchText) ||
                $0.director.localizedCaseInsensitiveContains(searchText) ||
                $0.cast.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
        
        switch sortBy {
        case .popular:
            // Prefer newer with decent rating
            return movies.sorted { (lhs, rhs) in
                if lhs.year != rhs.year { return lhs.year > rhs.year }
                return lhs.imdbRating > rhs.imdbRating
            }
        case .newest:
            return movies.sorted { $0.year > $1.year }
        case .rating:
            return movies.sorted { $0.imdbRating > $1.imdbRating }
        case .alphabetical:
            return movies.sorted { $0.title < $1.title }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                filters
                grid
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $selectedMovie) { mv in
            FreeMovieDetailWrapper(movie: mv)
                .onDisappear { selectedMovie = nil }
        }
        .task {
            if remoteMovies.isEmpty {
                await initialFetch()
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .buttonStyle(PressableScaleStyle())
            
            Spacer()
            
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Free Movies")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                Text("\(filteredMovies.count) movies available")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(AppTheme.AnimationPresets.easeInOut) { sortBy = option }
                    } label: {
                        Label(option.displayName, systemImage: sortBy == option ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)
            TextField("Search movies, directors, cast...", text: $searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.system(size: 16))
            if !searchText.isEmpty {
                Button {
                    withAnimation(AppTheme.AnimationPresets.quick) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
    
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Menu {
                    Button {
                        withAnimation(AppTheme.AnimationPresets.easeInOut) { showAllGenres = true }
                    } label: {
                        Label("🎬 All Genres", systemImage: showAllGenres ? "checkmark" : "")
                    }
                    ForEach(FreeMovie.MovieGenre.allCases, id: \.self) { genre in
                        Button {
                            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                                selectedGenre = genre
                                showAllGenres = false
                            }
                        } label: {
                            Label(genre.displayName, systemImage: (!showAllGenres && selectedGenre == genre) ? "checkmark" : "")
                        }
                    }
                } label: {
                    chipLabel(text: showAllGenres ? "🎬 All Genres" : selectedGenre.displayName)
                }
                .buttonStyle(PressableScaleStyle())
                
                Menu {
                    Button {
                        withAnimation(AppTheme.AnimationPresets.easeInOut) { selectedSource = nil }
                    } label: {
                        Label("All Sources", systemImage: selectedSource == nil ? "checkmark" : "")
                    }
                    ForEach(FreeMovie.StreamingSource.allCases, id: \.self) { src in
                        Button {
                            withAnimation(AppTheme.AnimationPresets.easeInOut) { selectedSource = src }
                        } label: {
                            Label(src.displayName, systemImage: selectedSource == src ? "checkmark" : "")
                        }
                    }
                } label: {
                    chipLabel(text: selectedSource?.displayName ?? "All Sources")
                }
                .buttonStyle(PressableScaleStyle())
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
    
    private func chipLabel(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundColor(AppTheme.Colors.primary)
        .background(AppTheme.Colors.primary.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.Colors.primary.opacity(0.25), lineWidth: 1))
    }
    
    private var grid: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width - 40
            let spacing: CGFloat = 16
            let config = columnsFor(width: containerWidth, spacing: spacing)
            let itemWidth = config.itemWidth
            let posterHeight = itemWidth * 1.5
            
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(chunked(filteredMovies, size: config.count), id: \.first?.id) { rowMovies in
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(rowMovies) { movie in
                                Button {
                                    selectedMovie = movie
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    MovieThumbnailView(movie: movie, itemWidth: itemWidth, posterHeight: posterHeight)
                                }
                                .buttonStyle(PressableScaleStyle(scale: 0.97))
                                .contextMenu {
                                    Button("Open Details", systemImage: "info.circle") { selectedMovie = movie }
                                    ShareLink(item: URL(string: movie.streamURL) ?? URL(fileURLWithPath: "/"), subject: Text(movie.title)) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                                .onAppear {
                                    if movie.id == filteredMovies.last?.id {
                                        fetchNextPageIfNeeded()
                                    }
                                }
                            }
                            
                            // Fill remaining space if last row has fewer items
                            if rowMovies.count < config.count {
                                ForEach(0..<(config.count - rowMovies.count), id: \.self) { _ in
                                    Spacer()
                                        .frame(width: itemWidth)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                
                if isFetching {
                    ProgressView("Loading more…")
                        .padding(.vertical, 20)
                }
            }
            .refreshable { await refresh() }
        }
    }
    
    private func columnsFor(width: CGFloat, spacing: CGFloat) -> (count: Int, itemWidth: CGFloat) {
        let count: Int
        switch width {
        case 0..<360: count = 2
        case 360..<520: count = 3
        case 520..<740: count = 4
        case 740..<980: count = 5
        default: count = 6
        }
        let totalSpacing = CGFloat(max(0, count - 1)) * spacing
        let itemWidth = (width - totalSpacing) / CGFloat(count)
        return (count, floor(itemWidth))
    }
    
    private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
    
    private func initialFetch() async {
        isFetching = true
        defer { isFetching = false }
        let query = searchText.isEmpty ? "" : searchText
        let results = await FreeCatalogService.shared.searchAll(query: query, limitPerSource: 20)
        await MainActor.run {
            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                // Prioritize modern (TMDB) results first
                let tmdb = results.filter { $0.id.hasPrefix("tmdb-") }.sorted { $0.year > $1.year }
                let others = results.filter { !$0.id.hasPrefix("tmdb-") }
                remoteMovies = tmdb + others
                page = 1
            }
        }
    }
    
    private func refresh() async {
        isFetching = true
        defer { isFetching = false }
        let query = searchText.isEmpty ? "" : searchText
        let results = await FreeCatalogService.shared.searchAll(query: query, limitPerSource: 20)
        await MainActor.run {
            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                let tmdb = results.filter { $0.id.hasPrefix("tmdb-") }.sorted { $0.year > $1.year }
                let others = results.filter { !$0.id.hasPrefix("tmdb-") }
                remoteMovies = tmdb + others
                page = 1
            }
        }
    }
    
    private func fetchNextPageIfNeeded() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            defer { isFetching = false }
            let results = await FreeCatalogService.shared.searchAll(query: searchText.isEmpty ? "" : searchText, limitPerSource: 12)
            await MainActor.run {
                withAnimation(AppTheme.AnimationPresets.gentle) {
                    page += 1
                    // Deduplicate on append
                    let existing = Set(remoteMovies.map { $0.streamURL })
                    let newOnes = results.filter { !existing.contains($0.streamURL) }
                    remoteMovies.append(contentsOf: newOnes)
                    // Keep TMDB-first ordering after append
                    let tmdb = remoteMovies.filter { $0.id.hasPrefix("tmdb-") }.sorted { $0.year > $1.year }
                    let others = remoteMovies.filter { !$0.id.hasPrefix("tmdb-") }
                    remoteMovies = tmdb + others
                }
            }
        }
    }
}

struct FreeMovieDetailWrapper: View {
    let movie: FreeMovie
    var body: some View {
        MovieDetailView(movie: movie)
    }
}

#Preview("FreeMovie Detail Wrapper") {
    FreeMovieDetailWrapper(movie: FreeMovie.sampleMovies.first!)
}

#Preview("Free Movies Grid") {
    FreeMoviesView()
        .environmentObject(AppState())
}