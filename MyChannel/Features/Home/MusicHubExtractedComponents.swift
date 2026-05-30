// ⚡ PERFORMANCE: Extracted from MusicHubView.swift — independent compilation unit.
// MusicCard + premium UI components compile separately from the 1490-line main hub view.
import SwiftUI

struct MusicCard: View {
    let song: CatalogSong
    var onOpenURL: (URL) -> Void = { url in
        _ = DeepLinkService.shared.parse(url: url)
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

// MARK: - New Release Row (Isolated view to prevent full-list re-renders during playback)

// Local NowPlayingBar removed; using GlobalNowPlayingBar

// MARK: - 🔥 PREMIUM UI COMPONENTS 🔥

// MARK: - Music Mood

// MARK: - Music Genre

// MARK: - Premium Badge

// MARK: - Quick Action Button (MyChannel Adaptive Style)

// MARK: - Mood Chip

// MARK: - Music Section Header

// MARK: - New Release Card

// MARK: - Spatial Audio Card

// MARK: - Genre Card

// MARK: - Music Wave Path (Animated Background)

// ScaleButtonStyle moved to Core/Components/ButtonStyles.swift

// MARK: - Curated Playlist Model

// MARK: - Music Playlist Card

// MARK: - Radio Station Model

// MARK: - Radio Station Card

// MARK: - Music Chart Model

// MARK: - Chart Card

// MARK: - Recently Played Card

// MARK: - Equalizer Sheet

// MARK: - Discover Artist Card (Smaller Square Style)

// MARK: - Discover Mix Card (kept for legacy, or can be removed if unused)


// MARK: - Friend Activity Card


// MARK: - Concert Preview Card


// MARK: - Behind the Music Card


// MARK: - Top Artist Square Card (matches Pinned Artists card size)

// MARK: - Top Chart Square Card


// MARK: - 3D Shelf Carousel Page (5 song rows with shelf effect)

