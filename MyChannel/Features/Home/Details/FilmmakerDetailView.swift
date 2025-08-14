import SwiftUI

struct FilmmakerDetailView: View {
    let name: String
    let films: [FreeMovie]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMovie: FreeMovie?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    filmography
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(item: $selectedMovie) { m in
                MovieDetailView(movie: m)
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.black.opacity(0.75), Color.black.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 260)
            .overlay(
                Group {
                    if let poster = films.first?.posterCandidates.first {
                        AppAsyncImage(url: poster) { img in
                            img.resizable().scaledToFill().opacity(0.35).blur(radius: 10)
                        } placeholder: { Color.clear }
                    }
                }
            )
            
            VStack(alignment: .leading, spacing: 10) {
                Text(name)
                    .foregroundStyle(.white)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Curated filmography • \(films.count) films")
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(16)
        }
    }
    
    private var filmography: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Films")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 16) {
                ForEach(films) { movie in
                    Button {
                        selectedMovie = movie
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            MultiSourceAsyncImage(urls: movie.posterCandidates) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            Text(movie.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

#Preview("Filmmaker Detail") {
    FilmmakerDetailView(
        name: "A. Rivers",
        films: Array(FreeMovie.sampleMovies.prefix(8))
    )
}