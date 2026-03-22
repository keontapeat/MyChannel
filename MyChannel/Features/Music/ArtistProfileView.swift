import SwiftUI

// MARK: - Discover Artist Card (horizontal scroll on home)

struct DiscoverArtistCard: View {
    let artist: CatalogArtist
    
    var body: some View {
        VStack(spacing: 10) {
            AppAsyncImage(url: URL(string: artist.artworkUrl ?? "")) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.7), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(width: 130, height: 130)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text(artist.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(width: 130)
        }
    }
}

// MARK: - Tag Pill

private struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.15)))
    }
}

// MARK: - Action Button

private struct ArtistActionButton: View {
    let icon: String
    let title: String
    var isPrimary: Bool = false
    var accentColor: Color = .red
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPrimary ? accentColor : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPrimary ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Artist Profile View

// MARK: - Stable Track Row Data (cached to prevent re-render jitter)
private struct TrackRowData: Identifiable {
    let id: Int
    let track: CatalogSong
    let rank: Int
    let playCount: String
    let duration: String
    let isTrending: Bool
    let artworkURL: URL?
}

// MARK: - Isolated Play Button (only this re-renders on playback state change)
private struct TrackPlayButton: View {
    let trackId: String
    let previewUrl: String?
    let title: String
    let artist: String
    let artworkURL: URL?
    
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    private var isPlaying: Bool {
        preview.currentTrackId == trackId && preview.isPlaying
    }
    
    var body: some View {
        Button {
            if let p = previewUrl, let u = URL(string: p) {
                if isPlaying {
                    preview.pause()
                } else {
                    preview.play(url: u, trackId: trackId, title: title, artist: artist, artworkURL: artworkURL)
                }
                HapticManager.shared.selection()
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
    }
}

struct ArtistProfileView: View {
    let artist: CatalogArtist
    @State private var tracks: [CatalogSong] = []
    @State private var trackRowData: [TrackRowData] = []
    @State private var loading = true
    @State private var isFollowing = false
    @Environment(\.dismiss) private var dismiss
    @State private var heroImageURL: URL? = nil
    
    private let accentRed = Color(red: 0.85, green: 0.15, blue: 0.15)
    private let darkGray = Color(white: 0.12)
    
    /// Look up featured friend data if this artist is one of your friends
    private var featuredFriend: FeaturedFriendArtist? {
        FeaturedFriendArtist.friends.first { $0.appleMusicId == artist.id }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    actionButtons.padding(.top, 20).padding(.horizontal, 20)
                    popularTracksSection.padding(.top, 32)
                    latestDropsSection.padding(.top, 32)
                    
                    // Extra padding for bottom stats bar
                    Spacer().frame(height: 120)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .animation(nil, value: tracks.count) // Prevent layout animation glitches
            
            // Floating Stats Bar at bottom
            statsBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button { HapticManager.shared.impact(style: .light) } label: {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Button {
                        isFollowing.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(accentRed.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accentRed, lineWidth: 1)
                            )
                    }
                    Button { HapticManager.shared.impact(style: .light) } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Resolve hero image: use artist artwork if available, otherwise load from tracks
            if let artUrl = artist.artworkUrl, !artUrl.isEmpty, let url = URL(string: artUrl) {
                heroImageURL = url
            }
            await loadTracks()
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = heroImageURL {
                AppAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.05, blue: 0.05), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: 420)
                .clipped()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.05, blue: 0.05), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 420)
            }
            
            // Gradient overlay to fade into black background
            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 420)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(artist.name)
                        // Use a stylish cursive/script font
                        .font(.custom("SnellRoundhand-Bold", size: 48))
                        .foregroundColor(.white)
                        // Fallback if custom font fails
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.7, green: 0.2, blue: 0.2))
                        .background(Circle().fill(.white).frame(width: 10, height: 10))
                }
                
                Text("\(featuredFriend?.followerCount ?? formatCount(Int.random(in: 1_000_000...5_000_000))) Followers • \(featuredFriend?.playCount ?? formatCount(Int.random(in: 10_000_000...100_000_000))) Plays")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 12) {
                    TagPill(text: featuredFriend?.location ?? "Flint, MI")
                    TagPill(text: featuredFriend?.genres.joined(separator: " • ") ?? "Hip-Hop • Underground")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 0)
        }
        .frame(height: 420)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                let fallbackArt = URL(string: artist.artworkUrl ?? "")
                let items: [PreviewQueueItem] = tracks.compactMap { s in
                    guard let p = s.previewUrl, let u = URL(string: p) else { return nil }
                    let art = URL(string: s.artworkUrl ?? "") ?? fallbackArt
                    return PreviewQueueItem(trackId: String(s.id), url: u, title: s.title, artist: s.artist, artworkURL: art)
                }
                if !items.isEmpty { AudioPreviewPlayer.shared.queueAndPlay(items) }
                HapticManager.shared.impact(style: .medium)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Play All")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [accentRed, Color(red: 0.6, green: 0.1, blue: 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
            
            Button(action: {
                isFollowing.toggle()
                HapticManager.shared.impact(style: .medium)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                    Text("Follow")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(darkGray))
            }
            
            Button(action: { HapticManager.shared.impact(style: .light) }) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentRed)
                    Text("Support")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(darkGray))
            }
            
            Button(action: { HapticManager.shared.impact(style: .light) }) {
                HStack(spacing: 6) {
                    Text("$")
                        .font(.system(size: 16, weight: .bold))
                    Text("Share")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(darkGray))
            }
        }
    }
    
    // MARK: - Popular Tracks
    
    private var popularTracksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Popular Tracks")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("See All") {}
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.8, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 20)
            
            if loading {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(trackRowData.prefix(5)) { row in
                        popularTrackRow(row: row)
                    }
                }
            }
        }
    }
    
    private func popularTrackRow(row: TrackRowData) -> some View {
        HStack(spacing: 14) {
            // Track Image — fall back to artist artwork if track artwork is missing
            AppAsyncImage(url: row.artworkURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Rank Number
            Text("\(row.rank)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            
            // Title & Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.track.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if row.isTrending {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("Trending")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(accentRed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(accentRed.opacity(0.2)))
                    }
                }
                
                HStack(spacing: 4) {
                    Text(row.playCount)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6))
                    Text("•  \(row.duration)")
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Trailing Actions
            HStack(spacing: 16) {
                Button { HapticManager.shared.impact(style: .light) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Isolated play button — only this subview re-renders on playback state change
                TrackPlayButton(
                    trackId: String(row.track.id),
                    previewUrl: row.track.previewUrl,
                    title: row.track.title,
                    artist: row.track.artist,
                    artworkURL: row.artworkURL
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(darkGray)
                .padding(.horizontal, 10)
        )
    }
    
    // MARK: - Latest Drops
    
    private var latestDropsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Latest Drops")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("View All") {}
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.8, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(trackRowData.prefix(6)) { row in
                        AppAsyncImage(url: row.artworkURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(darkGray)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        .frame(width: 160, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            if let p = row.track.previewUrl, let u = URL(string: p) {
                                AudioPreviewPlayer.shared.play(url: u, trackId: String(row.track.id), title: row.track.title, artist: row.track.artist, artworkURL: row.artworkURL)
                                HapticManager.shared.impact(style: .medium)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Stats Bar (edge-to-edge bottom dock)
    
    private var statsBar: some View {
        VStack(spacing: 0) {
            // Subtle top divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                // Fans
                VStack(spacing: 3) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Text(featuredFriend?.followerCount ?? "125K")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Fans")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 0.5, height: 32)
                
                // Monthly Listeners
                VStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Text(featuredFriend?.monthlyListeners ?? "420K")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Monthly Listeners")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 0.5, height: 32)
                
                // Subscribe CTA
                Button {
                    UIApplication.shared.sendAction(#selector(AppActions.presentMusicPaywall), to: nil, from: nil, for: nil)
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    VStack(spacing: 2) {
                        Text("Subscribe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("$4.99/mo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentRed, Color(red: 0.6, green: 0.1, blue: 0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(
            Color(white: 0.06)
                .overlay(
                    Color.white.opacity(0.03)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Helpers
    
    private func loadTracks() async {
        if let results = try? await MusicCatalogService.shared.topTracksForArtist(artistId: artist.id, limit: 15) {
            tracks = results
            // Build stable row data once — random values are cached and won't regenerate on re-render
            let artistFallbackArt = URL(string: artist.artworkUrl ?? "")
            trackRowData = results.enumerated().map { index, track in
                let trackArt: URL? = {
                    if let art = track.artworkUrl, !art.isEmpty, let url = URL(string: art) { return url }
                    return artistFallbackArt
                }()
                return TrackRowData(
                    id: track.id,
                    track: track,
                    rank: index + 1,
                    playCount: formatCount(Int.random(in: 800_000...3_000_000)),
                    duration: "\(Int.random(in: 2...4)):\(String(format: "%02d", Int.random(in: 10...59)))",
                    isTrending: index == 2,
                    artworkURL: trackArt
                )
            }
            // If we still have no hero image, use the first track's artwork
            if heroImageURL == nil, let firstArt = results.first?.artworkUrl, !firstArt.isEmpty, let url = URL(string: firstArt) {
                heroImageURL = url
            }
        }
        loading = false
    }
    
    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            let m = Double(n) / 1_000_000.0
            return String(format: "%.1fM", m)
        } else if n >= 1_000 {
            let k = Double(n) / 1_000.0
            return String(format: "%.0fK", k)
        }
        return "\(n)"
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }
}
