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
        FreeMovie.sampleMovies + remoteMovies
    }
    
    private var filteredMovies: [FreeMovie] {
        var movies = allMovies
        
        // Filter by genre
        if !showAllGenres {
            movies = movies.filter { $0.genre.contains(selectedGenre) }
        }
        
        // Filter by source
        if let source = selectedSource {
            movies = movies.filter { $0.streamingSource == source }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            movies = movies.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.overview.localizedCaseInsensitiveContains(searchText) ||
                $0.director.localizedCaseInsensitiveContains(searchText) ||
                $0.cast.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort movies
        switch sortBy {
        case .popular:
            return movies.sorted { $0.imdbRating > $1.imdbRating }
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
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("🎬 Free Movies")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("\(filteredMovies.count) movies available")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { sortBy = option }) {
                                Label(option.displayName, systemImage: sortBy == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Search movies...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.surface)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Genre Filter
                        Menu {
                            Button(action: { 
                                showAllGenres = true 
                            }) {
                                Label("🎬 All Genres", systemImage: showAllGenres ? "checkmark" : "")
                            }
                            
                            ForEach(FreeMovie.MovieGenre.allCases, id: \.self) { genre in
                                Button(action: { 
                                    selectedGenre = genre
                                    showAllGenres = false
                                }) {
                                    Label(genre.displayName, systemImage: (!showAllGenres && selectedGenre == genre) ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllGenres ? "🎬 All Genres" : selectedGenre.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(AppTheme.Colors.primary.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                
                // Movies Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 20) {
                        ForEach(filteredMovies) { movie in
                            CompactMovieCard(movie: movie) {
                                selectedMovie = movie
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }
                            .onAppear {
                                if movie.id == filteredMovies.last?.id {
                                    fetchNextPageIfNeeded()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if isFetching {
                        ProgressView("Loading more...")
                            .padding()
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .fullScreenCover(item: $selectedMovie) { mv in
            MovieDetailView(movie: mv)
                .onDisappear {
                    selectedMovie = nil
                }
        }
        .task {
            if remoteMovies.isEmpty {
                await initialFetch()
            }
        }
    }

    private func initialFetch() async {
        isFetching = true
        defer { isFetching = false }
        if let page1 = try? await ArchiveOrgService.shared.fetchPopular(page: 1, rows: 60) {
            remoteMovies = page1
            page = 1
        }
    }

    private func fetchNextPageIfNeeded() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            defer { isFetching = false }
            let next = page + 1
            if let results = try? await ArchiveOrgService.shared.fetchPopular(page: next, rows: 60) {
                page = next
                remoteMovies.append(contentsOf: results)
            }
        }
    }
}

// MARK: - Compact Movie Card
struct CompactMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Movie Poster (no FREE badge)
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: movie.posterURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        case .failure(_):
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .aspectRatio(2/3, contentMode: .fill)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                )
                        case .empty:
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .aspectRatio(2/3, contentMode: .fill)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                        .scaleEffect(0.8)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(12)
                    .clipped()
                    
                    // MyChannel badge instead of FREE
                    Text("MC")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.primary)
                        )
                        .padding(6)
                }
                
                // Movie Info (no streaming source)
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        
                        Text("\(movie.imdbRating, specifier: "%.1f")")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(movie.year)")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    // Just show HD quality, no streaming source
                    Text("HD Quality")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.primary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

#Preview {
    FreeMoviesView()
        .environmentObject(AppState())
}