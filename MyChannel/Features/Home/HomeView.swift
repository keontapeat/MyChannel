import SwiftUI
import Combine

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var selectedFilter: ContentFilter = .all
    @State private var searchText: String = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false
    @State private var selectedVideo: Video? = nil
    @State private var showingVideoPlayer: Bool = false
    @State private var selectedMovie: FreeMovie? = nil
    @State private var showingSearchView: Bool = false
    @State private var featuredContent: [Video] = []
    @State private var heroVideoIndex: Int = 0
    @State private var showingStories: Bool = true
    @State private var assetStories: [AssetStory] = AssetStory.sampleStories
    @State private var selectedAssetStory: AssetStory? = nil
    @State private var showingAssetStoryViewer: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // Main Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Header Spacer
                        Color.clear.frame(height: 100)
                        
                        // Stories Section
                        if showingStories {
                            MinimalStoriesSection(
                                stories: assetStories,
                                onStoryTap: { story in
                                    selectedAssetStory = story
                                    showingAssetStoryViewer = true
                                },
                                onAddStory: {
                                    HapticManager.shared.impact(style: .medium)
                                }
                            )
                            .padding(.bottom, 32)
                        }
                        
                        // Featured Hero Section
                        MinimalHeroSection(
                            featuredContent: featuredContent,
                            heroVideoIndex: heroVideoIndex,
                            onPlayVideo: playVideo,
                            onAddToList: toggleWatchLater
                        )
                        .padding(.bottom, 40)
                        
                        // Content Sections
                        MinimalContentSections(
                            onPlayVideo: playVideo,
                            onSelectMovie: { movie in selectedMovie = movie }
                        )
                        
                        // Bottom Spacer
                        Color.clear.frame(height: 100)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onScrollOffsetChange { offset in
                    scrollOffset = offset
                }
                
                // Minimal Navigation Header
                MinimalNavigationHeader(
                    scrollOffset: scrollOffset,
                    onSearchTap: { showingSearchView = true },
                    onProfileTap: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfileTab"), object: nil)
                    }
                )
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
        .fullScreenCover(item: $selectedAssetStory) { story in
            AssetStoryViewerView(story: story) {
                selectedAssetStory = nil
            }
        }
        .onReceive(Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                heroVideoIndex = (heroVideoIndex + 1) % max(1, featuredContent.count)
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
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleWatchLater(_ video: Video) {
        appState.toggleWatchLater(for: video.id)
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Minimal Navigation Header
struct MinimalNavigationHeader: View {
    let scrollOffset: CGFloat
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void
    
    @EnvironmentObject private var appState: AppState
    
    private var headerOpacity: Double {
        min(1.0, max(0.0, 1.0 - (scrollOffset / 100.0)))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Clean Logo
                HStack(spacing: 12) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                    
                    Text("MyChannel")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Minimal Actions
                HStack(spacing: 24) {
                    Button(action: onSearchTap) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    NavigationLink(destination: NotificationsView()) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if true { // Has notifications
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    
                    Button(action: onProfileTap) {
                        AsyncImage(url: URL(string: appState.currentUser?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 16)
            .background(
                Color(.systemBackground)
                    .opacity(scrollOffset > 50 ? 0.95 : 0)
                    .background(.ultraThinMaterial.opacity(scrollOffset > 50 ? 1 : 0))
            )
            
            Spacer()
        }
    }
}

// MARK: - Minimal Stories Section
struct MinimalStoriesSection: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Add Story Button
                Button(action: onAddStory) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text("Your Story")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Stories
                ForEach(stories) { story in
                    Button(action: { onStoryTap(story) }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.pink, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 64, height: 64)
                                
                                AsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(story.id.hashValue)")) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Image(story.authorImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                }
                            }
                            
                            Text(story.username)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Minimal Hero Section
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    let heroVideoIndex: Int
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void
    
    var body: some View {
        if !featuredContent.isEmpty {
            let currentVideo = featuredContent[heroVideoIndex % featuredContent.count]
            
            VStack(spacing: 20) {
                // Featured Badge
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        
                        Text("FEATURED")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .tracking(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Video Thumbnail
                AsyncImage(url: URL(string: currentVideo.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(height: 220)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: currentVideo.category.iconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                
                                Text(currentVideo.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 40)
                            }
                        )
                }
                .padding(.horizontal, 20)
                
                // Video Info
                VStack(spacing: 12) {
                    Text(currentVideo.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                    
                    // Metadata
                    HStack(spacing: 16) {
                        Text(currentVideo.category.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(currentVideo.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(currentVideo.formattedViewCount) views")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: { onPlayVideo(currentVideo) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        Button(action: { onAddToList(currentVideo) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Minimal Content Sections
struct MinimalContentSections: View {
    let onPlayVideo: (Video) -> Void
    let onSelectMovie: (FreeMovie) -> Void
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 40) {
            // Continue Watching
            if !appState.watchHistory.isEmpty {
                MinimalSection(
                    title: "Continue Watching",
                    seeAllAction: nil
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Video.sampleVideos.prefix(5)) { video in
                                MinimalVideoCard(video: video, action: { onPlayVideo(video) })
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            
            // Trending Now
            MinimalSection(
                title: "Trending Now",
                seeAllAction: { /* Navigate to trending */ }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Video.sampleVideos.filter { $0.viewCount > 100000 }.prefix(8)) { video in
                            MinimalVideoCard(video: video, action: { onPlayVideo(video) })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Free Movies
            MinimalSection(
                title: "Free Movies",
                seeAllAction: { /* Navigate to movies */ }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(FreeMovie.sampleMovies.prefix(6)) { movie in
                            MinimalMovieCard(movie: movie, action: { onSelectMovie(movie) })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Live TV
            MinimalSection(
                title: "Live TV",
                seeAllAction: { /* Navigate to live TV */ }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(LiveTVChannel.sampleChannels.prefix(8)) { channel in
                            MinimalChannelCard(channel: channel)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Minimal Section
struct MinimalSection<Content: View>: View {
    let title: String
    let seeAllAction: (() -> Void)?
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let seeAllAction = seeAllAction {
                    Button("See all", action: seeAllAction)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            
            content
        }
    }
}

// MARK: - Minimal Video Card
struct MinimalVideoCard: View {
    let video: Video
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 101)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(width: 180, height: 101)
                        .overlay(
                            Image(systemName: video.category.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(video.formattedDuration)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(.black.opacity(0.7))
                                )
                                .padding(8)
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("\(video.formattedViewCount) views")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Minimal Movie Card
struct MinimalMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                MultiSourceAsyncImage(
                    urls: movie.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                            .frame(width: 120, height: 180)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "film.stack")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    
                                    Text(movie.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 8)
                                }
                            )
                    }
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(
                                    index < Int(movie.imdbRating / 2) ? .yellow : Color(.systemGray4)
                                )
                        }
                        
                        Text("\(movie.imdbRating, specifier: "%.1f")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Minimal Channel Card
struct MinimalChannelCard: View {
    let channel: LiveTVChannel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 160, height: 90)
                
                VStack(spacing: 6) {
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(channel.name.prefix(2).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        )
                    
                    if channel.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 4, height: 4)
                            
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(formatViewerCount(channel.viewerCount)) viewers")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 160, alignment: .leading)
        }
    }
    
    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
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
    
    var displayName: String {
        switch self {
        case .all: return "Home"
        case .trending: return "Trending"
        case .movies: return "Movies"
        case .liveTV: return "Live TV"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .education: return "Education"
        }
    }
}

// MARK: - Preview
#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}