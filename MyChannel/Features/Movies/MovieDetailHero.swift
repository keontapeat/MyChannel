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

    @State private var showTrailerPreview = false
    @State private var previewMuted = true

    /// YouTube id for the muted hero preview, if the trailer is a YouTube link.
    private var trailerPreviewID: String? {
        guard let t = movie.trailerURL else { return nil }
        return TrailerPlayerView.youtubeID(from: t)
    }

    /// Only keep the preview alive near the top of the scroll view so it pauses
    /// (and releases the WebView) once the user scrolls into the content.
    private var isPreviewVisible: Bool {
        showTrailerPreview && scrollOffset > -80 && trailerPreviewID != nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            parallaxBackground
            trailerPreviewLayer
            gradientOverlay
            contentInfo
            trailerPreviewControls
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
        .onAppear {
            guard trailerPreviewID != nil, !showTrailerPreview else { return }
            // Small delay so the poster/backdrop lands first, then the trailer
            // fades in behind the content — YouTube/Netflix-style.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeIn(duration: 0.7)) { showTrailerPreview = true }
            }
        }
    }

    // MARK: - Trailer Preview (muted, looping, behind content)
    @ViewBuilder
    private var trailerPreviewLayer: some View {
        if isPreviewVisible, let id = trailerPreviewID {
            YouTubePlayerView(
                videoID: id,
                autoplay: true,
                startTime: 0,
                muted: previewMuted,
                showControls: false
            )
            .frame(width: geometry.size.width, height: headerHeight + max(0, scrollOffset))
            .offset(y: -scrollOffset * 0.5)
            .allowsHitTesting(false)
            .clipped()
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var trailerPreviewControls: some View {
        if isPreviewVisible {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        previewMuted.toggle()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: previewMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(PressableScaleStyle())
                    .accessibilityLabel(previewMuted ? "Unmute trailer preview" : "Mute trailer preview")
                }
                .padding(.trailing, 20)
                .padding(.top, 104)
                Spacer()
            }
        }
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

                metaRow

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

    // MARK: - Meta Row (rating • year • runtime • IMDb)
    private var metaRow: some View {
        HStack(spacing: 8) {
            if !movie.rating.isEmpty {
                Text(movie.rating.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    )
            }

            Text(String(movie.year))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            if movie.runtime > 0 {
                metaDot
                Text(movie.formattedRuntime)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            if movie.imdbRating > 0 {
                metaDot
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", movie.imdbRating))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("IMDb")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metaAccessibilityLabel)
    }

    private var metaDot: some View {
        Circle()
            .fill(.white.opacity(0.45))
            .frame(width: 3, height: 3)
    }

    private var metaAccessibilityLabel: String {
        var parts: [String] = []
        if !movie.rating.isEmpty { parts.append("Rated \(movie.rating)") }
        parts.append("Released \(movie.year)")
        if movie.runtime > 0 { parts.append(movie.formattedRuntime) }
        if movie.imdbRating > 0 { parts.append("Rated \(String(format: "%.1f", movie.imdbRating)) on IMDb") }
        return parts.joined(separator: ", ")
    }
}
