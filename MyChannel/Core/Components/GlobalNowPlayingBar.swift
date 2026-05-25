import SwiftUI

struct GlobalNowPlayingBar: View {
    @ObservedObject private var preview = AudioPreviewPlayer.shared

    var body: some View {
        Group {
            if preview.currentTrackId != nil {
                HStack(spacing: 12) {
                    ArtworkThumb(url: preview.currentArtworkURL)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(preview.currentTitle ?? "Preview")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if let artist = preview.currentArtist, !artist.isEmpty {
                                Text("•")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }
                        ProgressView(value: preview.progress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        if preview.isPlaying { preview.pause() } else { preview.resume() }
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: preview.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.black)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
                .padding(12)
                .background(BlurView(style: .systemMaterialDark).clipShape(RoundedRectangle(cornerRadius: 14)))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                .onTapGesture {
                    NotificationCenter.default.post(name: NSNotification.Name("PresentGlobalNowPlayingSheet"), object: nil)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 88) // leave space above tab bar
    }
}

private struct ArtworkThumb: View {
    let url: URL?
    var body: some View {
        AppAsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.2))
                .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.9)))
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}


