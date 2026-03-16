//
//  UserLibraryView.swift
//  MyChannel
//
//  User music library: playlists, liked songs, saved albums, followed artists.
//

import SwiftUI

struct UserLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = PlaylistService.shared
    @EnvironmentObject private var musicPlayer: MusicPlayerService

    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var newPlaylistDescription = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                playlistsSection
                likedSongsSection
                recentlyPlayedSection
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Your Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.shared.impact(style: .light)
                    showCreatePlaylist = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .accessibilityLabel("Your music library")
        .sheet(isPresented: $showCreatePlaylist) {
            createPlaylistSheet
        }
    }

    // MARK: - Sections

    private var playlistsSection: some View {
        librarySection(title: "Playlists", icon: "music.note.list") {
            if playlistService.playlists.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("No playlists yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Button {
                        showCreatePlaylist = true
                    } label: {
                        Text("Create Your First Playlist")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(playlistService.playlists) { playlist in
                        playlistRow(playlist)
                        if playlist.id != playlistService.playlists.last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    private var likedSongsSection: some View {
        librarySection(title: "Liked Songs", icon: "heart.fill") {
            if playlistService.likedSongs.isEmpty {
                Text("Songs you like will appear here")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(playlistService.likedSongs.prefix(10)) { track in
                        likedSongRow(track)
                        if track.id != playlistService.likedSongs.prefix(10).last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                    if playlistService.likedSongs.count > 10 {
                        Button {
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text("See all \(playlistService.likedSongs.count) songs")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
    }

    private var recentlyPlayedSection: some View {
        librarySection(title: "Recently Played", icon: "clock.fill") {
            if playlistService.recentlyPlayed.isEmpty {
                Text("Tracks you play will appear here")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(playlistService.recentlyPlayed.prefix(8)) { track in
                        likedSongRow(track)
                        if track.id != playlistService.recentlyPlayed.prefix(8).last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func playlistRow(_ playlist: UserPlaylist) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: (playlist.coverColors ?? ["#6B46C1", "#4299E1"]).compactMap { Color(hexOptional: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(playlist.trackCount) tracks • \(playlist.formattedDuration)")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                HapticManager.shared.impact(style: .light)
                if let first = playlist.tracks.first {
                    let song = Song(id: first.id, title: first.title,
                                   artistIds: [first.artist], primaryArtistId: first.artist,
                                   duration: first.duration)
                    musicPlayer.play(song: song, inQueue: playlist.tracks.map {
                        Song(id: $0.id, title: $0.title, artistIds: [$0.artist],
                             primaryArtistId: $0.artist, duration: $0.duration,
                             artworkURL: $0.artworkURL.flatMap { URL(string: $0) })
                    })
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func likedSongRow(_ track: PlaylistTrack) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(width: 48, height: 48)
                .overlay(
                    Group {
                        if let artStr = track.artworkURL, let url = URL(string: artStr) {
                            AppAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color.gray.opacity(0.2) }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                HapticManager.shared.impact(style: .light)
                let song = Song(id: track.id, title: track.title,
                               artistIds: [track.artist], primaryArtistId: track.artist,
                               duration: track.duration,
                               artworkURL: track.artworkURL.flatMap { URL(string: $0) })
                musicPlayer.play(song: song)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Create Playlist Sheet

    private var createPlaylistSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Playlist Details")) {
                    TextField("Playlist Name", text: $newPlaylistName)
                    TextField("Description (optional)", text: $newPlaylistDescription)
                }

                Section {
                    Button {
                        guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        HapticManager.shared.notification(type: .success)
                        _ = playlistService.createPlaylist(
                            name: newPlaylistName.trimmingCharacters(in: .whitespaces),
                            description: newPlaylistDescription.trimmingCharacters(in: .whitespaces).isEmpty
                                ? nil : newPlaylistDescription,
                            isPublic: false
                        )
                        newPlaylistName = ""
                        newPlaylistDescription = ""
                        showCreatePlaylist = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create Playlist")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty
                                  ? Color.gray : AppTheme.Colors.primary)
                    )
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPlaylistName = ""
                        newPlaylistDescription = ""
                        showCreatePlaylist = false
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }

    // MARK: - Section Shell

    private func librarySection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 20)

            content()
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
        }
    }
}


#Preview {
    NavigationStack {
        UserLibraryView()
            .environmentObject(AppState())
            .environmentObject(MusicPlayerService.shared)
    }
}
