import SwiftUI

struct VideoDetailUpNextBar: View {
    let sourceVideo: Video
    let next: Video
    @Binding var autoplayEnabled: Bool
    let onTap: () -> Void
    let onImpression: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Compact thumbnail - YouTube style (52x29)
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: next.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 52, height: 29)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                // Minimal "NEXT" badge
                Text("NEXT")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(2)
                    .padding(2)
            }

            // Compact video info
            VStack(alignment: .leading, spacing: 1) {
                Text("Up next")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(next.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            Spacer()

            // Compact autoplay toggle
            HStack(spacing: 6) {
                Text("Autoplay")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Toggle(isOn: $autoplayEnabled) { EmptyView() }
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
                    .scaleEffect(0.75)
                    .frame(width: 44)
            }

            // Compact play button
            Button(action: onTap) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .onAppear(perform: onImpression)
    }
}
