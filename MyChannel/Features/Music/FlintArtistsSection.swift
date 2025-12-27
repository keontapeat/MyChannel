//
//  FlintArtistsSection.swift
//  MyChannel
//
//  Flint Artists Section - Clean Apple Music style
//

import SwiftUI

// MARK: - Flint Artists Section

struct FlintArtistsSection: View {
    @StateObject private var flintService = FlintArtistService.shared
    @State private var selectedArtist: FlintArtist?
    @State private var showArtistDetail: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Flint Artists")
                    .font(.system(size: 22, weight: .bold))
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("See All")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 20)
            
            // Artists carousel
            if flintService.isLoading {
                loadingView
            } else if flintService.artists.isEmpty {
                emptyView
            } else {
                artistsCarousel
            }
        }
        .onAppear {
            Task {
                await flintService.fetchArtists()
            }
        }
        .sheet(isPresented: $showArtistDetail) {
            if let artist = selectedArtist {
                FlintArtistDetailSheet(artist: artist)
            }
        }
    }
    
    private var artistsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(flintService.artists) { artist in
                    ArtistCircleCard(artist: artist) {
                        selectedArtist = artist
                        showArtistDetail = true
                        HapticManager.shared.impact(style: .medium)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var loadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 14)
                    }
                    .shimmering()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var emptyView: some View {
        Text("No artists available")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - Artist Circle Card (Apple Music Style)

struct ArtistCircleCard: View {
    let artist: FlintArtist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Circular artist photo
                ZStack {
                    if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                artistPlaceholder
                            case .empty:
                                artistPlaceholder
                                    .shimmering()
                            @unknown default:
                                artistPlaceholder
                            }
                        }
                    } else {
                        artistPlaceholder
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                // Artist name with verified badge
                HStack(spacing: 4) {
                    Text(artist.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if artist.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artistPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            
            Image(systemName: "music.mic")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Flint Artist Detail Sheet (Apple Music Style)

struct FlintArtistDetailSheet: View {
    let artist: FlintArtist
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flintService = FlintArtistService.shared
    @StateObject private var musicKitService = MusicKitService.shared
    @State private var tracks: [FlintArtistTrack] = []
    @State private var isLoadingTracks: Bool = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Artist header - Apple Music style
                    artistHeader
                    
                    // Play/Shuffle buttons
                    playButtons
                        .padding(.top, 20)
                    
                    // Top Songs
                    if !tracks.isEmpty || isLoadingTracks {
                        topSongsSection
                            .padding(.top, 32)
                    }
                    
                    // About
                    if let bio = artist.bio, !bio.isEmpty {
                        aboutSection(bio)
                            .padding(.top, 32)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            tracks = await flintService.getArtistTracks(artist: artist)
            isLoadingTracks = false
        }
    }
    
    private var artistHeader: some View {
        VStack(spacing: 16) {
            // Large circular photo
            ZStack {
                if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            // Artist name with verified badge
            HStack(spacing: 6) {
                Text(artist.displayName)
                    .font(.system(size: 28, weight: .bold))
                
                if artist.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            
            // Monthly listeners
            Text("\(formatNumber(artist.monthlyListeners)) monthly listeners")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var playButtons: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.impact(style: .medium)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Button {
                HapticManager.shared.impact(style: .medium)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Songs")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 20)
            
            if isLoadingTracks {
                VStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 14)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 80, height: 12)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .shimmering()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.prefix(5).enumerated()), id: \.element.id) { index, flintTrack in
                        TrackRow(track: flintTrack.track, index: index + 1)
                    }
                }
            }
        }
    }
    
    private func aboutSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 22, weight: .bold))
            
            Text(bio)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(4)
            
            // Genres
            HStack(spacing: 8) {
                ForEach(artist.genres.prefix(3), id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
    
    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

// MARK: - Track Row (Apple Music Style)

struct TrackRow: View {
    let track: MusicKitTrack
    let index: Int
    @StateObject private var musicKitService = MusicKitService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number
            Text("\(index)")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Artwork
            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .regular))
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // More button
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                try? await musicKitService.play(track: track)
            }
            HapticManager.shared.impact(style: .medium)
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct FlintArtistsSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            FlintArtistsSection()
        }
        .background(Color(uiColor: .systemBackground))
    }
}
#endif


