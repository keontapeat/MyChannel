import SwiftUI
import AVKit
import UIKit

// MARK: - MovieDetailView
struct MovieDetailView: View {
    let movie: FreeMovie

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject var library = MovieLibraryService.shared
    @State var showPlayer = false
    @State var showTrailerPlayer = false
    @State var video: Video?
    @State var isWatchlisted = false
    @State var showUnavailableAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var showFullOverview = false
    @State var resumeProgress: Double = 0
    
    private let headerHeight: CGFloat = 400
    private let posterWidth: CGFloat = 110
    private let posterHeight: CGFloat = 165

    // MARK: - Main Body
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        heroSection(geometry: geometry)
                        contentSection
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(AScrollOffsetPreferenceKey.self) { value in
                    withAnimation(.easeOut(duration: 0.1)) {
                        scrollOffset = value
                        headerOpacity = min(1, max(0, (value - 100.0) / 100.0))
                    }
                }
                
                floatingHeader
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .top)
        .onAppear(perform: setupVideo)
        .task { await loadResumeAndList() }
        .fullScreenCover(isPresented: $showPlayer) {
            if let video {
                // Use the immersive fullscreen that reuses the Global player
                ImmersiveFullscreenPlayerView(video: video) {
                    // Capture resume progress before tearing the player down.
                    recordProgressFromPlayer()
                    // Stop audio and fully dismiss fullscreen
                    GlobalVideoPlayerManager.shared.closePlayer()
                    GlobalVideoPlayerManager.shared.showingFullscreen = false
                    showPlayer = false
                }
                .background(Color.black.ignoresSafeArea())
                .preferredColorScheme(.dark)
            }
        }
        .fullScreenCover(isPresented: $showTrailerPlayer) {
            if let t = movie.trailerURL {
                TrailerPlayerView(trailerURLString: t) {
                    showTrailerPlayer = false
                }
                .preferredColorScheme(.dark)
            }
        }
        .alert("Stream Unavailable", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This title doesn't have a direct in-app stream yet.")
        }
    }
    
    // MARK: - Hero Section
    private func heroSection(geometry: GeometryProxy) -> some View {
        MovieDetailHero(
            movie: movie,
            geometry: geometry,
            headerHeight: headerHeight,
            scrollOffset: scrollOffset,
            posterWidth: posterWidth,
            posterHeight: posterHeight,
            isWatchlisted: isWatchlisted,
            onToggleWatchlist: {
                toggleWatchlist()
            },
            onPlayTrailer: {
                HapticManager.shared.impact(style: .medium)
                showTrailerPlayer = true
            }
        )
    }
    
    // MARK: - Floating Header
    private var floatingHeader: some View {
        VStack(spacing: 0) {
            HStack {
                floatingBackButton
                
                Spacer()
                
                floatingHeaderTitle
                
                Spacer()
                
                floatingWatchlistButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 10)
            .background(
                .ultraThinMaterial
                    .opacity(headerOpacity)
            )
            
            Spacer()
        }
    }
    
    // MARK: - Floating Back Button
    private var floatingBackButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    // MARK: - Floating Header Title
    private var floatingHeaderTitle: some View {
        Text(movie.title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .opacity(headerOpacity)
    }
    
    // MARK: - Floating Watchlist Button
    private var floatingWatchlistButton: some View {
        Button(action: { toggleWatchlist() }) {
            Image(systemName: isWatchlisted ? "checkmark" : "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isWatchlisted ? AppTheme.Colors.primary : .white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            mainActionButtons

            if !movie.overview.isEmpty {
                MovieDetailOverviewSection(overview: movie.overview, showFullOverview: $showFullOverview)
            }

            MovieDetailMetadataGrid(movie: movie)

            if !movie.cast.isEmpty {
                MovieDetailCastSection(cast: movie.cast)
            }

            if !movie.genre.isEmpty {
                MovieDetailGenresSection(genres: movie.genre.map { $0.displayName })
            }

            Color.clear.frame(height: 40)
        }
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func toggleWatchlist() {
        let nowSaved = library.toggleMyList(movie, userId: appState.currentUser?.id)
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            isWatchlisted = nowSaved
        }
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Preview
#Preview("Movie Detail") {
    MovieDetailView(movie: FreeMovie.sampleMovies.first!)
        .environmentObject(AppState())
}