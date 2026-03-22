//
//  FeaturedArtistsSection.swift
//  MyChannel
//
//  Featured Artists Section - MyChannel Custom Design
//

import SwiftUI

// MARK: - Featured Artists Section

struct FeaturedArtistsSection: View {
    @StateObject private var featuredService = FeaturedArtistService.shared
    @State private var selectedArtist: FeaturedArtist?
    @State private var showArtistDetail: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Featured Artists")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
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
            if featuredService.isLoading {
                loadingView
            } else if featuredService.artists.isEmpty {
                emptyView
            } else {
                artistsCarousel
            }
        }
        .onAppear {
            Task {
                await featuredService.fetchArtists()
            }
        }
        .fullScreenCover(isPresented: $showArtistDetail) {
            if let artist = selectedArtist {
                ArtistDetailSheet(artist: artist)
            }
        }
    }
    
    private var artistsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(featuredService.artists) { artist in
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
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 120, height: 120)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.surface)
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
            .foregroundColor(AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - Artist Circle Card (MyChannel Style)

struct ArtistCircleCard: View {
    let artist: FeaturedArtist
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
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if artist.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.verificationBlue)
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
                .fill(AppTheme.Colors.surface)
            
            Image(systemName: "music.mic")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Artist Detail Sheet (Full-Bleed Hero — Image 2 Layout)

struct ArtistDetailSheet: View {
    let artist: FeaturedArtist
    @Environment(\.dismiss) private var dismiss
    @StateObject private var featuredService = FeaturedArtistService.shared
    @State private var tracks: [FeaturedArtistTrack] = []
    @State private var isLoadingTracks: Bool = true
    @ObservedObject private var preview = AudioPreviewPlayer.shared

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    tagsRow
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                    actionButtons
                        .padding(.top, 20)
                    popularTracksSection
                        .padding(.top, 28)
                    latestDropsSection
                        .padding(.top, 28)
                    bottomStatsBar
                        .padding(.top, 28)
                    Spacer().frame(height: 60)
                }
            }
            .ignoresSafeArea(edges: .top)

            topOverlayButtons
        }
        .task {
            tracks = await featuredService.getArtistTracks(artist: artist)
            isLoadingTracks = false
        }
    }

    // MARK: - Full-Bleed Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            let imgStr = artist.bannerImageURL ?? artist.profileImageURL
            if let str = imgStr, let url = URL(string: str) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [AppTheme.Colors.primary.opacity(0.6), AppTheme.Colors.backgroundDark],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Colors.primary.opacity(0.6), AppTheme.Colors.backgroundDark],
                        startPoint: .top, endPoint: .bottom
                    ))
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(artist.displayName)
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    if artist.isVerified {
                        ZStack {
                            Circle().fill(AppTheme.Colors.primary).frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                Text("\(formatNumber(artist.followerCount)) Followers  •  \(formatNumber(artist.totalStreams)) Plays")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .clipped()
    }

    // MARK: - Tags (hometown + genres)

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !artist.hometown.isEmpty {
                    tagPill(text: artist.hometown)
                }
                ForEach(artist.genres.prefix(3), id: \.self) { genre in
                    tagPill(text: genre)
                }
            }
        }
    }

    private func tagPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Play All — filled red
                Button {
                    HapticManager.shared.impact(style: .medium)
                    queueAllPreviews(shuffle: false)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                        Text("Play All")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppTheme.Colors.primary))
                }

                // Follow — outline
                Button { HapticManager.shared.impact(style: .light) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle")
                        Text("Follow")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.clear)
                            .overlay(Capsule().strokeBorder(AppTheme.Colors.divider, lineWidth: 1.5))
                    )
                }

                // Support — outline with red heart
                Button { HapticManager.shared.impact(style: .light) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Support")
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.clear)
                            .overlay(Capsule().strokeBorder(AppTheme.Colors.divider, lineWidth: 1.5))
                    )
                }

                // Share — outline
                Button { HapticManager.shared.impact(style: .light) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "dollarsign.circle")
                        Text("Share")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.clear)
                            .overlay(Capsule().strokeBorder(AppTheme.Colors.divider, lineWidth: 1.5))
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Popular Tracks

    private var popularTracksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Popular Tracks")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button("See All") { HapticManager.shared.impact(style: .light) }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, 20)

            if isLoadingTracks {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 3).fill(AppTheme.Colors.surface).frame(width: 20, height: 13)
                            RoundedRectangle(cornerRadius: 8).fill(AppTheme.Colors.surface).frame(width: 50, height: 50)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(AppTheme.Colors.surface).frame(width: 130, height: 13)
                                RoundedRectangle(cornerRadius: 3).fill(AppTheme.Colors.surface).frame(width: 80, height: 11)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                }
                .shimmering()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tracks.prefix(5).enumerated()), id: \.element.id) { index, ft in
                        TrackRow(track: ft.track, index: index + 1)
                    }
                }
            }
        }
    }

    // MARK: - Latest Drops

    private var latestDropsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Latest Drops")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button("View All") { HapticManager.shared.impact(style: .light) }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tracks.prefix(6), id: \.id) { ft in
                        ZStack(alignment: .bottomLeading) {
                            Group {
                                if let url = ft.track.artworkURL {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface)
                                }
                            }
                            .frame(width: 130, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.55)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(width: 130, height: 130)

                            Text(ft.track.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                        .frame(width: 130, height: 130)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 10) {
            statsTile(icon: "person.2.fill", label: "Fans", value: formatNumber(artist.followerCount))
            statsTile(icon: "chart.bar.fill", label: "Monthly Listeners", value: formatNumber(artist.monthlyListeners))
            Button { HapticManager.shared.impact(style: .medium) } label: {
                VStack(spacing: 2) {
                    Text("Subscribe")
                        .font(.system(size: 14, weight: .bold))
                    Text("$4.99/mo")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
    }

    private func statsTile(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Top Overlay Buttons

    private var topOverlayButtons: some View {
        HStack {
            Button {
                dismiss()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 10) {
                Button { HapticManager.shared.impact(style: .light) } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }
                Button { HapticManager.shared.impact(style: .light) } label: {
                    Text("Follow")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Capsule())
                }
                Button { HapticManager.shared.impact(style: .light) } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    // MARK: - Helpers

    private func queueAllPreviews(shuffle: Bool) {
        let items: [PreviewQueueItem] = tracks.compactMap { ft in
            guard let url = ft.track.previewURL else { return nil }
            return PreviewQueueItem(trackId: ft.track.id, url: url, title: ft.track.title, artist: ft.track.artistName, artworkURL: ft.track.artworkURL)
        }
        guard !items.isEmpty else { return }
        AudioPreviewPlayer.shared.queueAndPlay(shuffle ? items.shuffled() : items)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 { return String(format: "%.1fM", Double(num) / 1_000_000) }
        if num >= 1_000 { return String(format: "%.0fK", Double(num) / 1_000) }
        return "\(num)"
    }
}

// MARK: - Track Row (MyChannel Style — Preview Playback)

struct TrackRow: View {
    let track: MusicKitTrack
    let index: Int
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    private var isPlaying: Bool {
        preview.currentTrackId == track.id && preview.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number
            Text("\(index)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(index <= 3 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .frame(width: 24)
            
            // Artwork
            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isPlaying ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play/Pause preview button
            if track.previewURL != nil {
                Button {
                    togglePreview()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isPlaying ? .white : AppTheme.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(isPlaying ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
            }
            
            // More button
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isPlaying ? AppTheme.Colors.primary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            togglePreview()
        }
    }
    
    private func togglePreview() {
        guard let previewURL = track.previewURL else { return }
        if preview.currentTrackId == track.id && preview.isPlaying {
            preview.pause()
        } else {
            preview.play(
                url: previewURL,
                trackId: track.id,
                title: track.title,
                artist: track.artistName,
                artworkURL: track.artworkURL
            )
        }
        HapticManager.shared.selection()
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
struct FeaturedArtistsSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            FeaturedArtistsSection()
        }
        .background(AppTheme.Colors.background)
    }
}
#endif


