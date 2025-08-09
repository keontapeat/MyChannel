import SwiftUI
import Combine

// MARK: - Enhanced Video Playback
class RemoteConfigManager: ObservableObject {
    @Published var config: RemoteConfig? = nil
    
    var chatModels: [RemoteChatModel] {
        config?.chat_models ?? []
    }
    
    init() {
        self.fetch()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.fetch()
        }
    }
    
    func fetch() {
        Task {
            await MainActor.run {
            }
        }
    }
}

// MARK: - Remote Config Model
struct RemoteConfig {
    let chat_models: [RemoteChatModel]
}

struct RemoteChatModel {
    let id: String
    let name: String
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var selectedFilter: ContentFilter = .all
    @State private var searchText: String = ""
    @State private var showingFilters: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false
    @State private var showingStories: Bool = true
    @State private var headerOpacity: Double = 1.0
    @State private var isLoading: Bool = false
    @State private var selectedVideo: Video? = nil
    @State private var showingVideoPlayer: Bool = false
    @State private var selectedStory: Story? = nil
    @State private var showingStoryViewer: Bool = false
    @State private var stories: [Story] = Story.sampleStories
    @State private var showingSearchView: Bool = false
    @State private var assetStories: [AssetStory] = AssetStory.sampleStories
    @State private var selectedAssetStory: AssetStory? = nil
    @State private var showingAssetStoryViewer: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ParallaxHeaderView(
                            scrollOffset: scrollOffset,
                            headerOpacity: headerOpacity,
                            selectedFilter: $selectedFilter,
                            searchText: $searchText,
                            showingFilters: $showingFilters,
                            showingSearchView: $showingSearchView
                        )
                        
                        if showingStories {
                            AssetBouncyStoriesRow(
                                stories: assetStories,
                                onStoryTap: { story in
                                    selectedAssetStory = story
                                    showingAssetStoryViewer = true
                                },
                                onAddStory: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                        
                        ClickableTrendingCarousel(
                            videos: Video.sampleVideos.filter { $0.viewCount > 100000 },
                            onVideoTap: playVideoWithGlobalPlayer
                        )

                        if selectedFilter == .movies || selectedFilter == .all {
                            PremiumMoviesHubSection(
                                onMovieTap: { movie in
                                    print(" Movie tapped: \(movie.title)")
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }

                        AnimatedFilterChipsView(
                            selectedFilter: $selectedFilter,
                            scrollOffset: scrollOffset
                        )
                        
                        ClickableLiveStreamsSection(
                            onStreamTap: { _ in
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        )
                        
                        if selectedFilter == .liveTV || selectedFilter == .all {
                            PremiumLiveTVSection(
                                onChannelTap: { channel in
                                    print(" Live TV Channel tapped: \(channel.name)")
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        ClickableVideoFeedSection(
                            videos: Video.sampleVideos,
                            selectedFilter: selectedFilter,
                            watchLaterVideos: $appState.watchLaterVideos,
                            likedVideos: $appState.likedVideos,
                            isLoading: $isLoading,
                            onVideoTap: playVideoWithGlobalPlayer
                        )
                        
                        if isLoading {
                            PaginationLoadingView()
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .refreshable {
                    await refreshContent()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .onAppear {
            loadMoreContent()
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
                    .onAppear {
                        print(" VideoDetailView appeared for: \(video.title)")
                    }
                    .onDisappear {
                        print(" VideoDetailView disappeared")
                        selectedVideo = nil
                    }
            } else {
                Text("No video selected")
                    .foregroundColor(.white)
                    .background(Color.black)
            }
        }
        .onChange(of: showingVideoPlayer) { oldValue, newValue in
            print(" showingVideoPlayer changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: selectedVideo) { oldValue, newValue in
            print(" selectedVideo changed: \(oldValue?.title ?? "nil") -> \(newValue?.title ?? "nil")")
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            let safeStory = selectedStory ?? stories.first ?? Story.sampleStories.first!
            let safeStories = stories.isEmpty ? Story.sampleStories : stories
            
            StoryViewerView(
                stories: safeStories,
                initialStory: safeStory,
                onDismiss: {
                    showingStoryViewer = false
                    selectedStory = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showingAssetStoryViewer) {
            if let s = selectedAssetStory {
                NavigationStack {
                    AssetStoryViewerView(story: s) {
                        showingAssetStoryViewer = false
                        selectedAssetStory = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSearchView) {
            SearchView()
                .onAppear {
                    print(" SearchView appeared")
                }
                .onDisappear {
                    print(" SearchView disappeared")
                    showingSearchView = false
                }
        }
    }
    
    // MARK: - Enhanced Video Playback
    private func playVideoWithGlobalPlayer(_ video: Video) {
        selectedVideo = video
        showingVideoPlayer = true
    }
    
    private func refreshContent() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        stories = Story.sampleStories
        isRefreshing = false
    }
    
    private func loadMoreContent() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
}

// MARK: - Parallax Header View
struct ParallaxHeaderView: View {
    let scrollOffset: CGFloat
    let headerOpacity: Double
    @Binding var selectedFilter: ContentFilter
    @Binding var searchText: String
    @Binding var showingFilters: Bool
    @Binding var showingSearchView: Bool
    
    @State private var logoScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 12) {
                        Image("MyChannel")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .scaleEffect(logoScale * max(0.8, 1.0 - abs(scrollOffset) / 200.0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scrollOffset)
                            .animation(.easeInOut(duration: 2.0), value: logoScale)
                            .onAppear {
                                startSubtleZoom()
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MyChannel")
                                .font(AppTheme.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Welcome back!")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .opacity(headerOpacity)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showingSearchView = true
                        }) {
                            HomeActionButton(
                                icon: "magnifyingglass",
                                isActive: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        QuickActionsMenu()
                        
                        NavigationLink(destination: NotificationsView()) {
                            NotificationButton()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(height: 44)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.background,
                            AppTheme.Colors.background.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(headerOpacity)
                )
                .overlay(
                    Rectangle()
                        .fill(AppTheme.Colors.divider.opacity(0.2))
                        .frame(height: 1)
                        .opacity(1 - headerOpacity),
                    alignment: .bottom
                )
            }
            .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)
            .opacity(headerOpacity)
        }
    }
    
    private func startSubtleZoom() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                logoScale = logoScale == 1.0 ? 1.08 : 1.0
            }
        }
    }
}

// MARK: - Clickable Trending Carousel
struct ClickableTrendingCarousel: View {
    let videos: [Video]
    let onVideoTap: (Video) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.system(size: 16))
                    
                    Text("Trending Now")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink("See all", destination: TrendingView())
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(videos.filter { $0.viewCount > 100000 }.prefix(5)) { video in
                        ClickableTrendingVideoCard(video: video) {
                            onVideoTap(video)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Clickable Trending Video Card
struct ClickableTrendingVideoCard: View {
    let video: Video
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure(_):
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
                                    VStack(spacing: 8) {
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 32))
                                            .foregroundColor(video.category.color)
                                        
                                        Text(video.category.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(video.category.color)
                                    }
                                )
                        case .empty:
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
                                    VStack(spacing: 8) {
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 32))
                                            .foregroundColor(video.category.color)
                                        
                                        Text(video.category.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(video.category.color)
                                    }
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 180, height: 101)
                    .clipped()
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                    )
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                    .opacity(isPressed ? 1.0 : 0.8)
                    
                    VStack(alignment: .trailing) {
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if video.isLive {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                                
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text(video.formattedDuration)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
                    HStack(spacing: 6) {
                        AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(video.category.color.opacity(0.2))
                                .overlay(
                                    Text(String(video.creator.displayName.prefix(1)))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(video.category.color)
                                )
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                        
                        if video.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(video.formattedViewCount) views")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(video.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .frame(width: 180, height: 64, alignment: .top)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { 
                isPressed = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            },
            onRelease: { 
                isPressed = false 
            }
        )
        .accessibilityLabel(video.title)
        .accessibilityHint("Double tap to play video")
    }
}

// MARK: - Animated Filter Chips View
struct AnimatedFilterChipsView: View {
    @Binding var selectedFilter: ContentFilter
    let scrollOffset: CGFloat
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ContentFilter.allCases, id: \.self) { filter in
                    AnimatedFilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter,
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedFilter = filter
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            AppTheme.Colors.background
                .opacity(min(1.0, abs(scrollOffset) / 50.0))
        )
    }
}

// MARK: - Animated Filter Chip
struct AnimatedFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, isSelected ? 20 : 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        AppTheme.Colors.surface
                    }
                    
                    if isPressed {
                        Color.black.opacity(0.1)
                    }
                }
            )
            .foregroundColor(
                isSelected ? .white : AppTheme.Colors.textPrimary
            )
            .cornerRadius(AppTheme.CornerRadius.xl)
            .shadow(
                color: isSelected ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityHint(isSelected ? "Currently selected filter" : "Double tap to select filter")
    }
}

// MARK: - Clickable Live Streams Section
struct ClickableLiveStreamsSection: View {
    let onStreamTap: (User) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    
                    Text("Live Now")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink("See all", destination: LiveStreamsView())
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<min(3, User.sampleUsers.count), id: \.self) { index in
                        if !User.sampleUsers.isEmpty {
                            ClickableLiveStreamCard(
                                creator: User.sampleUsers[index],
                                viewerCount: Int.random(in: 100...5000)
                            ) {
                                onStreamTap(User.sampleUsers[index])
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Clickable Live Stream Card
struct ClickableLiveStreamCard: View {
    let creator: User
    let viewerCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 90)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                
                                Text("GO LIVE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                        )
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                        
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .padding(6)
                }
                
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(creator.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(viewerCount.formatted()) watching")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
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
        .accessibilityLabel("\(creator.displayName)'s live stream")
        .accessibilityHint("Double tap to join live stream")
    }
}

// MARK: - Clickable Video Feed Section
struct ClickableVideoFeedSection: View {
    let videos: [Video]
    let selectedFilter: ContentFilter
    @Binding var watchLaterVideos: Set<String>
    @Binding var likedVideos: Set<String>
    @Binding var isLoading: Bool
    let onVideoTap: (Video) -> Void
    
    var filteredVideos: [Video] {
        if selectedFilter == .all {
            return videos
        } else {
            return videos.filter { $0.category.rawValue == selectedFilter.rawValue }
        }
    }
    
    var body: some View {
        LazyVStack(spacing: AppTheme.Spacing.lg) {
            ForEach(filteredVideos) { video in
                ProfessionalVideoCard(
                    video: video,
                    isLiked: likedVideos.contains(video.id),
                    isWatchLater: watchLaterVideos.contains(video.id),
                    onVideoTap: {
                        onVideoTap(video)
                    },
                    onLike: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if likedVideos.contains(video.id) {
                                likedVideos.remove(video.id)
                            } else {
                                likedVideos.insert(video.id)
                            }
                        }
                    },
                    onWatchLater: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.1)) {
                            if watchLaterVideos.contains(video.id) {
                                watchLaterVideos.remove(video.id)
                            } else {
                                watchLaterVideos.insert(video.id)
                            }
                        }
                    }
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .onAppear {
                    if video.id == filteredVideos.last?.id {
                        loadMoreContent()
                    }
                }
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }
    
    private func loadMoreContent() {
        guard !isLoading else { return }
    }
}

// MARK: - Professional Video Card
struct ProfessionalVideoCard: View {
    let video: Video
    let isLiked: Bool
    let isWatchLater: Bool
    let onVideoTap: () -> Void
    let onLike: () -> Void
    let onWatchLater: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onVideoTap()
            }) {
                ZStack(alignment: .center) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure(_):
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            video.category.color.opacity(0.4),
                                            video.category.color.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 40))
                                            .foregroundColor(video.category.color)
                                        
                                        Text(video.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(video.category.color)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .padding(.horizontal, 20)
                                        
                                        Text(video.category.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(video.category.color.opacity(0.8))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(video.category.color.opacity(0.2))
                                            )
                                    }
                                )
                        case .empty:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            video.category.color.opacity(0.4),
                                            video.category.color.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 40))
                                            .foregroundColor(video.category.color)
                                        
                                        Text(video.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(video.category.color)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .padding(.horizontal, 20)
                                        
                                        Text(video.category.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(video.category.color.opacity(0.8))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(video.category.color.opacity(0.2))
                                            )
                                    }
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(AppTheme.CornerRadius.lg)
                    .clipped()
                    
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .opacity(isPressed ? 1.0 : 0.9)
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Text(video.formattedDuration)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.black.opacity(0.8))
                                )
                        }
                    }
                    .padding(12)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .onPressGesture(
                onPress: { isPressed = true },
                onRelease: { isPressed = false }
            )
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(video.category.color.opacity(0.3))
                            .overlay(
                                Text(String(video.creator.displayName.prefix(1)))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(video.category.color)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            onVideoTap()
                        }) {
                            Text(video.title)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Button(action: {}) {
                                    Text(video.creator.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if video.creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Text("\(video.formattedViewCount) views")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("•")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text(video.timeAgo)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            onWatchLater()
                        }) {
                            Label(
                                isWatchLater ? "Remove from Watch Later" : "Save to Watch Later",
                                systemImage: isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                        }
                        
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {}) {
                            Label("Not Interested", systemImage: "hand.thumbsdown")
                        }
                        
                        Button(action: {}) {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(8)
                    }
                }
                
                HStack(spacing: 24) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onLike()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .scaleEffect(isLiked ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                            
                            Text("\(video.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("\(video.commentCount)")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("Share")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onWatchLater()
                    }) {
                        Image(systemName: isWatchLater ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18))
                            .foregroundColor(isWatchLater ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .scaleEffect(isWatchLater ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isWatchLater)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Supporting Views and Extensions
struct HomeActionButton: View {
    let icon: String
    let isActive: Bool
    let action: (() -> Void)?
    
    init(icon: String, isActive: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .padding(8)
                .background(
                    Circle()
                        .fill(isActive ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
                        .shadow(
                            color: isActive ? AppTheme.Colors.primary.opacity(0.2) : .clear,
                            radius: isActive ? 4 : 0,
                            x: 0,
                            y: 2
                        )
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(icon)
        .accessibilityHint(isActive ? "Active" : "Inactive")
    }
}

struct NotificationButton: View {
    @State private var badgeCount: Int = 3
    
    var body: some View {
        ZStack {
            Image(systemName: "bell")
                .font(.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .offset(x: 10, y: -10)
                    .scaleEffect(badgeCount > 0 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: badgeCount)
            }
        }
        .accessibilityLabel("Notifications")
        .accessibilityValue(badgeCount > 0 ? "\(badgeCount) unread notifications" : "No unread notifications")
    }
}

struct SkeletonView: View {
    @State private var isAnimating: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct PaginationLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(0.8)
            
            Text("Loading more videos...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .accessibilityLabel("Loading more content")
    }
}

// MARK: - Enhanced Content Filter
enum ContentFilter: String, CaseIterable {
    case all = "all"
    case trending = "trending"
    case liveTV = "live_tv"
    case movies = "movies"
    case gaming = "gaming"
    case music = "music"
    case education = "education"
    case technology = "technology"
    case entertainment = "entertainment"
    case sports = "sports"
    case news = "news"
    case live = "live"
    case lifestyle = "lifestyle"
    case food = "food"
    case travel = "travel"
    case comedy = "comedy"
    case fitness = "fitness"
    case business = "business"
    case science = "science"
    case fashion = "fashion"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .trending: return "🔥 Trending"
        case .liveTV: return "📺 Live TV"
        case .movies: return "🎬 Movies"
        case .gaming: return "🎮 Gaming"
        case .music: return "🎵 Music"
        case .education: return "📚 Education"
        case .technology: return "💻 Tech"
        case .entertainment: return "🎭 Entertainment"
        case .sports: return "⚽ Sports"
        case .news: return "📰 News"
        case .live: return "🔴 Live"
        case .lifestyle: return "✨ Lifestyle"
        case .food: return "🍕 Food"
        case .travel: return "✈️ Travel"
        case .comedy: return "😂 Comedy"
        case .fitness: return "💪 Fitness"
        case .business: return "💼 Business"
        case .science: return "🔬 Science"
        case .fashion: return "👗 Fashion"
        }
    }
    
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .all:
            colors = [AppTheme.Colors.primary, AppTheme.Colors.secondary]
        case .trending:
            colors = [.orange, .red]
        case .liveTV:
            colors = [.blue, .purple]
        case .movies:
            colors = [.red, .pink]
        case .gaming:
            colors = [.green, .blue]
        case .music:
            colors = [.purple, .pink]
        case .education:
            colors = [.blue, .indigo]
        case .technology:
            colors = [.gray, .blue]
        case .entertainment:
            colors = [.yellow, .orange]
        case .sports:
            colors = [.green, .yellow]
        case .news:
            colors = [.red, .orange]
        case .live:
            colors = [.red, .pink]
        case .lifestyle:
            colors = [.pink, .purple]
        case .food:
            colors = [.orange, .yellow]
        case .travel:
            colors = [.blue, .cyan]
        case .comedy:
            colors = [.yellow, .orange]
        case .fitness:
            colors = [.green, .mint]
        case .business:
            colors = [.gray, .blue]
        case .science:
            colors = [.blue, .purple]
        case .fashion:
            colors = [.pink, .purple]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Previews
#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(GlobalVideoPlayerManager.shared)
}

#Preview("ParallaxHeaderView") {
    ParallaxHeaderView(
        scrollOffset: 0,
        headerOpacity: 1.0,
        selectedFilter: .constant(.all),
        searchText: .constant(""),
        showingFilters: .constant(false),
        showingSearchView: .constant(false)
    )
    .environmentObject(AppState())
}

#Preview("Trending Carousel") {
    ClickableTrendingCarousel(videos: Video.sampleVideos, onVideoTap: { _ in })
    .environmentObject(AppState())
}

#Preview("Trending Card") {
    ClickableTrendingVideoCard(video: Video.sampleVideos.first!, action: {})
    .environmentObject(AppState())
}

#Preview("Filter Chips") {
    AnimatedFilterChipsView(selectedFilter: .constant(.all), scrollOffset: 0)
    .environmentObject(AppState())
}

#Preview("Filter Chip") {
    AnimatedFilterChip(title: "🔥 Trending", isSelected: true, action: {})
    .environmentObject(AppState())
}

#Preview("Live Streams Section") {
    ClickableLiveStreamsSection(onStreamTap: { _ in })
    .environmentObject(AppState())
}

#Preview("Live Stream Card") {
    ClickableLiveStreamCard(
        creator: User.sampleUsers.first ?? User.sampleUsers[0],
        viewerCount: 1234,
        action: {}
    )
    .environmentObject(AppState())
}

#Preview("Video Feed Section") {
    ClickableVideoFeedSection(
        videos: Video.sampleVideos,
        selectedFilter: .all,
        watchLaterVideos: .constant([]),
        likedVideos: .constant([]),
        isLoading: .constant(false),
        onVideoTap: { _ in }
    )
    .environmentObject(AppState())
}

#Preview("Video Card") {
    ProfessionalVideoCard(
        video: Video.sampleVideos.first!,
        isLiked: false,
        isWatchLater: false,
        onVideoTap: {},
        onLike: {},
        onWatchLater: {}
    )
    .environmentObject(AppState())
}

#Preview("Notification Button") {
    NotificationButton()
    .environmentObject(AppState())
}

#Preview("Skeleton") {
    SkeletonView()
    .frame(height: 120)
    .environmentObject(AppState())
}

#Preview("Pagination Loading View") {
    PaginationLoadingView()
    .environmentObject(AppState())
}

#Preview("Asset Stories Section") {
    AssetBouncyStoriesRow(
        stories: AssetStory.sampleStories,
        onStoryTap: { _ in },
        onAddStory: {}
    )
    .environmentObject(AppState())
}