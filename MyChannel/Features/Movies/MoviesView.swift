import SwiftUI

// MARK: - 🔥 HULU STYLE MOVIES VIEW 🔥
struct MoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HuluTab = .movies
    @State private var searchText: String = ""
    @State private var selectedMovie: FreeMovie? = nil
    @State private var remoteMovies: [FreeMovie] = []
    @State private var isFetching: Bool = false
    @State private var showSearch: Bool = false
    @State private var showMovieDetail: Bool = false
    
    enum HuluTab: String, CaseIterable {
        case all = "ALL"
        case tv = "TV"
        case movies = "MOVIES"
        case news = "NEWS"
        case hubs = "HUBS"
    }
    
    private var allMovies: [FreeMovie] {
        deduped(remoteMovies + FreeMovie.sampleMovies)
    }
    
    // Featured movies (first row)
    private var featuredMovies: [FreeMovie] {
        allMovies
            .filter { $0.runtime >= 60 && $0.imdbRating >= 7.0 }
            .sorted { $0.imdbRating > $1.imdbRating }
            .prefix(50)
            .map { $0 }
    }
    
    // Horror Movies
    private var horrorMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.horror) || $0.genre.contains(.thriller) }.prefix(50).map { $0 }
    }
    
    // Blockbuster Movies
    private var blockbusterMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.action) || $0.genre.contains(.scifi) }.sorted { $0.imdbRating > $1.imdbRating }.prefix(50).map { $0 }
    }
    
    // Comedy Movies
    private var comedyMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.comedy) }.prefix(50).map { $0 }
    }

    // Drama Movies
    private var dramaMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.drama) }.prefix(50).map { $0 }
    }

    // Sci-Fi & Fantasy
    private var scifiMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.scifi) || $0.genre.contains(.fantasy) }.prefix(50).map { $0 }
    }

    // Top Rated
    private var topRatedMovies: [FreeMovie] {
        allMovies.filter { $0.imdbRating >= 7.5 }.sorted { $0.imdbRating > $1.imdbRating }.prefix(50).map { $0 }
    }

    // Animation
    private var animationMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.animation) }.prefix(50).map { $0 }
    }

    // Classics (pre-1980)
    private var classicMovies: [FreeMovie] {
        allMovies.filter { $0.year < 1980 }.sorted { $0.imdbRating > $1.imdbRating }.prefix(50).map { $0 }
    }

    // Full Movies (60+ min)
    private var fullMovies: [FreeMovie] {
        allMovies.filter { $0.runtime >= 60 }.sorted { $0.year > $1.year }.prefix(100).map { $0 }
    }
    
    private var searchResults: [FreeMovie] {
        guard !searchText.isEmpty else { return [] }
        return allMovies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.director.localizedCaseInsensitiveContains(searchText) ||
            $0.cast.joined().localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Hulu Dark background
                Color(red: 20/255, green: 22/255, blue: 25/255).ignoresSafeArea()

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
        }
        .task {
            if remoteMovies.isEmpty {
                await initialFetch()
            }
        }
    }
    
    // MARK: - Main Content (Hulu Style)
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Top Header with dismiss + Tabs
                VStack(spacing: 0) {
                    // Top bar: back/close button + title + search
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
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showSearch = true
                            }
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

                    // Hulu-style Tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(HuluTab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.8))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(selectedTab == tab ? Color.white : Color.clear))
                                        .overlay(Capsule().stroke(Color.white.opacity(selectedTab == tab ? 0 : 0.3), lineWidth: 1))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                }

                // Content Rows (Hulu Style)
                VStack(spacing: 28) {
                    if !featuredMovies.isEmpty {
                        movieRow(title: "Featured Movies", movies: featuredMovies)
                    }
                    if !topRatedMovies.isEmpty {
                        movieRow(title: "Top Rated", movies: topRatedMovies)
                    }
                    if !horrorMovies.isEmpty {
                        movieRow(title: "Horror Movies", movies: horrorMovies)
                    }
                    if !blockbusterMovies.isEmpty {
                        movieRow(title: "Blockbuster Movies", movies: blockbusterMovies)
                    }
                    if !comedyMovies.isEmpty {
                        movieRow(title: "Comedy Movies", movies: comedyMovies)
                    }
                    if !scifiMovies.isEmpty {
                        movieRow(title: "Sci-Fi & Fantasy", movies: scifiMovies)
                    }
                    if !dramaMovies.isEmpty {
                        movieRow(title: "Drama", movies: dramaMovies)
                    }
                    if !animationMovies.isEmpty {
                        movieRow(title: "Animation", movies: animationMovies)
                    }
                    if !fullMovies.isEmpty {
                        movieRow(title: "Full Movies", movies: fullMovies)
                    }
                    if !classicMovies.isEmpty {
                        movieRow(title: "Classic Cinema", movies: classicMovies)
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }
    
    // MARK: - Movie Row (Hulu Style)
    private func movieRow(title: String, movies: [FreeMovie]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(alignment: .bottom) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("VIEW ALL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.0)
            }
            .padding(.horizontal, 16)

            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(movies) { movie in
                        HuluMovieCard(movie: movie) {
                            selectedMovie = movie
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search View (Kept simple for now)
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack(spacing: 12) {
                Button {
                    withAnimation {
                        showSearch = false
                        searchText = ""
                    }
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
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Search Results
            if searchText.isEmpty {
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)],
                        spacing: 16
                    ) {
                        ForEach(searchResults) { movie in
                            HuluMovieCard(movie: movie) {
                                selectedMovie = movie
                            }
                        }
                    }
                    .padding(16)
                }
            }
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

// MARK: - Hulu-Style Movie Card
struct HuluMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void

    private let cardWidth: CGFloat = 130
    private let posterHeight: CGFloat = 195

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Poster with ... button overlay
                ZStack(alignment: .topTrailing) {
                    MultiSourceAsyncImage(
                        urls: movie.posterCandidates,
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: posterHeight)
                                .clipped()
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Color(red: 40/255, green: 42/255, blue: 45/255))
                                .frame(width: cardWidth, height: posterHeight)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                )
                                .shimmer(active: true)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Three dots (Hulu style)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .padding(7)
                }
                .frame(width: cardWidth, height: posterHeight)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                // Title
                Text(movie.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: cardWidth, alignment: .leading)

                // Rating row
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", movie.imdbRating))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.95))
        .contextMenu {
            Button { action() } label: {
                Label("Watch Now", systemImage: "play.fill")
            }
            Button {} label: {
                Label("Add to My Stuff", systemImage: "plus")
            }
            ShareLink(item: URL(string: movie.streamURL) ?? URL(fileURLWithPath: "/")) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

#Preview("Hulu Movies Grid") {
    MoviesView()
        .environmentObject(AppState())
}