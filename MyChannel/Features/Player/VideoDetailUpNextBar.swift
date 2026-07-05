import SwiftUI

/// YouTube-parity "Up Next" bar — pinned to the bottom safe area of the screen.
/// Parent is responsible for positioning this at the bottom of the full screen
/// (not as an overlay on a scroll view).
struct VideoDetailUpNextBar: View {
    let sourceVideo: Video
    let next: Video
    @Binding var autoplayEnabled: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onImpression: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top hairline separator — matches YouTube
            Divider()
                .background(Color.primary.opacity(0.12))

            HStack(spacing: 12) {
                // 16:9 thumbnail with duration badge — YouTube uses ~94×53pt
                thumbnailView

                // Video info block
                infoBlock

                Spacer(minLength: 0)

                // Right side: autoplay toggle + dismiss
                trailingControls
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.background)
        }
        .onAppear(perform: onImpression)
        // Slide in from bottom on appearance
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Sub-views (keep body shallow for fast type-checking)

    @ViewBuilder
    private var thumbnailView: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: next.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                                .font(.system(size: 14))
                        )
                }
                .frame(width: 94, height: 53)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                // Duration badge
                if next.duration > 0 {
                    Text(formatDuration(Int(next.duration)))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(3)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Play \(next.title)")
    }

    @ViewBuilder
    private var infoBlock: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                // "Up next" label — YouTube uses a very small secondary label
                HStack(spacing: 4) {
                    Text("Up next")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if autoplayEnabled {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }

                Text(next.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(next.creator.displayName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var trailingControls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Dismiss / close the bar
            Button(action: {
                HapticManager.shared.impact(style: .light)
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss Up Next")

            // Autoplay toggle with label — matches YouTube layout
            HStack(spacing: 5) {
                Text("Autoplay")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Toggle(isOn: $autoplayEnabled) { EmptyView() }
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
                    .scaleEffect(0.72)
                    .frame(width: 42, height: 24)
                    .onChange(of: autoplayEnabled) { _ in
                        HapticManager.shared.impact(style: .rigid)
                    }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
