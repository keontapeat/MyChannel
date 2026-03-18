//
//  ArtistTrackCard.swift
//  MyChannel
//
//  Card component for creator-uploaded tracks shown in the Music Hub
//  discovery feed (New Artist Drops, Trending on MyChannel).
//

import SwiftUI

// MARK: - Artist Track Card

struct ArtistTrackCard: View {
    let track: UploadedTrack
    @State private var showComments = false
    @State private var isLiked = false
    @ObservedObject private var preview = AudioPreviewPlayer.shared

    private var isPlaying: Bool {
        preview.currentTrackId == track.id && preview.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Artwork
            ZStack(alignment: .bottomLeading) {
                artworkView
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                // NEW badge
                if track.isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(red: 0.88, green: 0.15, blue: 0.25)))
                        .padding(8)
                }

                // Play/pause overlay
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            togglePlayback()
                            HapticManager.shared.impact(style: .medium)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 38, height: 38)
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: isPlaying ? 0 : 1)
                            }
                        }
                        .padding(10)
                    }
                    Spacer()
                }
                .frame(width: 160, height: 160)
            }

            // Progress bar when playing
            if isPlaying {
                ProgressView(value: preview.progress)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.88, green: 0.15, blue: 0.25))
                    .frame(width: 160)
            }

            // Title & artist
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)

                Text(track.artistName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(track.genre)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                    .lineLimit(1)
            }

            // Action row
            HStack(spacing: 14) {
                Button {
                    isLiked.toggle()
                    MusicDiscoveryFeedService.shared.toggleLike(trackId: track.id, liked: isLiked)
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isLiked ? .red : .secondary)
                }

                Button {
                    showComments = true
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Stream count
                HStack(spacing: 3) {
                    Image(systemName: "headphones")
                        .font(.system(size: 11))
                    Text(formatCount(track.streamCount))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .frame(width: 160)
        }
        .sheet(isPresented: $showComments) {
            ArtistTrackCommentSheet(track: track)
        }
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkView: some View {
        if let urlString = track.artworkURL, let url = URL(string: urlString) {
            AppAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                artworkPlaceholder
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        guard let url = URL(string: track.audioURL) else { return }
        if isPlaying {
            preview.pause()
        } else {
            preview.play(
                url: url,
                trackId: track.id,
                title: track.title,
                artist: track.artistName,
                artworkURL: track.artworkURL.flatMap { URL(string: $0) }
            )
            MusicDiscoveryFeedService.shared.incrementStream(trackId: track.id)
        }
    }

    // MARK: - Helpers

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
