//
//  ArtistPageView.swift
//  MyChannel
//
//  MyChannel Custom Artist Profile — Full-bleed hero, stats, popular tracks, latest drops.
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
            VStack(spacing: 0) {
                // Full-bleed hero
                artistHero
                
                VStack(spacing: 24) {
                    // Location + genre pills
                    locationGenrePills
                    
                    // Action buttons row
                    actionButtonsRow
                    
                    // Artist toolbar (own profile only)
                    if isOwnProfile {
                        artistToolbar
                    }
                    
                    // Popular Tracks
                    popularTracksSection
                    
                    // Latest Drops (horizontal)
                    latestDropsSection
                    
                    // Albums
                    albumsSection
                    
                    // Singles & EPs
                    singlesSection
                    
                    // Stats bar
                    statsBar
                    
                    // On MyChannel
                    onMyChannelSection
                    
                    // Similar Artists
                    similarArtistsSection
                    
                    // About
                    aboutSection
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUploadSheet) {
            MusicUploadSheet()
        }
        .navigationDestination(isPresented: $showEarnings) {
            ArtistEarningsView(artistId: artist.id, artistName: artist.name)
        }
    }
    
    // MARK: - Full-Bleed Hero Image
    
    private var artistHero: some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image - edge to edge
            if let url = artist.heroImageURL ?? artist.avatarURL {
                AppAsyncImage(
                    url: url,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        AppTheme.Colors.surface
                    }
                )
                .frame(height: 360)
                .clipped()
            } else {
                AppTheme.Colors.surface
                    .frame(height: 360)
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            
            // Bottom gradient for text readability
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    AppTheme.Colors.background.opacity(0.6),
                    AppTheme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
            
            // Name + verified + follower count
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(artist.name)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.Colors.verificationBlue)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("\(artist.followerCount.formatted()) followers")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 12))
                        Text("\(artist.monthlyListeners.formatted()) plays")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 360)
        .clipped()
    }
    
    // MARK: - Location + Genre Pills
    
    private var locationGenrePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let location = artist.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(location)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface)
                    .clipShape(Capsule())
                }
                
                Text("Hip-Hop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary.opacity(0.12))
                    .clipShape(Capsule())
                
                Text("Michigan Rap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Action Buttons Row
    
    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            // Play All (filled)
            Button {
                HapticManager.shared.impact(style: .medium)
                if let first = topSongs.first {
                    musicPlayer.play(song: first, inQueue: topSongs)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Play All")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Follow (outline)
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Follow")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1.5)
                )
            }
            
            // Support (heart)
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.Colors.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Share
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
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

    // MARK: - Popular Tracks (numbered with play counts + trending badge)
    
    private var popularTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Popular Tracks")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text("See All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 2) {
                ForEach(Array(topSongs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    let isCurrentlyPlaying = musicPlayer.currentSong?.id == song.id && musicPlayer.isPlaying
                    
                    Button {
                        HapticManager.shared.impact(style: .light)
                        musicPlayer.play(song: song, inQueue: topSongs)
                    } label: {
                        HStack(spacing: 12) {
                            // Rank number
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(index < 3 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                .frame(width: 24, alignment: .center)
                            
                            // Artwork
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.surface)
                                .frame(width: 50, height: 50)
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
                            
                            // Title + play count
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(song.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(isCurrentlyPlaying ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                    
                                    if index == 0 {
                                        Text("Trending")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.Colors.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text("\(song.playCount.formatted()) plays")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Play button
                            Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(isCurrentlyPlaying ? .white : AppTheme.Colors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(isCurrentlyPlaying ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                                .clipShape(Circle())
                            
                            // More menu
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            isCurrentlyPlaying
                                ? AppTheme.Colors.primary.opacity(0.08)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Latest Drops (horizontal dark cards)
    
    private var latestDropsSection: some View {
        let allDrops = (albums + singles).sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        if allDrops.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Latest Drops")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(allDrops.prefix(8), id: \.id) { album in
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
        )
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(artist.followerCount.formatted())", label: "Fans")
            
            Divider()
                .frame(height: 30)
                .background(AppTheme.Colors.divider)
            
            statItem(value: "\(artist.monthlyListeners.formatted())", label: "Monthly Listeners")
            
            Divider()
                .frame(height: 30)
                .background(AppTheme.Colors.divider)
            
            VStack(spacing: 4) {
                Text("Subscribe")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("$4.99/mo")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Sections
    
    private var albumsSection: some View {
        if albums.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Albums")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 20)
                
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
        )
    }
    
    private var singlesSection: some View {
        if singles.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Singles & EPs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 20)
                
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
    }
    
    private var similarArtistsSection: some View {
        if similarArtists.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Fans also like")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 20)
                
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

