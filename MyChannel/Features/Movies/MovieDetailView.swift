import SwiftUI
import AVKit
import UIKit

struct MovieDetailView: View {
    let movie: FreeMovie

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showPlayer = false
    @State private var video: Video?
    @State private var isWatchlisted = false
    @State private var showUnavailableAlert = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            backgroundHero

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBar

                    Spacer(minLength: 160)

                    titleBlock

                    actionButtons

                    metaChips

                    if !movie.overview.isEmpty {
                        sectionHeader("About the movie")
                        Text(movie.overview)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !movie.cast.isEmpty {
                        sectionHeader("Cast")
                        flowChips(movie.cast)
                    }

                    if !movie.genre.isEmpty {
                        sectionHeader("Genres")
                        flowChips(movie.genre.map { $0.displayName })
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .background(Color.clear)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // Prepare direct video only (no redirection)
            if video == nil {
                video = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser)
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let video {
                ModernVideoPlayerView(video: video)
                    .background(Color.black.ignoresSafeArea())
                    .preferredColorScheme(.dark)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .alert("Stream Unavailable", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This title doesn’t have a direct in-app stream yet.")
        }
    }

    private var backgroundHero: some View {
        ZStack(alignment: .top) {
            // Dark, cinematic header with robust fallbacks (no white placeholders)
            AsyncImage(url: URL(string: movie.backdropURL ?? movie.posterURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    LinearGradient(
                        colors: [.black, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                case .failure(_):
                    LinearGradient(
                        colors: [.black, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                @unknown default:
                    LinearGradient(
                        colors: [.black, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 320, alignment: .top)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 220)
            .allowsHitTesting(false)

            LinearGradient(
                colors: [.clear, .black],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 420)
            .allowsHitTesting(false)
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            Spacer()
            Text("Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Button {
                isWatchlisted.toggle()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                Image(systemName: isWatchlisted ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 40)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: URL(string: movie.posterURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.white.opacity(0.08))
                }
                .frame(width: 92, height: 138)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        ratingChip(movie.rating)
                        infoChip("\(movie.year)")
                        infoChip(movie.formattedRuntime)
                        imdbChip(movie.imdbRating)
                    }
                }
                Spacer()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if let directVideo = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser) {
                    video = directVideo
                    showPlayer = true
                } else {
                    showUnavailableAlert = true
                }
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Play")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.white)
                .cornerRadius(10)
            }

            if let trailer = movie.trailerURL, let url = URL(string: trailer) {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "film")
                        Text("Trailer")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.15))
                    .cornerRadius(10)
                }
            }
        }
    }

    private var metaChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(movie.genre.prefix(3)), id: \.self) { g in
                Text(g.displayName.replacingOccurrences(of: "🎬 ", with: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12))
                    .cornerRadius(16)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.top, 10)
    }

    private func flowChips(_ items: [String]) -> some View {
        FlexibleView(data: items, spacing: 8, alignment: .leading) { item in
            Text(item)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08))
                .cornerRadius(12)
        }
    }

    private func ratingChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.2))
            .cornerRadius(4)
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.12))
            .cornerRadius(4)
    }

    private func imdbChip(_ score: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            Text(String(format: "%.1f", score))
                .fontWeight(.semibold)
        }
        .font(.system(size: 12))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.orange.opacity(0.25))
        .cornerRadius(6)
    }
}

// Flexible layout helper
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { element in
                        content(element)
                    }
                }
            }
        }
    }

    private var rows: [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRowWidth: CGFloat = 0
        let maxWidth = UIScreen.main.bounds.width - 32

        for element in data {
            let item = UIHostingController(rootView: content(element)).view!
            let size = item.systemLayoutSizeFitting(CGSize(width: UIView.layoutFittingCompressedSize.width, height: UIView.layoutFittingCompressedSize.height))
            let itemWidth = size.width + spacing

            if currentRowWidth + itemWidth > maxWidth {
                rows.append([element])
                currentRowWidth = itemWidth
            } else {
                rows[rows.count - 1].append(element)
                currentRowWidth += itemWidth
            }
        }
        return rows
    }
}

#Preview("Movie Detail") {
    MovieDetailView(movie: FreeMovie.sampleMovies.first!)
        .environmentObject(AppState())
}