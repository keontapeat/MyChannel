import SwiftUI

// MARK: - 🔥 NETFLIX + YOUTUBE STYLE MOVIES VIEW 🔥
struct FreeMoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: MovieTab = .popular
    @State private var selectedGenre: FreeMovie.MovieGenre = .action
    @State private var searchText: String = ""
    @State private var selectedMovie: FreeMovie? = nil
    @State private var remoteMovies: [FreeMovie] = []
    @State private var isFetching: Bool = false
    @State private var showSearch: Bool = false
    @State private var featuredIndex: Int = 0
    @State private var animateHero: Bool = false
    
    // Auto-rotate featured movie
    let heroTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    enum MovieTab: String, CaseIterable {
        case popular = "Popular"
        case trending = "Trending"
        case topRated = "Top Rated"
        case fullMovies = "Full Movies"
        
        var icon: String {
            switch self {
            case .popular: return "flame.fill"
            case .trending: return "chart.line.uptrend.xyaxis"
            case .topRated: return "star.fill"
            case .fullMovies: return "play.rectangle.fill"
            }
        }
    }
    
    private var allMovies: [FreeMovie] {
        if !remoteMovies.isEmpty { return remoteMovies }
        return FreeMovie.sampleMovies
    }
    
    // Featured movies for hero banner (top rated, full length)
    private var featuredMovies: [FreeMovie] {
        allMovies
            .filter { $0.runtime >= 60 && $0.imdbRating >= 7.0 }
            .sorted { $0.imdbRating > $1.imdbRating }
            .prefix(5)
            .map { $0 }
    }
    
    // Movies by category
    private var trendingNow: [FreeMovie] {
        allMovies.sorted { ($0.imdbRating * Double($0.year)) > ($1.imdbRating * Double($1.year)) }.prefix(15).map { $0 }
    }
    
    private var topRated: [FreeMovie] {
        allMovies.filter { $0.imdbRating >= 7.0 }.sorted { $0.imdbRating > $1.imdbRating }.prefix(15).map { $0 }
    }
    
    private var fullMovies: [FreeMovie] {
        allMovies.filter { $0.runtime >= 60 }.sorted { $0.year > $1.year }.prefix(15).map { $0 }
    }
    
    private var actionMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.action) || $0.genre.contains(.thriller) }.prefix(15).map { $0 }
    }
    
    private var comedyMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.comedy) }.prefix(15).map { $0 }
    }
    
    private var horrorMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.horror) }.prefix(15).map { $0 }
    }
    
    private var scifiMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.scifi) || $0.genre.contains(.fantasy) }.prefix(15).map { $0 }
    }
    
    private var classicMovies: [FreeMovie] {
        allMovies.filter { $0.year < 1970 }.sorted { $0.imdbRating > $1.imdbRating }.prefix(15).map { $0 }
    }
    
    private var dramaMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.drama) }.prefix(15).map { $0 }
    }
    
    private var animationMovies: [FreeMovie] {
        allMovies.filter { $0.genre.contains(.animation) }.prefix(15).map { $0 }
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
                // Dark background like Netflix
                Color.black.ignoresSafeArea()
                
                if showSearch {
                    searchView
                } else {
                    mainContent
                }
            }
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateHero = true
            }
        }
        .onReceive(heroTimer) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                featuredIndex = (featuredIndex + 1) % max(1, featuredMovies.count)
            }
        }
    }
    
    // MARK: - Main Content (Netflix + YouTube Style)
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Hero Banner (Netflix Style)
                if !featuredMovies.isEmpty {
                    heroBanner
                }
                
                // Tab Navigation (YouTube Style)
                tabNavigation
                    .padding(.top, 16)
                
                // Content Rows (Netflix Style)
                VStack(spacing: 24) {
                    // 🔥 Trending Now
                    if !trendingNow.isEmpty {
                        movieRow(title: "🔥 Trending Now", movies: trendingNow, style: .large)
                    }
                    
                    // ⭐ Top Rated
                    if !topRated.isEmpty {
                        movieRow(title: "⭐ Top Rated", movies: topRated, style: .standard)
                    }
                    
                    // 🎬 Full Movies
                    if !fullMovies.isEmpty {
                        movieRow(title: "🎬 Full Movies", movies: fullMovies, style: .large)
                    }
                    
                    // 💥 Action & Thriller
                    if !actionMovies.isEmpty {
                        movieRow(title: "💥 Action & Thriller", movies: actionMovies, style: .standard)
                    }
                    
                    // 😂 Comedy
                    if !comedyMovies.isEmpty {
                        movieRow(title: "😂 Comedy", movies: comedyMovies, style: .standard)
                    }
                    
                    // 👻 Horror
                    if !horrorMovies.isEmpty {
                        movieRow(title: "👻 Horror", movies: horrorMovies, style: .standard)
                    }
                    
                    // 🚀 Sci-Fi & Fantasy
                    if !scifiMovies.isEmpty {
                        movieRow(title: "🚀 Sci-Fi & Fantasy", movies: scifiMovies, style: .standard)
                    }
                    
                    // 🎭 Drama
                    if !dramaMovies.isEmpty {
                        movieRow(title: "🎭 Drama", movies: dramaMovies, style: .standard)
                    }
                    
                    // 🎨 Animation
                    if !animationMovies.isEmpty {
                        movieRow(title: "🎨 Animation", movies: animationMovies, style: .standard)
                    }
                    
                    // 📽️ Classic Cinema
                    if !classicMovies.isEmpty {
                        movieRow(title: "📽️ Classic Cinema", movies: classicMovies, style: .standard)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .overlay(alignment: .top) {
            // Floating Header
            floatingHeader
        }
    }
    
    // MARK: - Floating Header (Netflix Style)
    private var floatingHeader: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial.opacity(0.8), in: Circle())
            }
            .buttonStyle(PressableScaleStyle())
            
            Spacer()
            
            // Logo/Title
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("Movies")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Search Button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showSearch = true
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial.opacity(0.8), in: Circle())
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [.black, .black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Hero Banner (Netflix Style)
    private var heroBanner: some View {
        let featured = featuredMovies[safe: featuredIndex] ?? featuredMovies.first!
        
        return ZStack(alignment: .bottom) {
            // Background Image
            GeometryReader { geo in
                MultiSourceAsyncImage(
                    urls: featured.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 500)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geo.size.width, height: 500)
                            .shimmer(active: true)
                    }
                )
            }
            .frame(height: 500)
            
            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.3), .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(spacing: 16) {
                // Badges
                HStack(spacing: 8) {
                    if featured.runtime >= 60 {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 10))
                            Text("FULL MOVIE")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.Colors.primary, in: Capsule())
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", featured.imdbRating))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Text("\(featured.year)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                
                // Title
                Text(featured.title)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                
                // Genre & Runtime
                HStack(spacing: 8) {
                    Text(featured.genre.prefix(2).map { $0.rawValue.capitalized }.joined(separator: " • "))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(featured.formattedRuntime)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Buttons
                HStack(spacing: 12) {
                    // Play Button
                    Button {
                        selectedMovie = featured
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Play")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(width: 140, height: 44)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PressableScaleStyle())
                    
                    // Info Button
                    Button {
                        selectedMovie = featured
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16, weight: .semibold))
                            Text("More Info")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 140, height: 44)
                        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PressableScaleStyle())
                }
                
                // Page Indicators
                HStack(spacing: 6) {
                    ForEach(0..<featuredMovies.count, id: \.self) { index in
                        Circle()
                            .fill(index == featuredIndex ? AppTheme.Colors.primary : .white.opacity(0.4))
                            .frame(width: index == featuredIndex ? 8 : 6, height: index == featuredIndex ? 8 : 6)
                            .animation(.spring(response: 0.3), value: featuredIndex)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .opacity(animateHero ? 1 : 0)
            .offset(y: animateHero ? 0 : 30)
        }
        .frame(height: 500)
    }
    
    // MARK: - Tab Navigation (YouTube Style)
    private var tabNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MovieTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTab = tab
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundColor(selectedTab == tab ? .black : .white)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? .white : .white.opacity(0.15))
                        )
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Movie Row (Netflix Style)
    enum RowStyle {
        case standard
        case large
    }
    
    private func movieRow(title: String, movies: [FreeMovie], style: RowStyle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // See all action
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
                .buttonStyle(PressableScaleStyle())
            }
            .padding(.horizontal, 16)
            
            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: style == .large ? 12 : 10) {
                    ForEach(movies) { movie in
                        NetflixMovieCard(
                            movie: movie,
                            style: style
                        ) {
                            selectedMovie = movie
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search View
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                // Popular Searches
                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular Searches")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                    
                    ForEach(["Action", "Comedy", "Horror", "Sci-Fi", "Drama"], id: \.self) { term in
                        Button {
                            searchText = term
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text(term)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.top, 20)
            } else {
                // Results Grid
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)],
                        spacing: 16
                    ) {
                        ForEach(searchResults) { movie in
                            NetflixMovieCard(movie: movie, style: .standard) {
                                selectedMovie = movie
                            }
                        }
                    }
                    .padding(16)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Data Fetching
    private func initialFetch() async {
        isFetching = true
        defer { isFetching = false }
        let results = await FreeCatalogService.shared.searchAll(query: "", limitPerSource: 30)
        let mapped = results.map { $0.toFreeMovie }
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                let tmdb = mapped.filter { $0.id.hasPrefix("tmdb-") }.sorted(by: { $0.releaseDate > $1.releaseDate })
                let others = mapped.filter { !$0.id.hasPrefix("tmdb-") }
                remoteMovies = tmdb + others
            }
        }
    }
}

// MARK: - Netflix-Style Movie Card
struct NetflixMovieCard: View {
    let movie: FreeMovie
    let style: FreeMoviesView.RowStyle
    let action: () -> Void
    
    private var cardWidth: CGFloat {
        style == .large ? 140 : 110
    }
    
    private var cardHeight: CGFloat {
        style == .large ? 200 : 160
    }
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Poster
                MultiSourceAsyncImage(
                    urls: movie.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: cardWidth, height: cardHeight)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            )
                            .shimmer(active: true)
                    }
                )
                
                // Gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Info Overlay
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    // Badges
                    HStack(spacing: 4) {
                        if movie.runtime >= 60 {
                            Text("FULL")
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 3))
                        }
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", movie.imdbRating))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Title
                    Text(movie.title)
                        .font(.system(size: style == .large ? 12 : 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(8)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableScaleStyle(scale: 0.95))
        .contextMenu {
            Button { action() } label: {
                Label("Watch Now", systemImage: "play.fill")
            }
            Button {} label: {
                Label("Add to My List", systemImage: "plus")
            }
            ShareLink(item: URL(string: movie.streamURL) ?? URL(fileURLWithPath: "/")) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

// Safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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