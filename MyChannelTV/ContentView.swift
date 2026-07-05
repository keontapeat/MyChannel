import SwiftUI
import TVUIKit
import AVKit
import AVFoundation

struct TVContentView: View {
    // Use @EnvironmentObject to consume the instances injected by MyChannelTVApp,
    // not create new independent instances (which would cause duplicate state).
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var feedVM = TVFeedViewModel()
    @State private var selectedTab: TVTab = .home
    
    enum TVTab: String, CaseIterable {
        case home, search, library, live
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .search: return "Search"  
            case .library: return "Library"
            case .live: return "Live"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .search: return "magnifyingglass"
            case .library: return "rectangle.stack"
            case .live: return "dot.radiowaves.left.and.right"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TVHomeView(feedVM: feedVM)
                .tabItem {
                    Label(TVTab.home.title, systemImage: TVTab.home.icon)
                }
                .tag(TVTab.home)
            
            TVSearchView(feedVM: feedVM)
                .tabItem {
                    Label(TVTab.search.title, systemImage: TVTab.search.icon)
                }
                .tag(TVTab.search)
            
            TVLibraryView(feedVM: feedVM)
                .tabItem {
                    Label(TVTab.library.title, systemImage: TVTab.library.icon)
                }
                .tag(TVTab.library)
            
            TVLiveView(feedVM: feedVM)
                .tabItem {
                    Label(TVTab.live.title, systemImage: TVTab.live.icon)
                }
                .tag(TVTab.live)
        }
        .environmentObject(appState)
        .environmentObject(authManager)
        .task {
            if let uid = authManager.currentUser?.id {
                await feedVM.loadLibrary(userId: uid)
            }
        }
        .onChange(of: authManager.currentUser) { user in
            if let uid = user?.id {
                Task { await feedVM.loadLibrary(userId: uid) }
            }
        }
    }
}

struct TVHomeView: View {
    @ObservedObject var feedVM: TVFeedViewModel
    @State private var selectedVideo: Video? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Hero section — real featured videos
                if !feedVM.featuredVideos.isEmpty {
                    TVHeroSection(videos: feedVM.featuredVideos, onPlay: { selectedVideo = $0 })
                }

                // Continue watching
                if !feedVM.continueWatching.isEmpty {
                    TVSection(title: "Continue Watching") {
                        TVVideoRow(videos: feedVM.continueWatching, onPlay: { selectedVideo = $0 })
                    }
                }

                // Trending
                if feedVM.isLoading {
                    ProgressView()
                        .padding(.horizontal, 80)
                } else if !feedVM.trendingVideos.isEmpty {
                    TVSection(title: "Trending") {
                        TVVideoRow(videos: feedVM.trendingVideos, onPlay: { selectedVideo = $0 })
                    }
                }

                // Categories
                TVCategoriesSection()
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .fullScreenCover(item: $selectedVideo) { video in
            TVVideoPlayerView(video: video, relatedVideos: feedVM.trendingVideos)
        }
        .refreshable { await feedVM.loadHomeFeed() }
    }
}

struct TVHeroSection: View {
    let videos: [Video]
    var onPlay: (Video) -> Void = { _ in }
    @State private var selectedIndex = 0
    
    var body: some View {
        if !videos.isEmpty {
            TabView(selection: $selectedIndex) {
                ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                    TVHeroCard(video: video)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: 600)
        }
    }
}

struct TVHeroCard: View {
    let video: Video
    @State private var isFocused = false
    
    var body: some View {
        ZStack {
            // Background image
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray4))
            }
            .frame(height: 600)
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content overlay
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(video.title)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(3)
                        
                        Text(video.description)
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(3)
                        
                        HStack(spacing: 24) {
                            Button {
                                // Play video
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(isFocused ? 1.05 : 1.0)
                            
                            Button {
                                // Add to watch later
                            } label: {
                                Label("Watch Later", systemImage: "bookmark")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(.black.opacity(0.3))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 80)
        }
        .focusable()
        .onFocusChange { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
    }
}

struct TVSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
            
            content
        }
    }
}

struct TVVideoRow: View {
    let videos: [Video]
    var onPlay: (Video) -> Void = { _ in }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 30) {
                ForEach(videos) { video in
                    TVVideoCard(video: video, onPlay: onPlay)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct TVVideoCard: View {
    let video: Video
    var onPlay: (Video) -> Void = { _ in }
    @State private var isFocused = false
    
    var body: some View {
        Button { onPlay(video) } label: {
            VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray4))
            }
            .frame(width: 320, height: 180)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white, lineWidth: isFocused ? 4 : 0)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                
                Text(video.creator.displayName)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            .frame(width: 320, alignment: .leading)
        }
        } // end Button label
        .focusable()
        .onFocusChange { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - TVVideoPlayerView (real AVPlayer)
struct TVVideoPlayerView: View {
    let video: Video
    var relatedVideos: [Video] = []
    @Environment(\.dismiss) private var dismiss

    @State private var player = AVPlayer()
    @State private var index = 0
    @State private var currentVideo: Video
    @State private var showInfo = true
    @State private var endObserver: NSObjectProtocol?
    @State private var infoHideTask: DispatchWorkItem?

    init(video: Video, relatedVideos: [Video] = []) {
        self.video = video
        self.relatedVideos = relatedVideos
        _currentVideo = State(initialValue: video)
    }

    /// Playback queue: the chosen video followed by deduped related videos (up-next).
    private var playlist: [Video] {
        [video] + relatedVideos.filter { $0.id != video.id }
    }

    private var fallbackURL: URL {
        URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                if showInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentVideo.title)
                            .font(.system(size: 34, weight: .bold))
                            .lineLimit(2)
                        Text(currentVideo.creator.displayName)
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Text("\(currentVideo.formattedViewCount) views")
                            Text("•")
                            Text(currentVideo.timeAgo)
                        }
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(60)
                    .transition(.opacity)
                }
            }
            .onAppear { start(at: index) }
            .onDisappear { saveProgress(); cleanup() }
            .onExitCommand { dismiss() }
    }

    private func start(at i: Int) {
        guard i >= 0 && i < playlist.count else { return }
        let v = playlist[i]
        currentVideo = v
        let url = URL(string: v.videoURL) ?? fallbackURL
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Resume from saved position (skip the very start / near-end)
        let saved = UserDefaults.standard.double(forKey: "tv.resume.\(v.id)")
        if saved > 5 {
            player.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
        }
        player.play()
        revealInfo()
        observeEnd(of: item)
    }

    private func revealInfo() {
        infoHideTask?.cancel()
        withAnimation { showInfo = true }
        let task = DispatchWorkItem { withAnimation { showInfo = false } }
        infoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in playNext() }
    }

    private func playNext() {
        UserDefaults.standard.removeObject(forKey: "tv.resume.\(currentVideo.id)")
        let next = index + 1
        if next < playlist.count {
            index = next
            start(at: next)
        } else {
            dismiss()
        }
    }

    private func saveProgress() {
        let t = player.currentTime().seconds
        if t.isFinite && t > 5 {
            UserDefaults.standard.set(t, forKey: "tv.resume.\(currentVideo.id)")
        }
    }

    private func cleanup() {
        infoHideTask?.cancel()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        player.pause()
    }
}

struct TVSearchView: View {
    @ObservedObject var feedVM: TVFeedViewModel
    @State private var searchText = ""
    @State private var selectedVideo: Video? = nil
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("Search")
                    .font(.system(size: 48, weight: .bold))
                
                TextField("Search for videos, creators, and more", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 24))
                    .frame(maxWidth: 800)
                    .onSubmit {
                        Task { await feedVM.search(query: searchText) }
                    }
            }
            .padding(.top, 100)
            
            if feedVM.isSearching {
                ProgressView()
            } else if !feedVM.searchResults.isEmpty {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 30) {
                        ForEach(feedVM.searchResults) { video in
                            TVVideoCard(video: video, onPlay: { selectedVideo = $0 })
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 80)
        .fullScreenCover(item: $selectedVideo) { video in
            TVVideoPlayerView(video: video, relatedVideos: feedVM.searchResults)
        }
    }
}

struct TVLibraryView: View {
    @ObservedObject var feedVM: TVFeedViewModel
    @EnvironmentObject private var appState: AppState
    @State private var selectedVideo: Video? = nil
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Your Library")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)
            
            if appState.isAuthenticated {
                TVSection(title: "Watch Later") {
                    TVVideoRow(videos: feedVM.watchLater.isEmpty
                        ? []
                        : feedVM.watchLater,
                    onPlay: { selectedVideo = $0 })
                }
                
                TVSection(title: "Watch History") {
                    TVVideoRow(videos: feedVM.watchHistory, onPlay: { selectedVideo = $0 })
                }
                
                TVSection(title: "Liked Videos") {
                    TVVideoRow(videos: feedVM.likedVideos, onPlay: { selectedVideo = $0 })
                }
            } else {
                VStack(spacing: 20) {
                    Text("Sign in to access your library")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        // Handle sign in
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 20))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 80)
        .fullScreenCover(item: $selectedVideo) { video in
            TVVideoPlayerView(video: video)
        }
    }
}

struct TVLiveView: View {
    @ObservedObject var feedVM: TVFeedViewModel

    var body: some View {
        VStack(spacing: 40) {
            Text("Live TV")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)
            
            if feedVM.liveStreams.isEmpty && feedVM.isLoading {
                ProgressView()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 40) {
                    ForEach(feedVM.liveStreams) { channel in
                        TVChannelCard(channel: channel)
                    }
                }
                .padding(.horizontal, 80)
            }
            
            Spacer()
        }
        .refreshable { await feedVM.loadHomeFeed() }
    }
}

struct TVChannelCard: View {
    let channel: LiveTVChannel
    @State private var isFocused = false
    @State private var isPlaying = false

    var body: some View {
        Button {
            isPlaying = true
        } label: {
            VStack(spacing: 12) {
            AsyncImage(url: URL(string: channel.logoURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray4))
            }
            .frame(width: 280, height: 160)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white, lineWidth: isFocused ? 4 : 0)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            
            VStack(spacing: 4) {
                Text(channel.name)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                
                if channel.isLive {
                    HStack {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("LIVE • \(channel.viewerCount) viewers")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 280)
        } // end Button label
        .focusable()
        .onFocusChange { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $isPlaying) {
            TVLivePlayerView(streamURL: channel.streamURL)
        }
    }
}

// MARK: - TVLivePlayerView (real HLS playback for live channels)
struct TVLivePlayerView: View {
    let streamURL: String
    @Environment(\.dismiss) private var dismiss

    private var player: AVPlayer {
        let url = URL(string: streamURL) ?? URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
        return AVPlayer(url: url)
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear { player.play() }
            .onDisappear { player.pause() }
            .onExitCommand { dismiss() }
    }
}

struct TVCategoriesSection: View {
    let categories = VideoCategory.allCases.prefix(8)
    
    var body: some View {
        TVSection(title: "Categories") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 30) {
                ForEach(Array(categories), id: \.rawValue) { category in
                    TVCategoryCard(category: category)
                }
            }
        }
    }
}

struct TVCategoryCard: View {
    let category: VideoCategory
    @State private var isFocused = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(category.color.opacity(0.8))
                    .frame(width: 160, height: 160)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white, lineWidth: isFocused ? 4 : 0)
            )
            
            Text(category.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .focusable()
        .onFocusChange { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if os(tvOS)
#Preview {
    TVContentView()
}
#endif


