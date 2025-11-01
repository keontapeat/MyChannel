import SwiftUI
import TVUIKit

struct TVContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager.shared
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
            TVHomeView()
                .tabItem {
                    Label(TVTab.home.title, systemImage: TVTab.home.icon)
                }
                .tag(TVTab.home)
            
            TVSearchView()
                .tabItem {
                    Label(TVTab.search.title, systemImage: TVTab.search.icon)
                }
                .tag(TVTab.search)
            
            TVLibraryView()
                .tabItem {
                    Label(TVTab.library.title, systemImage: TVTab.library.icon)
                }
                .tag(TVTab.library)
            
            TVLiveView()
                .tabItem {
                    Label(TVTab.live.title, systemImage: TVTab.live.icon)
                }
                .tag(TVTab.live)
        }
        .environmentObject(appState)
        .environmentObject(authManager)
    }
}

struct TVHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var featuredVideos: [Video] = []
    @State private var trendingVideos: [Video] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Hero section
                if !featuredVideos.isEmpty {
                    TVHeroSection(videos: featuredVideos)
                }
                
                // Continue watching
                if !appState.watchHistory.isEmpty {
                    TVSection(title: "Continue Watching") {
                        TVVideoRow(videos: Array(Video.sampleVideos.prefix(8)))
                    }
                }
                
                // Trending
                TVSection(title: "Trending") {
                    TVVideoRow(videos: trendingVideos)
                }
                
                // Categories
                TVCategoriesSection()
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .onAppear {
            loadContent()
        }
    }
    
    private func loadContent() {
        featuredVideos = Array(Video.sampleVideos.prefix(5))
        trendingVideos = Array(Video.sampleVideos.shuffled().prefix(12))
    }
}

struct TVHeroSection: View {
    let videos: [Video]
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
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 30) {
                ForEach(videos) { video in
                    TVVideoCard(video: video)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct TVVideoCard: View {
    let video: Video
    @State private var isFocused = false
    
    var body: some View {
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
        .focusable()
        .onFocusChange { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TVSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Video] = []
    
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
                        performSearch()
                    }
            }
            .padding(.top, 100)
            
            if !searchResults.isEmpty {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 30) {
                        ForEach(searchResults) { video in
                            TVVideoCard(video: video)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 80)
    }
    
    private func performSearch() {
        // Simulate search
        searchResults = Video.sampleVideos.filter { video in
            video.title.localizedCaseInsensitiveContains(searchText) ||
            video.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct TVLibraryView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Your Library")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)
            
            if appState.isAuthenticated {
                TVSection(title: "Watch Later") {
                    TVVideoRow(videos: Array(Video.sampleVideos.prefix(8)))
                }
                
                TVSection(title: "Watch History") {
                    TVVideoRow(videos: Array(Video.sampleVideos.prefix(8)))
                }
                
                TVSection(title: "Liked Videos") {
                    TVVideoRow(videos: Array(Video.sampleVideos.prefix(8)))
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
    }
}

struct TVLiveView: View {
    @State private var liveChannels: [LiveTVChannel] = []
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Live TV")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 40) {
                ForEach(liveChannels) { channel in
                    TVChannelCard(channel: channel)
                }
            }
            .padding(.horizontal, 80)
            
            Spacer()
        }
        .onAppear {
            loadLiveChannels()
        }
    }
    
    private func loadLiveChannels() {
        liveChannels = Array(LiveTVChannel.sampleChannels.prefix(12))
    }
}

struct TVChannelCard: View {
    let channel: LiveTVChannel
    @State private var isFocused = false
    
    var body: some View {
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


