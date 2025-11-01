import SwiftUI

struct NowPlayingSheet: View {
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)

            Spacer(minLength: 0)

            AppAsyncImage(url: preview.currentArtworkURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6))
                    .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundColor(.secondary))
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 6) {
                Text(preview.currentTitle ?? "Preview")
                    .font(.title3).bold()
                if let a = preview.currentArtist { Text(a).foregroundColor(.secondary) }
            }
            .padding(.horizontal, 24)

            // Scrubber
            VStack(spacing: 6) {
                Slider(value: Binding(get: { preview.progress }, set: { preview.seek(toFraction: $0) }))
                HStack {
                    Text(timeString(preview.progress * max(1, preview.durationSeconds)))
                    Spacer()
                    Text(timeString(preview.durationSeconds))
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 24) {
                Button(action: { preview.next(); HapticManager.shared.selection() }) {
                    Image(systemName: "forward.fill").font(.title2)
                }
                Button(action: { if preview.isPlaying { preview.pause() } else { preview.resume() }; HapticManager.shared.selection() }) {
                    Image(systemName: preview.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                }
                Button(action: { preview.stop(); HapticManager.shared.impact(style: .light); dismiss() }) {
                    Image(systemName: "stop.fill").font(.title2)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.hidden)
    }

    private func timeString(_ s: Double) -> String {
        let seconds = Int(s.rounded())
        return String(format: "%d:%02d", seconds/60, seconds%60)
    }
}



