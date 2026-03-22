//
//  MusicHomeView.swift
//  MyChannel
//
//  Premium MyChannel Music hub shown when tapping "See all" on Home.
//

import SwiftUI

struct MusicHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    @StateObject private var catalog = MusicCatalogService.shared
    @StateObject private var featuredService = FeaturedArtistService.shared
    @StateObject private var playlistService = PlaylistService.shared

    @State private var showSearch = false
    @State private var showLibrary = false
    @State private var trendingSongs: [CatalogSong] = []
    @State private var newReleaseAlbums: [CatalogAlbum] = []
    @State private var featuredArtists: [CatalogArtist] = []
    @State private var isLoadingTrending = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroHeader
                    topArtistsSection
                    trendingNowSection
                    newReleasesSection
                    localArtistsSection
                    genresSection
                    curatedPlaylistsSection
                }
                .padding(.vertical, 16)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("MyChannel Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }

                        Button {
                            HapticManager.shared.impact(style: .light)
                            showLibrary = true
                        } label: {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                NavigationStack {
                    MusicSearchView()
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showLibrary) {
                NavigationStack {
                    UserLibraryView()
                        .environmentObject(appState)
                }
            }
            .task {
                await loadContent()
            }
        }
    }

    // MARK: - Load

    private func loadContent() async {
        async let songs = catalog.curatedSpotlightSongs()
        async let albums = catalog.curatedAlbums()
        async let artists = catalog.curatedArtists()
        await featuredService.fetchArtists()
        let (s, a, ar) = await (songs, albums, artists)
        trendingSongs = s
        newReleaseAlbums = a
        featuredArtists = ar
        isLoadingTrending = false
    }

    // MARK: - Sections

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppTheme.Colors.primary, AppTheme.Colors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("Made for you")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text("Daily Mix • Detroit & Flint")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Button {
                    HapticManager.shared.impact(style: .medium)
                    if let first = trendingSongs.first {
                        let song = Song(
                            id: "\(first.id)",
                            title: first.title,
                            artistIds: [first.artist],
                            primaryArtistId: first.artist,
                            duration: 30,
                            artworkURL: URL(string: first.artworkUrl ?? ""),
                            streamURL: URL(string: first.previewUrl ?? "")
                        )
                        musicPlayer.play(song: song, inQueue: trendingSongs.prefix(10).map {
                            Song(id: "\($0.id)", title: $0.title, artistIds: [$0.artist],
                                 primaryArtistId: $0.artist, duration: 30,
                                 artworkURL: URL(string: $0.artworkUrl ?? ""),
                                 streamURL: URL(string: $0.previewUrl ?? ""))
                        })
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Play")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
    }

    private var topArtistsSection: some View {
        let artists = featuredService.featuredArtists.isEmpty ? [] : featuredService.featuredArtists
        return MusicHorizontalSection(title: "Top Artists", subtitle: "Michigan artists on the rise") {
            ForEach(artists) { artist in
                NavigationLink {
                    ArtistPageView(
                        artist: Artist(
                            id: artist.id,
                            name: artist.displayName,
                            slug: artist.displayName.lowercased().replacingOccurrences(of: " ", with: "-"),
                            bio: artist.bio,
                            avatarURL: URL(string: artist.profileImageURL ?? ""),
                            monthlyListeners: artist.monthlyListeners
                        ),
                        topSongs: [],
                        albums: [],
                        singles: [],
                        similarArtists: []
                    )
                } label: {
                    VStack(alignment: .center, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            AppAsyncImage(url: URL(string: artist.profileImageURL ?? "")) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.Colors.primary, lineWidth: 2))

                            if artist.verificationBadge != .none {
                                Image(systemName: artist.verificationBadge.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(artist.verificationBadge.color)
                                    .background(Circle().fill(AppTheme.Colors.background).padding(-2))
                            }
                        }

                        Text(artist.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                            .frame(width: 90)

                        Text(artist.genres.first ?? "Hip-Hop")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 94)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trendingNowSection: some View {
        MusicHorizontalSection(title: "Trending Now", subtitle: "What MyChannel is playing on repeat") {
            if isLoadingTrending {
                ForEach(0..<8, id: \.self) { i in
                    MusicSongRowTile(rank: i + 1, song: nil)
                }
            } else {
                ForEach(Array(trendingSongs.prefix(15).enumerated()), id: \.offset) { idx, song in
                    Button {
                        HapticManager.shared.impact(style: .light)
                        let s = Song(id: "\(song.id)", title: song.title, artistIds: [song.artist],
                                     primaryArtistId: song.artist, duration: 30,
                                     artworkURL: URL(string: song.artworkUrl ?? ""),
                                     streamURL: URL(string: song.previewUrl ?? ""))
                        musicPlayer.play(song: s, inQueue: trendingSongs.map {
                            Song(id: "\($0.id)", title: $0.title, artistIds: [$0.artist],
                                 primaryArtistId: $0.artist, duration: 30,
                                 artworkURL: URL(string: $0.artworkUrl ?? ""),
                                 streamURL: URL(string: $0.previewUrl ?? ""))
                        })
                    } label: {
                        MusicSongRowTile(rank: idx + 1, song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var newReleasesSection: some View {
        MusicHorizontalSection(title: "New Releases", subtitle: "Fresh albums & projects") {
            ForEach(newReleaseAlbums.prefix(10)) { album in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 160, height: 160)
                        .overlay(
                            Group {
                                if let url = album.artworkUrl.flatMap({ URL(string: $0) }) {
                                    AppAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                        placeholder: { Color.gray.opacity(0.2) }
                                } else {
                                    Image(systemName: "square.stack")
                                        .font(.system(size: 28))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        )

                    Text(album.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 160, alignment: .leading)

                    Text(album.artist)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(width: 160, alignment: .leading)
                }
            }
        }
    }

    private var localArtistsSection: some View {
        let local = featuredService.risingArtists
        return MusicHorizontalSection(title: "Michigan Artists", subtitle: "Local artists on the rise") {
            ForEach(local) { artist in
                NavigationLink {
                    ArtistPageView(
                        artist: Artist(
                            id: artist.id,
                            name: artist.displayName,
                            slug: artist.displayName.lowercased().replacingOccurrences(of: " ", with: "-"),
                            bio: artist.bio,
                            avatarURL: URL(string: artist.profileImageURL ?? ""),
                            monthlyListeners: artist.monthlyListeners
                        ),
                        topSongs: [],
                        albums: [],
                        singles: [],
                        similarArtists: []
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        AppAsyncImage(url: URL(string: artist.profileImageURL ?? "")) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.gray.opacity(0.3) }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.Colors.primary.opacity(0.5), lineWidth: 1.5))

                        Text(artist.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Text((artist.genres.first ?? "Hip-Hop") + " • 810")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 90, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var genresSection: some View {
        let genres = ["Hip-Hop", "R&B", "Pop", "Rock", "Electronic", "Country", "Afrobeats", "Latin", "Jazz", "Indie", "Local Artists"]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Genres")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(genres, id: \.self) { genre in
                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack {
                            Text(genre)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(12)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var curatedPlaylistsSection: some View {
        let playlists = playlistService.playlists
        let moodNames = ["Night Drive", "Workout Mode", "Chill Vibes", "Hype Up", "Late Night", "Study Flow", "Trap Season", "R&B Feels", "Summer Hits", "810 Anthems"]
        return MusicHorizontalSection(title: "Curated Playlists", subtitle: "Editorial picks for every mood") {
            if playlists.isEmpty {
                ForEach(moodNames.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 160, height: 190)
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Spacer()
                                Text(moodNames[i])
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text("Curated by MyChannel")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(12),
                            alignment: .bottomLeading
                        )
                }
            } else {
                ForEach(playlists.prefix(10)) { playlist in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 160, height: 190)
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Spacer()
                                Text(playlist.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text("\(playlist.trackCount) tracks")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(12),
                            alignment: .bottomLeading
                        )
                }
            }
        }
    }
}

// MARK: - Reusable Section Shell

private struct MusicHorizontalSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    content
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct MusicSongRowTile: View {
    let rank: Int
    let song: CatalogSong?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 24)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(width: 54, height: 54)
                .overlay(
                    Group {
                        if let url = song?.artworkUrl.flatMap({ URL(string: $0) }) {
                            AppAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color.gray.opacity(0.2) }
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(song?.title ?? "Loading...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(song?.artist ?? "—")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(AppTheme.Colors.primary)
        }
        .frame(width: 280)
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

