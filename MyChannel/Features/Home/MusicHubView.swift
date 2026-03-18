import SwiftUI
import Combine

// MARK: - 🔥 ULTIMATE MUSIC HUB - Apple Music Level Quality 🔥

struct MusicHubView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var flintService = FlintArtistService.shared
    @State private var trending: [CatalogSong] = []
    @State private var local: [CatalogSong] = []
    @State private var forYou: [CatalogSong] = []
    @State private var artists: [CatalogArtist] = []
    @State private var albums: [CatalogAlbum] = []
    @State private var searchText: String = ""
    @State private var loading: Bool = true
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var recentQueries: [String] = []
    @State private var safariURL: URL? = nil
    @State private var showSafari: Bool = false
    @State private var segment: Segment = .songs
    @State private var selectedMood: MusicMood? = nil
    @State private var animateHero: Bool = false
    @State private var showEqualizer: Bool = false
    @State private var showNowPlaying: Bool = false
    @State private var showListeningStats: Bool = false
    @State private var showShazam: Bool = false
    @State private var showDownloads: Bool = false
    @State private var showLibrary: Bool = false
    @State private var showKaraoke: Bool = false
    @State private var showSettings: Bool = false
    @State private var showConcerts: Bool = false
    @State private var showMerch: Bool = false
    @State private var showDiscover: Bool = false
    @State private var showUploadSheet: Bool = false
    @State private var showArtistCTA: Bool = true
    @StateObject private var discoveryFeed = MusicDiscoveryFeedService.shared
    
    enum Segment: String, CaseIterable { case songs = "Songs", artists = "Artists", albums = "Albums" }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        // 🔥 HERO SECTION - Apple Music Style
                        heroSection
                        
                        VStack(spacing: 24) {
                            // Quick Actions Row
                            quickActionsRow
                            
                            // 🎵 Artist Upload CTA
                            if showArtistCTA {
                                artistUploadCTA
                            }
                            
                            // 🔥 FLINT ARTISTS - 810 REPRESENT (TOP PRIORITY!)
                            FlintArtistsSection()
                            
                            // 🆕 New Artist Drops
                            if !discoveryFeed.newDrops.isEmpty {
                                newArtistDropsSection
                            }
                            
                            // 🔥 Curated Playlists
                            curatedPlaylistsSection
                            
                            // 🔥 810 Radio
                            radioStationsSection
                            
                            // 🔥 Discover Weekly & For You
                            discoverSection
                            
                            // � Trending on MyChannel (creator uploads)
                            if !discoveryFeed.trendingUploads.isEmpty {
                                trendingOnMyChannelSection
                            }
                            
                            // � Friend Activity
                            friendActivitySection
                            
                            // 🔥 Concerts & Events
                            concertsPreviewSection
                            
                            // 🔥 Behind the Music Stories
                            behindTheMusicSection
                            
                            // Search bar
                            searchBar
                            
                            // Mood/Genre Quick Filters
                            moodFilterRow
                            
                            // Segment Control
                            segmentControl
                            
                            // Content based on segment
                            if segment == .songs {
                                // Charts
                                chartsSection
                                
                                forYouSection
                                trendingSection
                                newReleasesSection
                            }
                            if segment == .artists { artistsSection }
                            if segment == .albums { albumsSection }
                            
                            // 🎥 Music Videos
                            MusicVideosSection()
                            
                            // Spatial Audio Section
                            spatialAudioSection
                            
                            // Recently Played
                            recentlyPlayedSection
                            
                            // Local Artists Section
                            localSection
                            
                            // Browse by Genre
                            genreBrowseSection
                            
                            // Bottom padding for now playing bar
                            Spacer().frame(height: 100)
                        }
                        .padding(.vertical, 16)
                    }
                }
                // Global Now Playing Bar is injected via MainTabView; no local bar here
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { try? awaitBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showEqualizer = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Button {
                            showSettings = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .task { await load() }
            .onAppear { 
                loadRecentQueries()
                withAnimation(.easeOut(duration: 0.8)) {
                    animateHero = true
                }
            }
            .onChange(of: searchText) { newValue in
                searchTask?.cancel()
                searchTask = Task { [newValue] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    if Task.isCancelled { return }
                    await performSearch()
                }
            }
            .sheet(isPresented: $showSafari) {
                if let u = safariURL { SafariView(url: u) }
            }
            .sheet(isPresented: $showEqualizer) {
                EqualizerSheet()
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .fullScreenCover(isPresented: $showListeningStats) {
                ListeningStatsView()
            }
            .fullScreenCover(isPresented: $showShazam) {
                ShazamView()
            }
        .fullScreenCover(isPresented: $showKaraoke) {
            if let song = trending.first {
                KaraokeModeView(track: PlaylistTrack(
                    id: String(song.id),
                    title: song.title,
                    artist: song.artist,
                    album: song.collectionName,
                    artworkURL: song.artworkUrl,
                    duration: 180,
                    addedAt: Date(),
                    addedBy: nil
                ))
            }
        }
            .sheet(isPresented: $showDownloads) {
                NavigationStack {
                    DownloadsView()
                }
            }
            .sheet(isPresented: $showLibrary) {
                MyLibraryView()
            }
            .sheet(isPresented: $showConcerts) {
                NavigationStack {
                    ConcertsView()
                }
            }
            .sheet(isPresented: $showMerch) {
                NavigationStack {
                    MerchStoreView()
                }
            }
            .sheet(isPresented: $showDiscover) {
                NavigationStack {
                    DiscoverView()
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    MusicSettingsView()
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                MusicUploadSheet()
            }
        }
    }
    
    // MARK: - Hero Section (Apple Music Light Style)
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred artwork background from first trending song
            if let artURL = trending.first?.artworkUrl, let url = URL(string: artURL) {
                AppAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .frame(height: 300)
                .clipped()
                .blur(radius: 40)
                .opacity(0.55)
            }
            
            // Gradient overlay: vibrant top → white/clear at bottom (Apple Music style)
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.85),
                    Color(red: 0.58, green: 0.08, blue: 0.38).opacity(0.75),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            
            // Subtle wave overlay
            GeometryReader { _ in
                ForEach(0..<4, id: \.self) { i in
                    MusicWavePath()
                        .stroke(Color.white.opacity(0.06 - Double(i) * 0.01), lineWidth: 1.5)
                        .offset(y: CGFloat(i) * 20)
                }
            }
            .frame(height: 300)
            
            // Content
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    PremiumBadge(icon: "airpodspro", text: "Spatial")
                    PremiumBadge(icon: "waveform", text: "Lossless")
                    PremiumBadge(icon: "music.note.tv", text: "Dolby Atmos")
                }
                .opacity(animateHero ? 1 : 0)
                .offset(y: animateHero ? 0 : 10)
                
                Text("MyChannel\nMusic")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 20)
                
                Text("100 million songs. Zero ads.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 15)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(height: 300)
        .clipped()
    }
    
    // MARK: - Quick Actions Row
    
    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickActionButton(icon: "arrow.up.circle.fill", title: "Upload") {
                    showUploadSheet = true
                    HapticManager.shared.impact(style: .medium)
                }
                QuickActionButton(icon: "shuffle", title: "Shuffle") {
                    if !trending.isEmpty {
                        let items: [PreviewQueueItem] = trending.shuffled().compactMap { s in
                            guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                            return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                        }
                        if !items.isEmpty { preview.queueAndPlay(items) }
                    }
                    HapticManager.shared.impact(style: .medium)
                }
                QuickActionButton(icon: "chart.bar.fill", title: "My Stats") {
                    showListeningStats = true
                    HapticManager.shared.impact(style: .medium)
                }
                QuickActionButton(icon: "clock.arrow.circlepath", title: "History") {
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "heart.fill", title: "Favorites") {
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "antenna.radiowaves.left.and.right", title: "Radio") {
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "music.mic", title: "Lyrics") {
                    showNowPlaying = true
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "waveform", title: "Shazam") {
                    showShazam = true
                    HapticManager.shared.impact(style: .medium)
                }
                QuickActionButton(icon: "arrow.down.circle.fill", title: "Downloads") {
                    showDownloads = true
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "music.note.list", title: "Library") {
                    showLibrary = true
                    HapticManager.shared.impact(style: .light)
                }
                QuickActionButton(icon: "ticket.fill", title: "Concerts") {
                    showConcerts = true
                    HapticManager.shared.impact(style: .light)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Artist Upload CTA Banner
    
    private var artistUploadCTA: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image(systemName: "music.mic")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Are you an artist?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text("Upload your music & get paid")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                showUploadSheet = true
                HapticManager.shared.impact(style: .medium)
            } label: {
                Text("Upload")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showArtistCTA = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - New Artist Drops Section
    
    private var newArtistDropsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "New Artist Drops",
                subtitle: "Fresh uploads from creators",
                icon: "music.note.list",
                iconColor: Color(red: 0.88, green: 0.15, blue: 0.25),
                showSeeAll: true
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(discoveryFeed.newDrops) { track in
                        ArtistTrackCard(track: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Trending on MyChannel Section
    
    private var trendingOnMyChannelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Trending on MyChannel",
                subtitle: "Most streamed creator tracks",
                icon: "flame.fill",
                iconColor: .orange,
                showSeeAll: true
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(discoveryFeed.trendingUploads) { track in
                        ArtistTrackCard(track: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Mood Filter Row
    
    private var moodFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MusicMood.allCases, id: \.self) { mood in
                    MoodChip(mood: mood, isSelected: selectedMood == mood) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if selectedMood == mood {
                                selectedMood = nil
                            } else {
                                selectedMood = mood
                            }
                        }
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - New Releases Section
    
    private var newReleasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(title: "New Releases", subtitle: "Fresh drops this week", showSeeAll: true)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(trending.prefix(8).enumerated()), id: \.element.id) { index, song in
                        NewReleaseCard(song: song, index: index + 1)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Spatial Audio Section
    
    private var spatialAudioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Spatial Audio",
                subtitle: "Immersive sound with Dolby Atmos",
                icon: "airpodspro",
                iconColor: .cyan,
                showSeeAll: true
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(trending.prefix(6), id: \.id) { song in
                        SpatialAudioCard(song: song)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Genre Browse Section
    
    private var genreBrowseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(title: "Browse by Genre", subtitle: nil, showSeeAll: false)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MusicGenre.allCases, id: \.self) { genre in
                    GenreCard(genre: genre) {
                        searchText = genre.searchTerm
                        Task { await performSearch() }
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Curated Playlists Section
    
    private var curatedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(title: "Playlists", subtitle: "Curated for you", showSeeAll: true)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(CuratedPlaylist.flintPlaylists, id: \.id) { playlist in
                        MusicPlaylistCard(playlist: playlist) {
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Radio Stations Section
    
    private var radioStationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Radio",
                subtitle: "Live stations",
                icon: "antenna.radiowaves.left.and.right",
                iconColor: .red,
                showSeeAll: false
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(RadioStation.flintStations, id: \.id) { station in
                        RadioStationCard(station: station) {
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Discover Section
    
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Made For You",
                subtitle: "AI-powered personalization",
                icon: "sparkles",
                iconColor: .purple,
                showSeeAll: true,
                seeAllAction: {
                    showDiscover = true
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    DiscoverMixCard(title: "Daily Mix", subtitle: "Your personalized playlist", colors: [.orange, .pink]) {
                        showDiscover = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    
                    DiscoverMixCard(title: "Discover Weekly", subtitle: "Fresh picks every Monday", colors: [.purple, .blue]) {
                        showDiscover = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    
                    DiscoverMixCard(title: "810 Mix", subtitle: "Flint's finest", colors: [.red, .orange]) {
                        showDiscover = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    
                    DiscoverMixCard(title: "Release Radar", subtitle: "New from artists you follow", colors: [.green, .teal]) {
                        showDiscover = true
                        HapticManager.shared.impact(style: .medium)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Friend Activity Section
    
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Friend Activity",
                subtitle: "What your friends are playing",
                icon: "person.2.fill",
                iconColor: .green,
                showSeeAll: true
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<5) { i in
                        FriendActivityCard(
                            name: ["Mike", "Sarah", "James", "Aisha", "Dre"][i],
                            track: ["Coochie", "Flint Flow", "Enbarassing", "Money Talk", "810 Anthem"][i],
                            artist: ["YN Jay", "Rio Da Yung OG", "RMC Mike", "Louie Ray", "Flint Legends"][i],
                            isPlaying: i < 2
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Concerts Preview Section
    
    private var concertsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Concerts Near You",
                subtitle: "Live events in the 810",
                icon: "ticket.fill",
                iconColor: .pink,
                showSeeAll: true,
                seeAllAction: {
                    showConcerts = true
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ConcertPreviewCard(
                        artist: "YN Jay",
                        venue: "The Machine Shop",
                        date: "Sat, Dec 28",
                        imageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg"
                    ) {
                        showConcerts = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    
                    ConcertPreviewCard(
                        artist: "Rio Da Yung OG",
                        venue: "Saint Andrew's Hall",
                        date: "Jan 4, 2025",
                        imageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg"
                    ) {
                        showConcerts = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    
                    ConcertPreviewCard(
                        artist: "RMC Mike",
                        venue: "The Fillmore",
                        date: "Jan 11, 2025",
                        imageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg"
                    ) {
                        showConcerts = true
                        HapticManager.shared.impact(style: .medium)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Behind the Music Section
    
    private var behindTheMusicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Behind the Music",
                subtitle: "Stories from the 810",
                icon: "play.rectangle.fill",
                iconColor: .red,
                showSeeAll: false
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    BehindTheMusicCard(
                        title: "The Making of Coochie",
                        artist: "YN Jay",
                        imageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
                        duration: "3:42"
                    )
                    
                    BehindTheMusicCard(
                        title: "From the Block to the Stage",
                        artist: "Rio Da Yung OG",
                        imageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg",
                        duration: "5:18"
                    )
                    
                    BehindTheMusicCard(
                        title: "The Flint Sound",
                        artist: "RMC Mike",
                        imageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg",
                        duration: "4:55"
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Charts",
                subtitle: "What's hot right now",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .orange,
                showSeeAll: true
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(MusicChart.allCharts, id: \.id) { chart in
                        ChartCard(chart: chart) {
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Recently Played Section
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicSectionHeader(
                title: "Recently Played",
                subtitle: nil,
                icon: "clock.arrow.circlepath",
                iconColor: .purple,
                showSeeAll: true
            )
            
            if trending.isEmpty {
                Text("Start listening to see your history")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(trending.prefix(8), id: \.id) { song in
                            RecentlyPlayedCard(song: song)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Music Background (kept for legacy, background now set inline)
    
    private var musicBackground: some View {
        Color(.systemGroupedBackground)
    }

    // MARK: - Back helper
    private func awaitBack() {
        // Dismiss if presented modally (as fullScreenCover from Home)
        NotificationCenter.default.post(name: Notification.Name("DismissMusicHub"), object: nil)
    }
    
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search songs, artists", text: $searchText)
                    .onSubmit { Task { await performSearch() } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface))
            if !recentQueries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentQueries.reversed().prefix(8), id: \.self) { q in
                            Button {
                                searchText = q
                                Task { await performSearch() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock").font(.system(size: 12))
                                    Text(q)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.Colors.surface)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            recentQueries.removeAll()
                            UserDefaults.standard.set(recentQueries, forKey: recentKey)
                        } label: {
                            Text("Clear")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var subscriptionCTA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MyChannel Music")
                .font(.system(size: 22, weight: .bold))
            Text("Unlimited music from top artists and your city. Try free, then $9.99/month.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button {
                    // Present StoreKit paywall
                    UIApplication.shared.sendAction(#selector(AppActions.presentMusicPaywall), to: nil, from: nil, for: nil)
                } label: {
                    Text("Start Free Trial")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(8)
                }
                Button {
                    // TODO: open terms / pricing
                } label: {
                    Text("Learn More")
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var segmentControl: some View {
        Picker("", selection: $segment) {
            ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trending")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if !trending.isEmpty {
                    Button("Preview All") {
                        let items: [PreviewQueueItem] = trending.compactMap { s in
                            guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                            return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                        }
                        if !items.isEmpty {
                            preview.queueAndPlay(items)
                            HapticManager.shared.selection()
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(trending, id: \.id) { s in
                        MusicCard(song: s)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("For You")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(forYou, id: \.id) { s in
                        MusicCard(song: s)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity(forYou.isEmpty ? 0 : 1)
        .animation(.easeInOut(duration: 0.25), value: forYou.isEmpty)
    }

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Artists").font(.system(size: 20, weight: .bold)); Spacer() }
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(artists, id: \.id) { a in
                        VStack(spacing: 8) {
                            AsyncImage(url: URL(string: a.artworkUrl ?? "")) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Circle().fill(Color(.systemGray6)) }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            Text(a.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).frame(width: 120)
                            HStack(spacing: 8) {
                                Button("Preview All") {
                                    Task {
                                        if let tracks = try? await MusicCatalogService.shared.topTracksForArtist(artistId: a.id, limit: 10) {
                                            let items: [PreviewQueueItem] = tracks.compactMap { s in
                                                guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                                                return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                                            }
                                            if !items.isEmpty { AudioPreviewPlayer.shared.queueAndPlay(items); HapticManager.shared.selection() }
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                if let link = a.linkUrl, let u = URL(string: link) {
                                    Button("Open") { safariURL = u; showSafari = true; HapticManager.shared.selection() }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Albums").font(.system(size: 20, weight: .bold)); Spacer() }
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(albums, id: \.id) { al in
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: URL(string: al.artworkUrl ?? "")) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)) }
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(al.title).font(.system(size: 13, weight: .semibold)).lineLimit(2).frame(width: 140, alignment: .leading)
                            Text(al.artist).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                            HStack(spacing: 8) {
                                Button("Preview All") {
                                    Task {
                                        if let tracks = try? await MusicCatalogService.shared.topTracksForAlbum(collectionId: al.id) {
                                            let items: [PreviewQueueItem] = tracks.compactMap { s in
                                                guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                                                return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                                            }
                                            if !items.isEmpty { AudioPreviewPlayer.shared.queueAndPlay(items); HapticManager.shared.selection() }
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                if let link = al.viewUrl, let u = URL(string: link) {
                                    Button("Open") { safariURL = u; showSafari = true; HapticManager.shared.selection() }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }

    private var localSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localTitle)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if !local.isEmpty {
                    Button("Preview All") {
                        let items: [PreviewQueueItem] = local.compactMap { s in
                            guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                            return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                        }
                        if !items.isEmpty {
                            preview.queueAndPlay(items)
                            HapticManager.shared.selection()
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            
            if local.isEmpty {
                Text("No local artists yet. Explore trending while we learn your taste.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(local, id: \.id) { s in
                            MusicCard(song: s)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var localTitle: String {
        if let city = appState.currentUser?.location, !city.isEmpty { return "Local • \(city)" }
        return "Local Artists"
    }
    
    private func load() async {
        loading = true
        
        async let curatedSongsTask = MusicCatalogService.shared.curatedSpotlightSongs()
        async let curatedArtistsTask = MusicCatalogService.shared.curatedArtists()
        async let curatedAlbumsTask = MusicCatalogService.shared.curatedAlbums()
        
        let top = (try? await MusicCatalogService.shared.topSongs(limit: 40)) ?? []
        let curatedSongs = await curatedSongsTask
        let editorialArtists = await curatedArtistsTask
        let editorialAlbums = await curatedAlbumsTask
        
        if !top.isEmpty { trending = top }
        if !editorialArtists.isEmpty { artists = editorialArtists }
        if !editorialAlbums.isEmpty { albums = editorialAlbums }
        
        let city = appState.currentUser?.location ?? ""
        if !city.isEmpty, let loc = try? await MusicCatalogService.shared.searchSongs(term: city, limit: 30) {
            local = loc
        }
        if local.isEmpty {
            let fallback = !curatedSongs.isEmpty ? curatedSongs : top
            local = Array(fallback.prefix(8))
        }
        
        await loadForYou(curatedFallback: !curatedSongs.isEmpty ? curatedSongs : top)
        loading = false
    }
    
    private func performSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        if let res = try? await MusicCatalogService.shared.searchSongs(term: term, limit: 40) { trending = res }
        if let ars = try? await MusicCatalogService.shared.searchArtists(term: term, limit: 30), !ars.isEmpty {
            artists = ars
        } else if artists.isEmpty {
            let curated = await MusicCatalogService.shared.curatedArtists()
            if !curated.isEmpty { artists = curated }
        }
        if let als = try? await MusicCatalogService.shared.searchAlbums(term: term, limit: 30), !als.isEmpty {
            albums = als
        } else if albums.isEmpty {
            let curated = await MusicCatalogService.shared.curatedAlbums()
            if !curated.isEmpty { albums = curated }
        }
        if !term.isEmpty { saveRecentQuery(term) }
    }

    private func loadForYou(curatedFallback: [CatalogSong]) async {
        var seeds: [String] = []
        if let city = appState.currentUser?.location, !city.isEmpty { seeds.append(city) }
        seeds.append(contentsOf: recentQueries.suffix(3))
        let term = seeds.joined(separator: " ")
        guard !term.isEmpty else {
            if !curatedFallback.isEmpty {
                forYou = Array(curatedFallback.prefix(12))
            } else {
                forYou = Array(trending.prefix(12))
            }
            return
        }
        if let res = try? await MusicCatalogService.shared.searchSongs(term: term, limit: 20) {
            if res.isEmpty {
                forYou = !curatedFallback.isEmpty ? Array(curatedFallback.prefix(12)) : Array(trending.prefix(12))
            } else {
                forYou = res
            }
        } else {
            forYou = !curatedFallback.isEmpty ? Array(curatedFallback.prefix(12)) : Array(trending.prefix(12))
        }
    }

    // MARK: - Recent queries persistence
    private let recentKey = "music_recent_queries"
    private func loadRecentQueries() {
        if let data = UserDefaults.standard.array(forKey: recentKey) as? [String] {
            recentQueries = data
        }
    }
    private func saveRecentQuery(_ q: String) {
        var arr = recentQueries
        if let i = arr.firstIndex(of: q) { arr.remove(at: i) }
        arr.append(q)
        recentQueries = Array(arr.suffix(20))
        UserDefaults.standard.set(recentQueries, forKey: recentKey)
    }
}

private struct MusicCard: View {
    let song: CatalogSong
    var onOpenURL: (URL) -> Void = { url in
        DeepLinkService.shared.handle(url: url)
    }
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))
                    .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(song.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            
            HStack(spacing: 8) {
            if let urlString = song.trackViewUrl, let url = URL(string: urlString) {
                    Button {
                        onOpenURL(url)
                        HapticManager.shared.selection()
                    } label: {
                        Text("Buy")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    UIApplication.shared.sendAction(#selector(AppActions.presentMusicPaywall), to: nil, from: nil, for: nil)
                HapticManager.shared.selection()
                } label: {
                    Text("Listen")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.primary.opacity(0.12))
                        .cornerRadius(6)
                }
                if let p = song.previewUrl, let u = URL(string: p) {
                    Button {
                        let id = String(song.id)
                        if preview.currentTrackId == id && preview.isPlaying {
                            preview.pause()
                        } else {
                            preview.play(url: u, trackId: id, title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                        }
                    HapticManager.shared.selection()
                    } label: {
                        Image(systemName: preview.currentTrackId == String(song.id) && preview.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                    }
                }
            }
            if preview.currentTrackId == String(song.id) {
                ProgressView(value: preview.progress)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.Colors.primary)
                    .frame(width: 140)
            }
        }
    }
}

// Local NowPlayingBar removed; using GlobalNowPlayingBar

// MARK: - 🔥 PREMIUM UI COMPONENTS 🔥

// MARK: - Music Mood
enum MusicMood: String, CaseIterable {
    case chill = "Chill"
    case hype = "Hype"
    case focus = "Focus"
    case workout = "Workout"
    case party = "Party"
    case sad = "Sad"
    case happy = "Happy"
    case romantic = "Romantic"
    
    var icon: String {
        switch self {
        case .chill: return "leaf.fill"
        case .hype: return "flame.fill"
        case .focus: return "brain.head.profile"
        case .workout: return "figure.run"
        case .party: return "sparkles"
        case .sad: return "cloud.rain.fill"
        case .happy: return "sun.max.fill"
        case .romantic: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .chill: return .mint
        case .hype: return .orange
        case .focus: return .purple
        case .workout: return .red
        case .party: return .pink
        case .sad: return .blue
        case .happy: return .yellow
        case .romantic: return .red
        }
    }
}

// MARK: - Music Genre
enum MusicGenre: String, CaseIterable {
    case hiphop = "Hip-Hop"
    case rnb = "R&B"
    case pop = "Pop"
    case rock = "Rock"
    case electronic = "Electronic"
    case jazz = "Jazz"
    case country = "Country"
    case gospel = "Gospel"
    
    var searchTerm: String { rawValue }
    
    var color: LinearGradient {
        switch self {
        case .hiphop: return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rnb: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pop: return LinearGradient(colors: [.pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rock: return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .electronic: return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .jazz: return LinearGradient(colors: [.brown, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .country: return LinearGradient(colors: [.yellow, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gospel: return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var icon: String {
        switch self {
        case .hiphop: return "music.mic"
        case .rnb: return "heart.fill"
        case .pop: return "star.fill"
        case .rock: return "guitars.fill"
        case .electronic: return "waveform"
        case .jazz: return "music.quarternote.3"
        case .country: return "music.note"
        case .gospel: return "hands.clap.fill"
        }
    }
}

// MARK: - Premium Badge
struct PremiumBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}

// MARK: - Quick Action Button (Apple Music Light Style)
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Mood Chip
struct MoodChip: View {
    let mood: MusicMood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mood.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(mood.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? mood.color : Color(.systemGray5))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Music Section Header
struct MusicSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .primary
    var showSeeAll: Bool = false
    var seeAllAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if showSeeAll {
                Button {
                    seeAllAction?()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - New Release Card
struct NewReleaseCard: View {
    let song: CatalogSong
    let index: Int
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                // Album art
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // Rank badge
                Text("#\(index)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .padding(10)
                
                // NEW badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.yellow)
                            )
                            .padding(10)
                    }
                }
                .frame(width: 180, height: 180)
                
                // Play overlay on hover
                if isHovered {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.4))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        )
                }
            }
            .onTapGesture {
                if let p = song.previewUrl, let u = URL(string: p) {
                    preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                }
                HapticManager.shared.impact(style: .medium)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
                
                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Spatial Audio Card
struct SpatialAudioCard: View {
    let song: CatalogSong
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Spatial Audio badge
                HStack(spacing: 4) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Spatial")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.cyan.opacity(0.9))
                )
                .padding(8)
            }
            .onTapGesture {
                if let p = song.previewUrl, let u = URL(string: p) {
                    preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                }
                HapticManager.shared.impact(style: .medium)
            }
            
            Text(song.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            Text(song.artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Genre Card
struct GenreCard: View {
    let genre: MusicGenre
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: genre.icon)
                        .font(.system(size: 22, weight: .semibold))
                    Text(genre.rawValue)
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(16)
            .frame(height: 80)
            .background(genre.color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Music Wave Path (Animated Background)
struct MusicWavePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        // Create smooth wave
        for x in stride(from: 0, through: width, by: 5) {
            let relativeX = x / width
            let y = midY + sin(relativeX * .pi * 4) * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// ScaleButtonStyle moved to Core/Components/ButtonStyles.swift

// MARK: - Curated Playlist Model
struct CuratedPlaylist: Identifiable {
    let id: String
    let name: String
    let description: String
    let imageColors: [Color]
    let icon: String
    let songCount: Int
    
    static let flintPlaylists: [CuratedPlaylist] = [
        CuratedPlaylist(
            id: "810-essentials",
            name: "810 Essentials",
            description: "The best of Flint",
            imageColors: [.orange, .red],
            icon: "flame.fill",
            songCount: 50
        ),
        CuratedPlaylist(
            id: "flint-heat",
            name: "Flint Heat",
            description: "Hottest tracks right now",
            imageColors: [.red, .pink],
            icon: "waveform.path",
            songCount: 30
        ),
        CuratedPlaylist(
            id: "810-classics",
            name: "810 Classics",
            description: "MC Breed, Dayton Family & more",
            imageColors: [.purple, .blue],
            icon: "crown.fill",
            songCount: 40
        ),
        CuratedPlaylist(
            id: "michigan-rap",
            name: "Michigan Rap",
            description: "The whole state goes hard",
            imageColors: [.blue, .cyan],
            icon: "music.mic",
            songCount: 75
        ),
        CuratedPlaylist(
            id: "new-810",
            name: "New 810",
            description: "Fresh releases from Flint",
            imageColors: [.green, .mint],
            icon: "sparkles",
            songCount: 25
        ),
        CuratedPlaylist(
            id: "street-certified",
            name: "Street Certified",
            description: "Real street music",
            imageColors: [.gray, .black],
            icon: "bolt.fill",
            songCount: 45
        )
    ]
}

// MARK: - Music Playlist Card
struct MusicPlaylistCard: View {
    let playlist: CuratedPlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Playlist artwork
                ZStack {
                    LinearGradient(
                        colors: playlist.imageColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: playlist.icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: playlist.imageColors.first?.opacity(0.4) ?? .clear, radius: 10, x: 0, y: 5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(playlist.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Radio Station Model
struct RadioStation: Identifiable {
    let id: String
    let name: String
    let description: String
    let color: Color
    let isLive: Bool
    
    static let flintStations: [RadioStation] = [
        RadioStation(id: "810-radio", name: "810 Radio", description: "Flint's #1 station", color: .orange, isLive: true),
        RadioStation(id: "flint-underground", name: "Flint Underground", description: "Independent artists", color: .purple, isLive: true),
        RadioStation(id: "michigan-hits", name: "Michigan Hits", description: "State-wide bangers", color: .blue, isLive: true),
        RadioStation(id: "throwback-810", name: "Throwback 810", description: "Classic Flint hip-hop", color: .red, isLive: false),
        RadioStation(id: "rnb-soul", name: "R&B Soul", description: "Smooth vibes", color: .pink, isLive: true)
    ]
}

// MARK: - Radio Station Card
struct RadioStationCard: View {
    let station: RadioStation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    // Station icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [station.color, station.color.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    
                    // Live indicator
                    if station.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .offset(x: -5, y: 5)
                    }
                }
                
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Text(station.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 100)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Music Chart Model
struct MusicChart: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let updateFrequency: String
    
    static let allCharts: [MusicChart] = [
        MusicChart(id: "top-50-flint", name: "Top 50: Flint", icon: "trophy.fill", color: .orange, updateFrequency: "Updated daily"),
        MusicChart(id: "top-100-usa", name: "Top 100: USA", icon: "flag.fill", color: .blue, updateFrequency: "Updated daily"),
        MusicChart(id: "viral-50", name: "Viral 50", icon: "flame.fill", color: .red, updateFrequency: "Updated daily"),
        MusicChart(id: "hip-hop-charts", name: "Hip-Hop Charts", icon: "music.mic", color: .purple, updateFrequency: "Updated weekly"),
        MusicChart(id: "new-releases", name: "New Releases", icon: "sparkles", color: .green, updateFrequency: "Updated Friday")
    ]
}

// MARK: - Chart Card
struct ChartCard: View {
    let chart: MusicChart
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chart icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [chart.color, chart.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: chart.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chart.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(chart.updateFrequency)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .frame(width: 260)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recently Played Card
struct RecentlyPlayedCard: View {
    let song: CatalogSong
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Play button overlay
                Button {
                    if let p = song.previewUrl, let u = URL(string: p) {
                        preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                    }
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    Image(systemName: preview.currentTrackId == String(song.id) && preview.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                .padding(6)
            }
            
            Text(song.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
            
            Text(song.artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
        }
    }
}

// MARK: - Equalizer Sheet
struct EqualizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: String = "Flat"
    @State private var eqBands: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    let presets = ["Flat", "Rock", "Pop", "Jazz", "Classical", "Hip-Hop", "R&B", "Electronic", "Bass Boost", "Treble Boost"]
    let frequencies = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preset selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                selectedPreset = preset
                                applyPreset(preset)
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Text(preset)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedPreset == preset ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedPreset == preset ? AppTheme.Colors.primary : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // EQ Sliders
                HStack(spacing: 0) {
                    ForEach(Array(frequencies.enumerated()), id: \.offset) { index, freq in
                        VStack(spacing: 8) {
                            // Value
                            Text(String(format: "%.0f", eqBands[index]))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Slider (vertical)
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    // Track
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 8)
                                    
                                    // Fill
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.6)],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(width: 8, height: max(0, (eqBands[index] + 12) / 24 * geo.size.height))
                                }
                                .frame(maxWidth: .infinity)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let ratio = 1 - (value.location.y / geo.size.height)
                                            let clamped = min(max(ratio, 0), 1)
                                            eqBands[index] = (clamped * 24) - 12
                                        }
                                )
                            }
                            .frame(height: 150)
                            
                            // Frequency label
                            Text(freq)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                
                // Bass/Treble quick controls
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("BASS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { (eqBands[0] + eqBands[1] + eqBands[2]) / 3 + 12 },
                            set: { newValue in
                                let adjusted = newValue - 12
                                eqBands[0] = adjusted
                                eqBands[1] = adjusted * 0.8
                                eqBands[2] = adjusted * 0.6
                            }
                        ), in: 0...24)
                        .tint(AppTheme.Colors.primary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("TREBLE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { (eqBands[7] + eqBands[8] + eqBands[9]) / 3 + 12 },
                            set: { newValue in
                                let adjusted = newValue - 12
                                eqBands[7] = adjusted * 0.6
                                eqBands[8] = adjusted * 0.8
                                eqBands[9] = adjusted
                            }
                        ), in: 0...24)
                        .tint(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(Color(.systemBackground))
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
    
    private func applyPreset(_ preset: String) {
        switch preset {
        case "Flat": eqBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case "Rock": eqBands = [4, 3, -1, -2, 1, 2, 4, 5, 5, 4]
        case "Pop": eqBands = [-1, 2, 4, 4, 1, -1, -2, -2, -1, -1]
        case "Jazz": eqBands = [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]
        case "Classical": eqBands = [4, 3, 2, 1, -1, -2, -1, 2, 3, 4]
        case "Hip-Hop": eqBands = [6, 5, 2, 1, -1, -1, 1, 2, 3, 4]
        case "R&B": eqBands = [4, 4, 2, 1, 0, 1, 2, 3, 3, 2]
        case "Electronic": eqBands = [3, 2, 0, -1, 1, 0, 1, 3, 4, 4]
        case "Bass Boost": eqBands = [8, 6, 4, 2, 0, -1, -2, -3, -3, -3]
        case "Treble Boost": eqBands = [-3, -3, -2, -1, 0, 1, 3, 5, 7, 8]
        default: eqBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
}

// MARK: - Discover Mix Card

struct DiscoverMixCard: View {
    let title: String
    let subtitle: String
    let colors: [Color]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Friend Activity Card

struct FriendActivityCard: View {
    let name: String
    let track: String
    let artist: String
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(name.prefix(1)))
                            .font(.system(size: 24, weight: .semibold))
                    )
                
                if isPlaying {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                
                if isPlaying {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                        Text(track)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(track)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 80)
    }
}

// MARK: - Concert Preview Card

struct ConcertPreviewCard: View {
    let artist: String
    let venue: String
    let date: String
    let imageURL: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    AppAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(width: 200, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Date badge
                    Text(date)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist)
                        .font(.system(size: 14, weight: .semibold))
                    Text(venue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Behind the Music Card

struct BehindTheMusicCard: View {
    let title: String
    let artist: String
    let imageURL: String
    let duration: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    AppAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Play overlay
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
                
                // Duration badge
                Text(duration)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.7)))
                    .padding(8)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            
            Text(artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: 180)
    }
}

