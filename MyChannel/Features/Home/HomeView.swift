import SwiftUI
import Combine

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var selectedFilter: ContentFilter = .all
    @State private var searchText: String = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 1.0
    @State private var isRefreshing: Bool = false
    @State private var selectedVideo: Video? = nil
    @State private var showingVideoPlayer: Bool = false
    @State private var selectedMovie: FreeMovie? = nil
    @State private var showingSearchView: Bool = false
    @State private var featuredContent: [Video] = []
    @State private var heroVideoIndex: Int = 0
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium Background
                premiumBackground
                
                // Main Content
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            // Hero Section
                            netflixStyleHeroSection
                            
                            // Premium Content Sections
                            premiumContentSections
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onScrollOffsetChange { offset in
                        withAnimation(.easeOut(duration: 0.1)) {
                            scrollOffset = offset
                            headerOpacity = min(1.0, max(0.0, 1.0 - (offset / 200.0)))
                        }
                    }
                }
                
                // Floating Navigation Header
                floatingNavigationHeader
            }
        }
        .onAppear(perform: setupContent)
        .refreshable { await refreshContent() }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
                    .onDisappear { selectedVideo = nil }
            }
        }
        .fullScreenCover(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
                .onDisappear { selectedMovie = nil }
        }
        .fullScreenCover(isPresented: $showingSearchView) {
            SearchView()
                .onDisappear { showingSearchView = false }
        }
    }
    
    // MARK: - Premium Background
    private var premiumBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.black.opacity(0.95),
                Color.black.opacity(0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Netflix Style Hero Section
    private var netflixStyleHeroSection: some View {
        ZStack(alignment: .bottom) {
            // Hero Background Video/Image
            heroBackgroundContent
            
            // Hero Gradient Overlay
            heroGradientOverlay
            
            // Hero Content Info
            heroContentInfo
        }
        .frame(height: 600)
        .clipped()
    }
    
    // MARK: - Hero Background Content
    private var heroBackgroundContent: some View {
        GeometryReader { geometry in
            if !featuredContent.isEmpty {
                let currentVideo = featuredContent[heroVideoIndex % featuredContent.count]
                
                AsyncImage(url: URL(string: currentVideo.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: 600 + max(0, scrollOffset)
                        )
                        .offset(y: -scrollOffset * 0.3)
                        .blur(radius: max(0, scrollOffset * 0.005))
                } placeholder: {
                    heroPlaceholderContent(for: currentVideo)
                }
            } else {
                defaultHeroPlaceholder
            }
        }
        .onReceive(Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                heroVideoIndex = (heroVideoIndex + 1) % max(1, featuredContent.count)
            }
        }
    }
    
    // MARK: - Hero Placeholder Content
    private func heroPlaceholderContent(for video: Video) -> some View {
        LinearGradient(
            colors: [
                video.category.color.opacity(0.4),
                Color.black.opacity(0.8),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 24) {
                Image(systemName: video.category.iconName)
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(video.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }
        )
    }
    
    // MARK: - Default Hero Placeholder
    private var defaultHeroPlaceholder: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.primary.opacity(0.3),
                Color.black.opacity(0.8),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 24) {
                Image("MyChannel")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .opacity(0.6)
                
                Text("Welcome to MyChannel")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        )
    }
    
    // MARK: - Hero Gradient Overlay
    private var heroGradientOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.2),
                Color.black.opacity(0.6),
                Color.black.opacity(0.9),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
    
    // MARK: - Hero Content Info
    private var heroContentInfo: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if !featuredContent.isEmpty {
                let currentVideo = featuredContent[heroVideoIndex % featuredContent.count]
                
                VStack(spacing: 16) {
                    // Featured Badge
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                        
                        Text("FEATURED")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                    }
                    .opacity(0.9)
                    
                    // Title
                    Text(currentVideo.title)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    
                    // Metadata
                    HStack(spacing: 12) {
                        heroMetadataChip(currentVideo.category.displayName, icon: "play.rectangle.fill")
                        heroMetadataChip(currentVideo.formattedDuration, icon: "clock.fill")
                        heroMetadataChip("\(currentVideo.formattedViewCount) views", icon: "eye.fill")
                    }
                    .opacity(0.9)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        // Play Button
                        Button(action: { playVideo(currentVideo) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Play")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(width: 140, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                            )
                            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PremiumButtonStyle())
                        
                        // My List Button
                        Button(action: { toggleWatchLater(currentVideo) }) {
                            HStack(spacing: 12) {
                                Image(systemName: appState.isVideoInWatchLater(currentVideo.id) ? "checkmark.circle.fill" : "plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text("My List")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 120, height: 56)
                            .background(
                                .ultraThinMaterial.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 80)
            }
        }
    }
    
    // MARK: - Hero Metadata Chip
    private func heroMetadataChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial.opacity(0.6),
            in: Capsule()
        )
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Floating Navigation Header
    private var floatingNavigationHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Logo
                Button(action: {}) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Navigation Actions
                HStack(spacing: 20) {
                    Button(action: { showingSearchView = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: NotificationsView()) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                            
                            // Notification Badge
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: ProfileView()) {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 10)
            .background(
                .ultraThinMaterial.opacity(headerOpacity < 0.5 ? 1 - headerOpacity : 0)
            )
            
            Spacer()
        }
    }
    
    // MARK: - Premium Content Sections
    private var premiumContentSections: some View {
        VStack(spacing: 40) {
            // Continue Watching
            if !appState.watchHistory.isEmpty {
                continueWatchingSection
            }
            
            // Trending Now
            trendingSection
            
            // Movies Section
            moviesSection
            
            // Categories Section
            categoriesSection
            
            // Because You Watched
            recommendedSection
            
            // Live TV
            liveTVSection
            
            // Bottom Spacing
            Color.clear.frame(height: 100)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Continue Watching Section
    private var continueWatchingSection: some View {
        PremiumContentSection(
            title: "Continue Watching",
            subtitle: "Pick up where you left off",
            icon: "play.circle.fill"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Video.sampleVideos.prefix(5)) { video in
                        ContinueWatchingCard(video: video) {
                            playVideo(video)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        PremiumContentSection(
            title: "Trending Now",
            subtitle: "What everyone's watching",
            icon: "flame.fill",
            seeAllAction: { /* Navigate to trending */ }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Video.sampleVideos.filter { $0.viewCount > 100000 }.prefix(8)) { video in
                        PremiumVideoCard(video: video) {
                            playVideo(video)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Movies Section
    private var moviesSection: some View {
        PremiumContentSection(
            title: "Free Movies",
            subtitle: "Classic films, completely free",
            icon: "film.fill",
            seeAllAction: { /* Navigate to movies */ }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(FreeMovie.sampleMovies.prefix(6)) { movie in
                        HomeMovieCard(movie: movie) {
                            selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        PremiumContentSection(
            title: "Browse by Category",
            subtitle: "Discover content you love",
            icon: "square.grid.2x2.fill"
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(ContentFilter.allCases.dropFirst().prefix(6)), id: \.self) { category in
                    CategoryCard(category: category) {
                        selectedFilter = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Recommended Section
    private var recommendedSection: some View {
        PremiumContentSection(
            title: "Because You Watched",
            subtitle: "More content tailored for you",
            icon: "heart.fill"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Video.sampleVideos.shuffled().prefix(6)) { video in
                        PremiumVideoCard(video: video) {
                            playVideo(video)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Live TV Section
    private var liveTVSection: some View {
        PremiumContentSection(
            title: "Live TV",
            subtitle: "Watch live channels 24/7",
            icon: "tv.fill",
            seeAllAction: { /* Navigate to live TV */ }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5) { index in
                        LiveTVCard(
                            channelName: "Channel \(index + 1)",
                            programName: "Live Program",
                            isLive: true
                        ) {
                            // Handle live TV tap
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupContent() {
        featuredContent = Video.sampleVideos.filter { $0.viewCount > 500000 }.shuffled()
        if featuredContent.isEmpty {
            featuredContent = Array(Video.sampleVideos.prefix(3))
        }
    }
    
    private func refreshContent() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setupContent()
        isRefreshing = false
    }
    
    // MARK: - Action Methods
    private func playVideo(_ video: Video) {
        selectedVideo = video
        showingVideoPlayer = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func toggleWatchLater(_ video: Video) {
        appState.toggleWatchLater(for: video.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Premium Content Section
struct PremiumContentSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let seeAllAction: (() -> Void)?
    @ViewBuilder let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        seeAllAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.seeAllAction = seeAllAction
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if let seeAllAction = seeAllAction {
                    Button("See all", action: seeAllAction)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 20)
            
            // Section Content
            content
        }
    }
}

// MARK: - Premium Video Card
struct PremiumVideoCard: View {
    let video: Video
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        video.category.color.opacity(0.3),
                                        video.category.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: video.category.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(video.category.color)
                            )
                    }
                    .frame(width: 200, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Duration Badge
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.8))
                        )
                        .padding(8)
                }
                
                // Video Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    Text("\(video.formattedViewCount) views")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)
                .frame(width: 200, alignment: .leading)
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

// MARK: - Home Movie Card (Renamed to avoid conflicts)
struct HomeMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Poster
                MultiSourceAsyncImage(
                    urls: movie.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.3))
                            .frame(width: 140, height: 210)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "film.stack")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Text(movie.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 8)
                                }
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Movie Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(
                                    index < Int(movie.imdbRating / 2) ? .yellow : .white.opacity(0.3)
                                )
                        }
                        
                        Text("\(movie.imdbRating, specifier: "%.1f")")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.top, 8)
                .frame(width: 140, alignment: .leading)
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

// MARK: - Continue Watching Card
struct ContinueWatchingCard: View {
    let video: Video
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var progress: Double = Double.random(in: 0.1...0.8)
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(video.category.color.opacity(0.3))
                            .overlay(
                                Image(systemName: video.category.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(video.category.color)
                            )
                    }
                    .frame(width: 180, height: 101)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Progress Bar
                    VStack(spacing: 0) {
                        Spacer()
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.black.opacity(0.3))
                                    .frame(height: 3)
                                
                                Rectangle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geometry.size.width * progress, height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text("\(Int(progress * 100))% watched")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)
                .frame(width: 180, alignment: .leading)
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

// MARK: - Category Card
struct CategoryCard: View {
    let category: ContentFilter
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(category.gradient)
                        .frame(height: 80)
                    
                    Text(category.displayName.split(separator: " ").last?.uppercased() ?? "")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                
                Text(category.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
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

// MARK: - Live TV Card
struct LiveTVCard: View {
    let channelName: String
    let programName: String
    let isLive: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.3), .black.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                
                                if isLive {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 6, height: 6)
                                            .animation(.easeInOut(duration: 1).repeatForever(), value: isLive)
                                        
                                        Text("LIVE")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        )
                    
                    if isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(.black.opacity(0.8))
                        )
                        .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(channelName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(programName)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.top, 8)
                .frame(width: 160, alignment: .leading)
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

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Content Filter
enum ContentFilter: String, CaseIterable {
    case all = "all"
    case trending = "trending"
    case movies = "movies"
    case liveTV = "live_tv"
    case gaming = "gaming"
    case music = "music"
    case education = "education"
    case technology = "technology"
    case entertainment = "entertainment"
    case sports = "sports"
    case news = "news"
    
    var displayName: String {
        switch self {
        case .all: return "🏠 Home"
        case .trending: return "🔥 Trending"
        case .movies: return "🎬 Movies"
        case .liveTV: return "📺 Live TV"
        case .gaming: return "🎮 Gaming"
        case .music: return "🎵 Music"
        case .education: return "📚 Education"
        case .technology: return "💻 Tech"
        case .entertainment: return "🎭 Entertainment"
        case .sports: return "⚽ Sports"
        case .news: return "📰 News"
        }
    }
    
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .all: colors = [AppTheme.Colors.primary, AppTheme.Colors.secondary]
        case .trending: colors = [.orange, .red]
        case .movies: colors = [.red, .pink]
        case .liveTV: colors = [.blue, .purple]
        case .gaming: colors = [.green, .blue]
        case .music: colors = [.purple, .pink]
        case .education: colors = [.blue, .indigo]
        case .technology: colors = [.gray, .blue]
        case .entertainment: colors = [.yellow, .orange]
        case .sports: colors = [.green, .yellow]
        case .news: colors = [.red, .orange]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Preview
#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}