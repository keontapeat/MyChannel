import SwiftUI

// MARK: - Hulu-style Movie Card (poster + title + rating + action menu)

struct HuluMovieCard: View {
    let movie: FreeMovie
    var isInMyList: Bool = false
    let onTap: () -> Void
    var onToggleList: (() -> Void)? = nil

    private let cardWidth: CGFloat = 130
    private let posterHeight: CGFloat = 195

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    MultiSourceAsyncImage(
                        urls: movie.posterCandidates,
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: posterHeight)
                                .clipped()
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Color(red: 32/255, green: 34/255, blue: 38/255))
                                .frame(width: cardWidth, height: posterHeight)
                                .overlay(
                                    VStack(spacing: 6) {
                                        Image(systemName: "film")
                                            .font(.system(size: 22))
                                            .foregroundColor(.gray)
                                        Text(movie.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 6)
                                    }
                                )
                                .shimmer(active: true)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Menu {
                        Button(action: onTap) { Label("Watch Now", systemImage: "play.fill") }
                        if let onToggleList {
                            Button(action: onToggleList) {
                                Label(isInMyList ? "Remove from My List" : "Add to My List",
                                      systemImage: isInMyList ? "checkmark" : "plus")
                            }
                        }
                        ShareLink(item: URL(string: movie.streamURL) ?? URL(fileURLWithPath: "/")) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .padding(7)

                    if isInMyList {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(width: cardWidth, height: posterHeight)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                Text(movie.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: cardWidth, alignment: .leading)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", movie.imdbRating))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if movie.year > 0 {
                        Text("• \(String(movie.year))")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.95))
    }
}

// MARK: - Continue Watching Card (landscape + progress bar)

struct ContinueWatchingMovieCard: View {
    let entry: MovieResumeEntry
    let onTap: () -> Void

    private let cardWidth: CGFloat = 230
    private let cardHeight: CGFloat = 130

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottom) {
                    MultiSourceAsyncImage(
                        urls: backdropCandidates,
                        content: { image in
                            image.resizable().scaledToFill()
                                .frame(width: cardWidth, height: cardHeight)
                                .clipped()
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Color(red: 32/255, green: 34/255, blue: 38/255))
                                .frame(width: cardWidth, height: cardHeight)
                                .shimmer(active: true)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Play glyph
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 4)
                        .frame(width: cardWidth, height: cardHeight)

                    VStack(spacing: 4) {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.3))
                                Capsule().fill(AppTheme.Colors.primary)
                                    .frame(width: geo.size.width * CGFloat(min(1, max(0.02, entry.progress))))
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .frame(width: cardWidth, height: cardHeight)
                }
                .frame(width: cardWidth, height: cardHeight)

                Text(entry.movie.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: cardWidth, alignment: .leading)

                Text(entry.remainingText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }

    private var backdropCandidates: [URL] {
        var urls: [URL] = []
        if let b = entry.movie.backdropURL, let u = URL(string: b) { urls.append(u) }
        urls.append(contentsOf: entry.movie.posterCandidates)
        return urls
    }
}

// MARK: - Featured Hero Card (Netflix-style top banner)

struct FeaturedMovieHeroCard: View {
    let movie: FreeMovie
    let isInMyList: Bool
    let onPlay: () -> Void
    let onToggleList: () -> Void
    let onInfo: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            MultiSourceAsyncImage(
                urls: heroCandidates,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: {
                    LinearGradient(
                        colors: [AppTheme.Colors.primary.opacity(0.35), .black],
                        startPoint: .top, endPoint: .bottom
                    )
                    .shimmer(active: true)
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 470)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.85), Color(red: 13/255, green: 14/255, blue: 17/255)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 14) {
                Text(movie.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                // Genre / meta line
                Text(metaLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Button(action: onToggleList) {
                        VStack(spacing: 3) {
                            Image(systemName: isInMyList ? "checkmark" : "plus")
                                .font(.system(size: 18, weight: .bold))
                            Text("My List").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 64)
                    }
                    .buttonStyle(PressableScaleStyle())

                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.97))

                    Button(action: onInfo) {
                        VStack(spacing: 3) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .bold))
                            Text("Info").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 64)
                    }
                    .buttonStyle(PressableScaleStyle())
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 26)
        }
        .frame(height: 470)
    }

    private var heroCandidates: [URL] {
        var urls: [URL] = []
        if let b = movie.backdropURL, let u = URL(string: b) { urls.append(u) }
        urls.append(contentsOf: movie.posterCandidates)
        return urls
    }

    private var metaLine: String {
        var parts: [String] = []
        if movie.year > 0 { parts.append(String(movie.year)) }
        parts.append(movie.formattedRuntime)
        let genres = movie.genre.prefix(3).map { $0.shortTitle }
        if !genres.isEmpty { parts.append(genres.joined(separator: " • ")) }
        return parts.joined(separator: "  |  ")
    }
}

// MARK: - View All grid (sheet)

struct ViewAllGrid: View {
    let title: String
    let movies: [FreeMovie]
    let onSelect: (FreeMovie) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var library = MovieLibraryService.shared
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)],
                    spacing: 18
                ) {
                    ForEach(movies) { movie in
                        HuluMovieCard(
                            movie: movie,
                            isInMyList: library.isInMyList(movie.id),
                            onTap: { onSelect(movie) },
                            onToggleList: { library.toggleMyList(movie, userId: appState.currentUser?.id) }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(red: 13/255, green: 14/255, blue: 17/255).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
