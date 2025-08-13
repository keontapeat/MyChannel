import Foundation
import SwiftUI

@MainActor
final class MoviesViewModel: ObservableObject {
    @Published var movies: [FreeMovie] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func loadPopular() async {
        guard error == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await TMDBService.shared.fetchPopularWithTrailersUS(page: 1, limit: 40)
            // Keep only items that actually have a trailer
            movies = list.filter { $0.trailerURL != nil }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

struct MoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MoviesViewModel()
    @State private var selectedMovie: FreeMovie?
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 14, alignment: .top)
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                if let error = vm.error {
                    errorState(message: error)
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            if vm.movies.isEmpty {
                await vm.loadPopular()
            }
        }
        .fullScreenCover(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(vm.movies) { movie in
                        TrailerPosterCard(movie: movie) {
                            selectedMovie = movie
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                if vm.isLoading {
                    ProgressView("Loading popular trailers…")
                        .padding(.vertical, 24)
                }
                
                Color.clear.frame(height: 16)
            }
            .refreshable {
                await vm.loadPopular()
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .buttonStyle(PressableScaleStyle())
            
            Spacer()
            
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Movies")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                Text("\(vm.movies.count) popular trailers")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Button {
                Task { await vm.loadPopular() }
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.Colors.primary)
            Text("Unable to load movies")
                .font(.title3.bold())
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await vm.loadPopular() }
            }
            .buttonStyle(TabErrorButtonStyle())
        }
        .padding()
    }
}

private struct TrailerPosterCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    MultiSourceAsyncImage(
                        urls: movie.posterCandidates,
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                        },
                        placeholder: {
                            SkeletonView()
                        }
                    )
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.Colors.divider.opacity(0.6), lineWidth: 0.8)
                    )
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    trailerRibbon
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()
                        Text(movie.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 10))
                            Text("\(movie.imdbRating, specifier: "%.1f") • \(movie.year)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.97))
        .contentShape(Rectangle())
        .accessibilityLabel("\(movie.title) trailer")
        .accessibilityHint("Double tap to watch trailer")
    }
    
    private var trailerRibbon: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("TRAILER")
                .font(.system(size: 11, weight: .heavy))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.white)
        .background(AppTheme.Colors.primary, in: Capsule())
        .padding(8)
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

#Preview("Movies - Popular Trailers") {
    MoviesView()
        .preferredColorScheme(.light)
        .environmentObject(AppState())
}