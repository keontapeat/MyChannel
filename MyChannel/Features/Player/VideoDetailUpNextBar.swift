import SwiftUI

struct VideoDetailUpNextBar: View {
    let sourceVideo: Video
    let next: Video
    @Binding var autoplayEnabled: Bool
    let onTap: () -> Void
    let onImpression: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppAsyncImage(url: URL(string: next.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial)
            }
            .frame(width: 56, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                Text("Next")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(2),
                alignment: .bottomTrailing
            )
            Text(next.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Toggle(isOn: $autoplayEnabled) { Text("Autoplay").font(.caption2) }
                .labelsHidden()
                .tint(AppTheme.Colors.primary)
            Button(action: onTap) {
                Image(systemName: "play.fill")
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .onAppear(perform: onImpression)
    }
}
