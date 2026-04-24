import SwiftUI

/// Album page from iTunes catalog — opens from Music Hub Top Albums.
struct AlbumDetailView: View {
    let album: CatalogAlbum
    @State private var tracks: [CatalogSong] = []
    @State private var loading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        AppAsyncImage(url: URL(string: album.artworkUrl ?? "")) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                                .overlay(Image(systemName: "music.note.list").foregroundColor(.white.opacity(0.35)))
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(album.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(3)
                            Text(album.artist)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                            if let aid = album.artistId {
                                NavigationLink {
                                    ArtistProfileView(artist: CatalogArtist(id: aid, name: album.artist, linkUrl: nil, artworkUrl: album.artworkUrl))
                                } label: {
                                    Text("View artist")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    if loading {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                                albumTrackRow(index: index + 1, track: track)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadTracks() }
        .onDisappear {
            AudioPreviewPlayer.shared.stop()
        }
    }
    
    private func albumTrackRow(index: Int, track: CatalogSong) -> some View {
        Button {
            guard let p = track.previewUrl, let u = URL(string: p) else { return }
            AudioPreviewPlayer.shared.play(
                url: u,
                trackId: String(track.id),
                title: track.title,
                artist: track.artist,
                artworkURL: URL(string: track.artworkUrl ?? album.artworkUrl ?? "")
            )
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 28, alignment: .leading)
                AppAsyncImage(url: URL(string: track.artworkUrl ?? album.artworkUrl ?? "")) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.25))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func loadTracks() async {
        if let t = try? await MusicCatalogService.shared.topTracksForAlbum(collectionId: album.id) {
            tracks = t
        }
        loading = false
    }
}
