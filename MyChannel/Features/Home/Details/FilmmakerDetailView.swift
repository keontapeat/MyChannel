import SwiftUI

struct FilmmakerDetailView: View {
    let name: String
    let films: [FreeMovie]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    private var columns: [GridItem] {
        let count = (hSize == .compact) ? 3 : 6
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(films) { movie in
                            MinimalMovieCard(movie: movie) {
                                MovieDetailView(movie: movie)
                                    .presentAsSheet()
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: films.count)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(.systemGray6))
                Image(systemName: "video.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(films.count) films")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Button {
                    } label: {
                        Text("Follow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.blue))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }
}

private extension View {
    func presentAsSheet() { }
}

#Preview("FilmmakerDetailView") {
    FilmmakerDetailView(
        name: "A. Rivers",
        films: Array(FreeMovie.sampleMovies.prefix(10))
    )
    .preferredColorScheme(.light)
}