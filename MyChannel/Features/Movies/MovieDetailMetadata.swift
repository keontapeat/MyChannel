import SwiftUI

// MARK: - Movie Detail Metadata (extracted from MovieDetailView)

struct MovieDetailOverviewSection: View {
    let overview: String
    @Binding var showFullOverview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Synopsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(overview)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(showFullOverview ? nil : 4)
                .animation(AppTheme.AnimationPresets.easeInOut, value: showFullOverview)

            if overview.count > 200 {
                Button(showFullOverview ? "Show Less" : "Show More") {
                    withAnimation(AppTheme.AnimationPresets.spring) {
                        showFullOverview.toggle()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .accessibilityLabel(showFullOverview ? "Show less synopsis" : "Show more synopsis")
            }
        }
        .padding(.vertical, 8)
    }
}

struct MovieDetailMetadataGrid: View {
    let movie: FreeMovie

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MovieDetailMetadataCard("Director", movie.director.isEmpty ? "Unknown" : movie.director, "person.fill")
                MovieDetailMetadataCard("Language", movie.language, "globe")
                MovieDetailMetadataCard("Country", movie.country, "flag.fill")
                MovieDetailMetadataCard("Source", movie.streamingSource.displayName, "tv.fill")
            }
        }
    }
}

struct MovieDetailCastSection: View {
    let cast: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cast.prefix(10), id: \.self) { actor in
                        MovieDetailCastCard(actor: actor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct MovieDetailCastCard: View {
    let actor: String

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 24))
                )

            Text(actor)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cast member \(actor)")
    }
}

struct MovieDetailGenresSection: View {
    let genres: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genres")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            MovieFlowLayout(genres, spacing: 8) { genre in
                MovieDetailGenreChip(genre: genre)
            }
        }
    }
}

struct MovieDetailGenreChip: View {
    let genre: String

    var body: some View {
        Text(genre)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            .accessibilityLabel("Genre \(genre)")
    }
}

struct MovieDetailMetadataCard: View {
    let title: String
    let value: String
    let icon: String

    init(_ title: String, _ value: String, _ icon: String) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Movie Flow Layout Component

struct MovieFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    init(_ data: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(computeRows(geometry.size.width), id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { item in
                            content(item)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(height: computeHeight())
    }

    private func computeRows(_ availableWidth: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var currentRow: [Data.Element] = []
        var currentWidth: CGFloat = 0

        for item in data {
            let itemWidth = itemSize(item).width + spacing

            if currentWidth + itemWidth > availableWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [item]
                currentWidth = itemWidth
            } else {
                currentRow.append(item)
                currentWidth += itemWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func computeHeight() -> CGFloat {
        let rows = computeRows(1000)
        return CGFloat(rows.count) * 40 + CGFloat(max(0, rows.count - 1)) * spacing
    }

    private func itemSize(_ item: Data.Element) -> CGSize {
        CGSize(width: 100, height: 40)
    }
}
