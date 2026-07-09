/**
 * MovieDetailHero — parallax poster / backdrop for MovieDetailView.
 */

import SwiftUI

struct MovieDetailHero: View {
    let movie: FreeMovie
    let geometry: GeometryProxy
    let headerHeight: CGFloat
    let scrollOffset: CGFloat
    let posterWidth: CGFloat
    let posterHeight: CGFloat
    let isWatchlisted: Bool
    let onToggleWatchlist: () -> Void
    let onPlayTrailer: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            parallaxBackground
            gradientOverlay
            contentInfo
        }
        .frame(height: headerHeight)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named("scroll")).minY
                )
            }
        )
    }

    private var parallaxBackground: some View {
        MultiSourceAsyncImage(
            urls: movie.posterCandidates + [URL(string: movie.backdropURL ?? "")].compactMap { $0 },
            content: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: headerHeight + max(0, scrollOffset)
                    )
                    .offset(y: -scrollOffset * 0.5)
                    .blur(radius: max(0, scrollOffset * 0.01))
            },
            placeholder: {
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary.opacity(0.3),
                        Color.black.opacity(0.8),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geometry.size.width, height: headerHeight)
            }
        )
        .clipped()
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [
                .clear,
                .black.opacity(0.3),
                .black.opacity(0.85),
                .black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var contentInfo: some View {
        HStack(alignment: .bottom, spacing: 16) {
            MultiSourceAsyncImage(
                urls: movie.posterCandidates,
                content: { image in
                    image
                        .resizable()
                        .scaledToFill()
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.surface)
                }
            )
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
            .accessibilityLabel("\(movie.title) poster")

            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .accessibilityAddTraits(.isHeader)

                if !movie.genre.isEmpty {
                    Text(movie.genreString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Button(action: onPlayTrailer) {
                        Label("Trailer", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(PressableScaleStyle())
                    .accessibilityLabel("Play trailer")

                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        onToggleWatchlist()
                    }) {
                        Image(systemName: isWatchlisted ? "checkmark" : "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isWatchlisted ? AppTheme.Colors.primary : .white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PressableScaleStyle())
                    .accessibilityLabel(isWatchlisted ? "Remove from list" : "Add to list")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}
