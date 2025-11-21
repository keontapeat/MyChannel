import SwiftUI
import Combine

struct MusicHubView: View {
    @EnvironmentObject var appState: AppState
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
    enum Segment: String, CaseIterable { case songs = "Songs", artists = "Artists", albums = "Albums" }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        searchBar
                        subscriptionCTA
                        segmentControl
                        forYouSection
                        if segment == .songs { trendingSection }
                        if segment == .artists { artistsSection }
                        if segment == .albums { albumsSection }
                        localSection
                    }
                    .padding(.vertical, 16)
                }
                // Global Now Playing Bar is injected via MainTabView; no local bar here
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Music")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { try? awaitBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .task { await load() }
            .onAppear { loadRecentQueries() }
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
        }
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


