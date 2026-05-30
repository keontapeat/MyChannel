import SwiftUI
import Combine

// MARK: - 🔥 MYCHANNEL MUSIC HUB - Custom Design 🔥

struct MusicHubView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var featuredService = FeaturedArtistService.shared
    @State private var trending: [CatalogSong] = []
    @State private var local: [CatalogSong] = []
    @State private var forYou: [CatalogSong] = []
    @State private var artists: [CatalogArtist] = []
    @State private var albums: [CatalogAlbum] = []
    @State private var quickPicks: [CatalogSong] = []
    @State private var topArtists: [CatalogArtist] = []
    @State private var topAlbums: [CatalogAlbum] = []
    /// Newest friend tracks first (from iTunes `releaseDate`); fallback to hub pool.
    @State private var newReleaseSongs: [CatalogSong] = []
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
    @State private var showArtistDashboard: Bool = false
    @StateObject private var discoveryFeed = MusicDiscoveryFeedService.shared
    
    enum Segment: String, CaseIterable { case songs = "Songs", artists = "Artists", albums = "Albums" }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background — clean white
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Welcome Header
                        welcomeHeader
                        
                        VStack(spacing: 32) {
                            // Pinned Artists
                            discoverArtistsSection
                            
                            // On Repeat
                            onRepeatSection
                            
                            // Top Charts
                            topChartsSection
                            
                            // Top Artists
                            topArtistsSection
                            
                            // Top Songs
                            topSongsSection
                            
                            // Top Albums
                            topAlbumsSection
                            
                            // New Releases
                            newReleasesListSection
                            
                            // Bottom padding for now playing bar
                            Spacer().frame(height: 100)
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        awaitBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Music")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showEqualizer = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        Button {
                            showSettings = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
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
            .onDisappear {
                AudioPreviewPlayer.shared.stop()
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
            .navigationDestination(isPresented: $showArtistDashboard) {
                ArtistDashboardView()
            }
        }
    }
    
    // MARK: - MyChannel Music Logo
    
    private var myChannelMusicBanner: some View {
        HStack {
            Image("MyChannelMusicLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 36)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Welcome Header (Clean — No Gradient)
    
    private var welcomeHeader: some View {
        HStack(spacing: 12) {
            // Profile avatar
            if let photoURL = appState.currentUser?.profileImageURL,
               let url = URL(string: photoURL) {
                AppAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                    )
                    .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(appState.currentUser?.displayName ?? "Music Lover")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    showArtistDashboard = true
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        )
                }
                
                Button {
                    showDiscover = true
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .opacity(animateHero ? 1 : 0)
        .offset(y: animateHero ? 0 : 8)
    }
    
    @State private var newReleasesPage: Int = 0
    
    // MARK: - New Releases List (Numbered Rows)
    
    private var newReleasesListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Releases")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
            
            if trending.isEmpty && loading && newReleaseSongs.isEmpty {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                let songs = newReleaseSongs.isEmpty ? Array(trending.prefix(100)) : newReleaseSongs
                let pages = stride(from: 0, to: songs.count, by: 5).map { i in
                    Array(songs[i..<min(i + 5, songs.count)])
                }
                
                TabView(selection: $newReleasesPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageSongs in
                        ShelfCarouselPage(
                            songs: pageSongs,
                            startIndex: pageIndex * 5,
                            showFlame: false
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: CGFloat(5 * 72 + 20))
            }
        }
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
                    .fill(AppTheme.Colors.premiumGradient)
                    .frame(width: 48, height: 48)
                Image(systemName: "music.mic")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Are you an artist?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Upload your music & get paid")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
                    .background(AppTheme.Colors.premiumGradient)
                    .clipShape(Capsule())
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showArtistCTA = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
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
    
    // MARK: - Discover Artists Section
    
    private var discoverArtistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text("Pinned Artists")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    // Show current user's profile picture first
                    if let currentUser = appState.currentUser {
                        NavigationLink(destination: ArtistProfileView(artist: CatalogArtist(id: currentUser.id.hashValue, name: currentUser.displayName, linkUrl: nil, artworkUrl: currentUser.profileImageURL))) {
                            DiscoverArtistCircleCard(artist: CatalogArtist(id: currentUser.id.hashValue, name: currentUser.displayName, linkUrl: nil, artworkUrl: currentUser.profileImageURL))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ForEach(artists, id: \.id) { artist in
                        NavigationLink(destination: ArtistProfileView(artist: artist)) {
                            DiscoverArtistCircleCard(artist: artist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    @State private var onRepeatPage: Int = 0
    
    // MARK: - Top Charts Section
    
    @State private var topCharts: [CatalogSong] = []
    
    private var topChartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                Text("Top Charts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            
            if topCharts.isEmpty && loading {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(topCharts.prefix(100).enumerated()), id: \.offset) { index, song in
                            NavigationLink(destination: ArtistProfileView(artist: catalogArtistForChartSong(song))) {
                                TopChartSquareCard(song: song, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - On Repeat Section (10 slots — songs from Pinned Artists / friend IDs in MusicCatalogService)
    
    private var onRepeatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                    Text("On Repeat")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    let items: [PreviewQueueItem] = quickPicks.compactMap { s in
                        guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                        return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: URL(string: s.artworkUrl ?? ""))
                    }
                    if !items.isEmpty { AudioPreviewPlayer.shared.queueAndPlay(items) }
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    Text("Play all")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
            
            if quickPicks.isEmpty && loading {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                let pages = stride(from: 0, to: quickPicks.count, by: 5).map { i in
                    Array(quickPicks[i..<min(i + 5, quickPicks.count)])
                }
                
                TabView(selection: $onRepeatPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageSongs in
                        ShelfCarouselPage(
                            songs: pageSongs,
                            startIndex: pageIndex * 5,
                            showFlame: false
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: CGFloat(min(quickPicks.count, 5) * 72 + 20))
            }
        }
    }
    
    // MARK: - Top Artists Section
    
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("Top Artists")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            
            if topArtists.isEmpty && loading {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(topArtists.prefix(100).enumerated()), id: \.element.id) { index, artist in
                            NavigationLink(destination: ArtistProfileView(artist: artist)) {
                                TopArtistSquareCard(artist: artist, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    @State private var topSongsPage: Int = 0
    
    // MARK: - Top Songs Section
    
    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("Top Songs")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            
            if trending.isEmpty && loading {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                let cap = min(trending.count, 100)
                let pages = stride(from: 0, to: cap, by: 5).map { i in
                    Array(trending[i..<min(i + 5, cap)])
                }
                
                TabView(selection: $topSongsPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageSongs in
                        ShelfCarouselPage(
                            songs: pageSongs,
                            startIndex: pageIndex * 5,
                            showFlame: true
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: CGFloat(5 * 72 + 20))
            }
        }
    }
    
    // MARK: - Top Albums Section
    
    private var topAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                Text("Top Albums")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            
            if topAlbums.isEmpty && loading {
                ProgressView().tint(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(topAlbums.prefix(100)) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AppAsyncImage(url: URL(string: album.artworkUrl ?? "")) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                            .overlay(
                                                Image(systemName: "music.note.list")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.gray.opacity(0.4))
                                            )
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(album.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 90, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
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
                    ForEach(RadioStation.featuredStations, id: \.id) { station in
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
                    
                    DiscoverMixCard(title: "810 Mix", subtitle: "The best 810 hits", colors: [.red, .orange]) {
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
                            track: ["Coochie", "Street Vibes", "Enbarassing", "Money Talk", "810 Anthem"][i],
                            artist: ["YN Jay", "Rio Da Yung OG", "RMC Mike", "Louie Ray", "810 Legends"][i],
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
                        title: "The 810 Sound",
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
    
    /// iTunes artist id for navigation — never use track `id` as artist id.
    private func catalogArtistForChartSong(_ song: CatalogSong) -> CatalogArtist {
        let aid = song.artistId
            ?? FeaturedFriendArtist.friends.first { $0.name.caseInsensitiveCompare(song.artist) == .orderedSame }?.appleMusicId
            ?? 0
        return CatalogArtist(id: aid, name: song.artist, linkUrl: nil, artworkUrl: song.artworkUrl)
    }
    
    private func load() async {
        loading = true
        
        let instantFriendArtists = FeaturedFriendArtist.friends.map { $0.catalogArtist }
        artists = instantFriendArtists
        topArtists = instantFriendArtists.shuffled()
        
        Task {
            async let hubTask = MusicCatalogService.shared.loadFriendHubMusic()
            async let onRepeatTask = MusicCatalogService.shared.songsForOnRepeatPinnedFriends()
            let hub = await hubTask
            let onRepeatSongs = await onRepeatTask
            let editedSongs = await MusicCatalogService.shared.applyMusicHubTopSongsEdits(hub.songs)
            await MainActor.run {
                if !editedSongs.isEmpty {
                    trending = editedSongs
                    topCharts = Array(editedSongs.prefix(100))
                }
                if !hub.albums.isEmpty {
                    topAlbums = hub.albums
                    albums = hub.albums
                }
                let newestFiltered = Array(hub.songsNewestFirst.prefix(100)).filter {
                    $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "trump"
                }
                newReleaseSongs = newestFiltered.isEmpty ? Array(editedSongs.prefix(100)) : newestFiltered
                if !onRepeatSongs.isEmpty { quickPicks = onRepeatSongs }
                loading = false
            }
        }
        
        // Phase 4: Refresh friend artist artwork in background (non-blocking)
        Task {
            let freshFriendArtists: [CatalogArtist] = await withTaskGroup(of: CatalogArtist.self) { group in
                for friend in FeaturedFriendArtist.friends {
                    group.addTask {
                        if let freshUrl = await MusicCatalogService.shared.freshArtworkURL(forArtistId: friend.appleMusicId),
                           !freshUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return CatalogArtist(id: friend.appleMusicId, name: friend.name, linkUrl: friend.catalogArtist.linkUrl, artworkUrl: freshUrl)
                        }
                        return friend.catalogArtist
                    }
                }
                var results: [CatalogArtist] = []
                for await artist in group { results.append(artist) }
                return FeaturedFriendArtist.friends.compactMap { friend in
                    results.first { $0.id == friend.appleMusicId }
                }
            }
            await MainActor.run {
                let freshIds = Set(freshFriendArtists.map { $0.id })
                let filtered = artists.filter { !freshIds.contains($0.id) }
                artists = freshFriendArtists + filtered
                topArtists = freshFriendArtists.shuffled()
            }
        }
        
        // Phase 5: Local + For You (non-blocking; fall back to friend hub pool)
        Task {
            let city = appState.currentUser?.location ?? ""
            if !city.isEmpty, let loc = try? await MusicCatalogService.shared.searchSongs(term: city, limit: 30) {
                await MainActor.run { local = loc }
            }
            await MainActor.run {
                if local.isEmpty {
                    local = Array(trending.prefix(8))
                }
            }
            await loadForYou(curatedFallback: Array(trending.prefix(12)))
        }
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

// ⚡ MusicCard + premium UI components extracted to MusicHubComponents.swift
