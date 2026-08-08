import SwiftUI

// MARK: - More Like This
// Recommends catalog titles that share a genre with the current movie so viewers
// keep browsing without leaving the detail screen. Ranks by number of shared
// genres, then IMDb rating. Pure-logic ranking is precomputed off `body`.
struct MovieDetailRelatedSection: View {
    let movie: FreeMovie
    let onSelect: (FreeMovie) -> Void

    private let related: [FreeMovie]

    init(movie: FreeMovie, onSelect: @escaping (FreeMovie) -> Void) {
        self.movie = movie
        self.onSelect = onSelect
        self.related = Self.computeRelated(for: movie)
    }

    var body: some View {
        if related.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("More Like This")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(related) { item in
                            Button {
                                HapticManager.shared.impact(style: .light)
                                onSelect(item)
                            } label: {
                                MovieThumbnailView(movie: item, itemWidth: 124, posterHeight: 186)
                            }
                            .buttonStyle(PressableScaleStyle())
                            .accessibilityLabel("Open \(item.title)")
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Ranking
    private static func computeRelated(for movie: FreeMovie, limit: Int = 12) -> [FreeMovie] {
        let currentGenres = Set(movie.genre)
        guard !currentGenres.isEmpty else { return [] }

        let scored: [(movie: FreeMovie, shared: Int)] = FreeMovie.sampleMovies
            .compactMap { candidate in
                guard candidate.id != movie.id else { return nil }
                let shared = currentGenres.intersection(Set(candidate.genre)).count
                guard shared > 0 else { return nil }
                return (candidate, shared)
            }

        return scored
            .sorted { lhs, rhs in
                if lhs.shared != rhs.shared { return lhs.shared > rhs.shared }
                return lhs.movie.imdbRating > rhs.movie.imdbRating
            }
            .prefix(limit)
            .map { $0.movie }
    }
}
