import SwiftUI

// MARK: - 🎬 MOVIES (Netflix / Hulu parity)
// Featured hero carousel • Continue Watching • My List • category filter •
// working "View All" • per-card action menu • live search. Backed by Firebase
// via MovieLibraryService + WatchProgressService.
struct MoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var library = MovieLibraryService.shared

    @State private var selectedFilter: MovieFilter = .all
    @State private var searchText: String = ""
    @State private var selectedMovie: FreeMovie? = nil
    @State private var remoteMovies: [FreeMovie] = []
    @State private var isFetching: Bool = false
    @State private var showSearch: Bool = false
    @State private var heroIndex: Int = 0
    @State private var viewAll: ViewAllContext? = nil

    // MARK: - Catalog

    private var allMovies: [FreeMovie] {
        deduped(remoteMovies + FreeMovie.sampleMovies)
    }

    /// Movies matching the active category filter.
    private var filteredMovies: [FreeMovie] {
        switch selectedFilter {
        case .all:
            return allMovies
        case .genre(let g):
            return allMovies.filter { $0.genre.contains(g) }
        }
    }

    private var featuredMovies: [FreeMovie] {
        allMovies
            .filter { $0.runtime >= 60 && $0.imdbRating >= 7.0 }
            .sorted { $0.imdbRating > $1.imdbRating }
            .prefix(5)
            .map { $0 }
    }

    private var continueWatching: [MovieResumeEntry] { library.continueWatching }
    private var myList: [FreeMovie] { library.myListMovies(from: allMovies) }

    private func movies(in genre: FreeMovie.MovieGenre) -> [FreeMovie] {
        allMovies.filter { $0.genre.contains(genre) }
            .sorted { $0.imdbRating > $1.imdbRating }
    }

    private var topRatedMovies: [FreeMovie] {
        allMovies.filter { $0.imdbRating >= 7.5 }.sorted { $0.imdbRating > $1.imdbRating }
    }

    private var classicMovies: [FreeMovie] {
        allMovies.filter { $0.year > 0 && $0.year < 1980 }.sorted { $0.imdbRating > $1.imdbRating }
    }

    private var searchResults: [FreeMovie] {
        guard !searchText.isEmpty else { return [] }
        return allMovies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.director.localizedCaseInsensitiveContains(searchText) ||
            $0.cast.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
            $0.genreString.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 13/255, green: 14/255, blue: 17/255).ignoresSafeArea()

                if showSearch {
                    searchView
                } else {
                    mainContent
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $selectedMovie) { mv in
            MovieDetailView(movie: mv)
                .environmentObject(appState)
        }
        .sheet(item: $viewAll) { ctx in
            ViewAllGrid(title: ctx.title, movies: ctx.movies) { movie in
                viewAll = nil
                // Defer presenting the detail cover until the sheet has dismissed,
                // otherwise SwiftUI can drop the second presentation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedMovie = movie
                }
            }
            .environmentObject(appState)
        }
        .task {
            if remoteMovies.isEmpty { await initialFetch() }
            bindLibrary()
        }
        .onChange(of: appState.currentUser?.id) { _ in bindLibrary() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                categoryBar

                switch selectedFilter {
                case .all:
                    allTabContent
                case .genre(let g):
                    genreGrid(for: g)
                }
            }
            .padding(.bottom, 90)
        }
    }

    private var allTabContent: some View {
        VStack(spacing: 30) {
            if !featuredMovies.isEmpty {
                heroCarousel
            }

            if !continueWatching.isEmpty {
                continueWatchingRow
            }

            if !myList.isEmpty {
                movieRow(title: "My List", movies: myList)
            }

            if !topRatedMovies.isEmpty {
                movieRow(title: "Top Rated", movies: topRatedMovies)
            }

            ForEach(MovieFilter.featuredGenres, id: \.self) { genre in
                let list = movies(in: genre)
                if !list.isEmpty {
                    movieRow(title: genre.rowTitle, movies: list)
                }
            }

            if !classicMovies.isEmpty {
                movieRow(title: "Classic Cinema", movies: classicMovies)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("Movies")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showSearch = true }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Category Bar (functional filter)

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MovieFilter.allFilters, id: \.self) { filter in
                    let isSelected = filter == selectedFilter
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedFilter = filter }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(isSelected ? Color.white : Color.clear))
                            .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Hero Carousel

    private var heroCarousel: some View {
        TabView(selection: $heroIndex) {
            ForEach(Array(featuredMovies.enumerated()), id: \.element.id) { idx, movie in
                FeaturedMovieHeroCard(
                    movie: movie,
                    isInMyList: library.isInMyList(movie.id),
                    onPlay: { open(movie) },
                    onToggleList: { toggleList(movie) },
                    onInfo: { open(movie) }
                )
                .tag(idx)
            }
        }
        .frame(height: 470)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                ForEach(0..<featuredMovies.count, id: \.self) { i in
                    Capsule()
                        .fill(i == heroIndex ? Color.white : Color.white.opacity(0.35))
                        .frame(width: i == heroIndex ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: heroIndex)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Continue Watching Row

    private var continueWatchingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Watching")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(continueWatching) { entry in
                        ContinueWatchingMovieCard(entry: entry) { open(entry.movie) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Generic Movie Row

    private func movieRow(title: String, movies: [FreeMovie]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    viewAll = ViewAllContext(title: title, movies: movies)
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("VIEW ALL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(1.0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(movies.prefix(40)) { movie in
                        HuluMovieCard(
                            movie: movie,
                            isInMyList: library.isInMyList(movie.id),
                            onTap: { open(movie) },
                            onToggleList: { toggleList(movie) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Genre Grid (filter selected)

    private func genreGrid(for genre: FreeMovie.MovieGenre) -> some View {
        let list = filteredMovies
        return Group {
            if list.isEmpty {
                emptyState(text: "No \(genre.rowTitle.lowercased()) yet")
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)],
                    spacing: 18
                ) {
                    ForEach(list) { movie in
                        HuluMovieCard(
                            movie: movie,
                            isInMyList: library.isInMyList(movie.id),
                            onTap: { open(movie) },
                            onToggleList: { toggleList(movie) }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.25))
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Search

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation { showSearch = false; searchText = "" }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PressableScaleStyle())

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)

                    TextField("Search movies, actors, directors...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if searchText.isEmpty {
                searchSuggestions
            } else if searchResults.isEmpty {
                emptyState(text: "No results for \u{201C}\(searchText)\u{201D}")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)],
                        spacing: 16
                    ) {
                        ForEach(searchResults) { movie in
                            HuluMovieCard(
                                movie: movie,
                                isInMyList: library.isInMyList(movie.id),
                                onTap: { open(movie) },
                                onToggleList: { toggleList(movie) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var searchSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse by Genre")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MovieFilter.featuredGenres, id: \.self) { genre in
                        Button {
                            withAnimation { showSearch = false; selectedFilter = .genre(genre) }
                        } label: {
                            Text(genre.rowTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary.opacity(0.35), Color.white.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(PressableScaleStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func open(_ movie: FreeMovie) {
        selectedMovie = movie
        HapticManager.shared.impact(style: .medium)
    }

    private func toggleList(_ movie: FreeMovie) {
        library.toggleMyList(movie, userId: appState.currentUser?.id)
        HapticManager.shared.impact(style: .light)
    }

    private func bindLibrary() {
        if let userId = appState.currentUser?.id {
            library.bind(userId: userId)
            Task { await library.hydrateContinueWatching(userId: userId, catalog: allMovies) }
        } else {
            library.refreshContinueWatching(from: allMovies)
        }
    }

    // MARK: - Data Fetching

    private func initialFetch() async {
        isFetching = true
        defer { isFetching = false }
        let results = await FreeCatalogService.shared.searchAll(query: "", limitPerSource: 100)
        let mapped = results.map { $0.toFreeMovie }
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                let tmdb = mapped.filter { $0.id.hasPrefix("tmdb-") }.sorted(by: { $0.releaseDate > $1.releaseDate })
                let others = mapped.filter { !$0.id.hasPrefix("tmdb-") }
                remoteMovies = deduped(tmdb + others)
            }
            library.refreshContinueWatching(from: allMovies)
        }
    }

    private func deduped(_ movies: [FreeMovie]) -> [FreeMovie] {
        var seen = Set<String>()
        return movies.filter { movie in
            let key = "\(movie.id)|\(movie.title.lowercased())"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return movie.isAvailable && !movie.streamURL.isEmpty
        }
    }
}

// MARK: - Movie Filter

enum MovieFilter: Hashable {
    case all
    case genre(FreeMovie.MovieGenre)

    var title: String {
        switch self {
        case .all: return "All"
        case .genre(let g): return g.shortTitle
        }
    }

    /// Genres surfaced as filter chips and as home rows, in priority order.
    static let featuredGenres: [FreeMovie.MovieGenre] = [
        .action, .scifi, .horror, .comedy, .drama, .thriller, .animation, .family, .romance, .western
    ]

    static var allFilters: [MovieFilter] {
        [.all] + featuredGenres.map { .genre($0) }
    }
}

extension FreeMovie.MovieGenre {
    var shortTitle: String {
        switch self {
        case .scifi: return "Sci-Fi"
        default: return rawValue.capitalized
        }
    }

    var rowTitle: String {
        switch self {
        case .action: return "Action & Adventure"
        case .scifi: return "Sci-Fi & Fantasy"
        case .horror: return "Horror"
        case .comedy: return "Comedy"
        case .drama: return "Drama"
        case .thriller: return "Thrillers"
        case .animation: return "Animation"
        case .family: return "Family"
        case .romance: return "Romance"
        case .western: return "Westerns"
        default: return shortTitle
        }
    }
}

// MARK: - View All context

struct ViewAllContext: Identifiable {
    let id = UUID()
    let title: String
    let movies: [FreeMovie]
}

#Preview("Movies") {
    MoviesView()
        .environmentObject(AppState())
}
