//
//  ArtistPageView.swift
//  MyChannel
//
//  Premium artist profile similar to Spotify / Apple Music.
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ArtistPageView: View {
    let artist: Artist
    let topSongs: [Song]
    let albums: [Album]
    let singles: [Album]
    let similarArtists: [Artist]

    @EnvironmentObject private var musicPlayer: MusicPlayerService
    @State private var showUploadSheet = false
    @State private var showEarnings = false

    private var isOwnProfile: Bool {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid == artist.id ||
               Auth.auth().currentUser?.displayName == artist.name
        #else
        return false
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if isOwnProfile {
                    artistToolbar
                }
                topSongsSection
                albumsSection
                singlesSection
                onMyChannelSection
                similarArtistsSection
                aboutSection
            }
            .padding(.bottom, 40)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUploadSheet) {
            MusicUploadSheet()
        }
        .navigationDestination(isPresented: $showEarnings) {
            ArtistEarningsView(artistId: artist.id, artistName: artist.name)
        }
    }
    
    // MARK: - Artist Toolbar (own profile only)

    private var artistToolbar: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.impact(style: .medium)
                showUploadSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Upload Track")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                HapticManager.shared.impact(style: .light)
                showEarnings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Earnings")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.primary.opacity(0.4), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Header
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppTheme.Colors.primary, AppTheme.Colors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 260)
            
            VStack(alignment: .leading, spacing: 12) {
                if let url = artist.heroImageURL ?? artist.avatarURL {
                    AppAsyncImage(
                        url: url,
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                        },
                        placeholder: {
                            Color.black.opacity(0.2)
                        }
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 3))
                    .shadow(radius: 10)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(artist.monthlyListeners) monthly listeners")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        if let first = topSongs.first {
                            musicPlayer.play(song: first, inQueue: topSongs)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Play")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .light)
                        // Follow action hook – integrate with SocialMusicService later.
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Follow")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Sections
    
    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ForEach(Array(topSongs.enumerated()), id: \.element.id) { index, song in
                Button {
                    HapticManager.shared.impact(style: .light)
                    musicPlayer.play(song: song, inQueue: topSongs)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 24)
                        
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Group {
                                    if let url = song.artworkURL {
                                        AppAsyncImage(
                                            url: url,
                                            content: { image in
                                                image.resizable().scaledToFill()
                                            },
                                            placeholder: { Color.gray.opacity(0.2) }
                                        )
                                    } else {
                                        Image(systemName: "music.note")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            Text(song.genre ?? "Song")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(song.formattedDuration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var albumsSection: some View {
        if albums.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Albums")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(albums, id: \.id) { album in
                            NavigationLink {
                                AlbumDetailView(album: album, tracks: [])
                            } label: {
                                AlbumTileView(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 12)
        )
    }
    
    private var singlesSection: some View {
        if singles.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Singles & EPs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(singles, id: \.id) { album in
                            NavigationLink {
                                AlbumDetailView(album: album, tracks: [])
                            } label: {
                                AlbumTileView(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 4)
        )
    }
    
    private var onMyChannelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On MyChannel")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Connect your music videos and live streams here.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var similarArtistsSection: some View {
        if similarArtists.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Fans also like")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(similarArtists, id: \.id) { other in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Group {
                                            if let url = other.avatarURL {
                                                AppAsyncImage(
                                                    url: url,
                                                    content: { image in
                                                        image.resizable().scaledToFill()
                                                    },
                                                    placeholder: { Color.gray.opacity(0.2) }
                                                )
                                            } else {
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                            }
                                        }
                                        .clipShape(Circle())
                                    )
                                
                                Text(other.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 90)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)
        )
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let bio = artist.bio {
                Text(bio)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } else {
                Text("Artist bio coming soon.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

// MARK: - Supporting Views

private struct AlbumTileView: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(width: 150, height: 150)
                .overlay(
                    Group {
                        if let url = album.artworkURL {
                            AppAsyncImage(
                                url: url,
                                content: { image in
                                    image.resizable().scaledToFill()
                                },
                                placeholder: { Color.gray.opacity(0.2) }
                            )
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
            
            Text(album.type == .album ? "Album" : (album.type == .ep ? "EP" : "Single"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(width: 150, alignment: .leading)
    }
}

