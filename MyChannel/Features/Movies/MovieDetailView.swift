import SwiftUI
import AVKit
import UIKit

// MARK: - MovieDetailView
struct MovieDetailView: View {
    let movie: FreeMovie

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showPlayer = false
    @State private var showTrailerPlayer = false
    @State private var video: Video?
    @State private var isWatchlisted = false
    @State private var showUnavailableAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var showFullOverview = false
    
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
        .fullScreenCover(isPresented: $showPlayer) {
            if let video {
                // Use the immersive fullscreen that reuses the Global player
                ImmersiveFullscreenPlayerView(video: video) {
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
        ZStack(alignment: .bottom) {
            heroParallaxBackground(geometry: geometry)
            heroGradientOverlay
            heroContentInfo
        }
        .frame(height: headerHeight)
        .background(GeometryReader { proxy in
            Color.clear.preference(
                key: AScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("scroll")).minY
            )
        })
    }
    
    // MARK: - Hero Parallax Background
    private func heroParallaxBackground(geometry: GeometryProxy) -> some View {
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
    
    // MARK: - Hero Gradient Overlay
    private var heroGradientOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.4),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.8),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Hero Content Info
    private var heroContentInfo: some View {
        VStack(spacing: 20) {
            Spacer()
            
            HStack(alignment: .bottom, spacing: 16) {
                heroPosterCard
                heroMovieInfo
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Hero Poster Card
    private var heroPosterCard: some View {
        MultiSourceAsyncImage(
            urls: movie.posterCandidates,
            content: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: posterWidth, height: posterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            },
            placeholder: {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: posterWidth, height: posterHeight)
                    .overlay(
                        Image(systemName: "film.stack")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .shimmer(active: true)
            }
        )
        .scaleEffect(max(0.8, 1 - scrollOffset * 0.001))
        .animation(AppTheme.AnimationPresets.spring, value: scrollOffset)
    }
    
    // MARK: - Hero Movie Info
    private var heroMovieInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(movie.title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(2)
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
            
            HStack(spacing: 8) {
                movieInfoChip(movie.rating, color: .red, icon: "exclamationmark.triangle.fill")
                movieInfoChip("\(movie.year)", color: .blue, icon: "calendar")
                movieInfoChip(movie.formattedRuntime, color: .green, icon: "clock.fill")
            }
            
            movieRatingSection
        }
    }
    
    // MARK: - Movie Rating Section
    private var movieRatingSection: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                Image(systemName: "star.fill")
                    .foregroundColor(
                        index < Int(movie.imdbRating / 2) ? .yellow : .white.opacity(0.3)
                    )
                    .font(.system(size: 14))
            }
            Text("\(movie.imdbRating, specifier: "%.1f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text("IMDb")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.yellow.opacity(0.2), in: Capsule())
        }
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
        Button(action: { 
            withAnimation(AppTheme.AnimationPresets.bouncy) {
                isWatchlisted.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Image(systemName: isWatchlisted ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isWatchlisted ? .red : .white)
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
                movieOverviewSection
            }
            
            movieDetailsGrid
            
            if !movie.cast.isEmpty {
                movieCastSection
            }
            
            if !movie.genre.isEmpty {
                movieGenresSection
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
    
    // MARK: - Main Action Buttons
    private var mainActionButtons: some View {
        HStack(spacing: 16) {
            primaryPlayButton
            
            if movie.trailerURL != nil {
                trailerButton()
            }
            
            shareButton
        }
    }
    
    // MARK: - Primary Play Button
    private var primaryPlayButton: some View {
        Button(action: playAction) {
            let isDirect = MoviePlaybackResolver.directPlayableURL(for: movie) != nil
            let title = isDirect ? "Play Now" : "Play Trailer"
            let icon = "play.fill"
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
    
    // MARK: - Trailer Button
    private func trailerButton() -> some View {
        Button {
            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                showTrailerPlayer = true
            }
        } label: {
            Image(systemName: "play.rectangle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    // MARK: - Share Button
    private var shareButton: some View {
        Button(action: shareAction) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PressableScaleStyle())
    }
    
    // MARK: - Movie Overview Section
    private var movieOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Synopsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(movie.overview)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(showFullOverview ? nil : 4)
                .animation(AppTheme.AnimationPresets.easeInOut, value: showFullOverview)
            
            if movie.overview.count > 200 {
                overviewToggleButton
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Overview Toggle Button
    private var overviewToggleButton: some View {
        Button(showFullOverview ? "Show Less" : "Show More") {
            withAnimation(AppTheme.AnimationPresets.spring) {
                showFullOverview.toggle()
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.Colors.primary)
    }
    
    // MARK: - Movie Details Grid
    private var movieDetailsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                movieDetailCard("Director", movie.director.isEmpty ? "Unknown" : movie.director, "person.fill")
                movieDetailCard("Language", movie.language, "globe")
                movieDetailCard("Country", movie.country, "flag.fill")
                movieDetailCard("Source", movie.streamingSource.displayName, "tv.fill")
            }
        }
    }
    
    // MARK: - Movie Cast Section
    private var movieCastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(movie.cast.prefix(10), id: \.self) { actor in
                        castMemberCard(actor: actor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Cast Member Card
    private func castMemberCard(actor: String) -> some View {
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
    }
    
    // MARK: - Movie Genres Section
    private var movieGenresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genres")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            FlowLayout(movie.genre.map { $0.displayName }, spacing: 8) { genre in
                genreChip(genre: genre)
            }
        }
    }
    
    // MARK: - Genre Chip
    private func genreChip(genre: String) -> some View {
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
    }
    
    // MARK: - Movie Info Chip Helper
    private func movieInfoChip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.3), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Movie Detail Card Helper
    private func movieDetailCard(_ title: String, _ value: String, _ icon: String) -> some View {
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
    }
    
    // MARK: - Setup Methods
    private func setupVideo() {
        if video == nil {
            video = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser)
        }
    }
    
    // MARK: - Action Methods
    private func playAction() {
        if let directVideo = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser) {
            // Hand off the player used in detail to the global one for fullscreen playback
            video = directVideo
            let vm = VideoPlayerManager()
            vm.setupPlayer(with: directVideo)
            vm.play() // autoplay before adopting so global state reflects Playing
            GlobalVideoPlayerManager.shared.adoptExternalPlayerManager(vm, video: directVideo, showFullscreen: true)
            showPlayer = true
        } else {
            // Prefer in-app trailer playback
            if movie.trailerURL != nil {
                showTrailerPlayer = true
            } else if URL(string: movie.streamURL) != nil {
                showUnavailableAlert = true
            } else {
                showUnavailableAlert = true
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func shareAction() {
        // Implement sharing functionality
        let activityViewController = UIActivityViewController(
            activityItems: [
                movie.title,
                "Check out this movie: \(movie.title)",
                URL(string: movie.trailerURL ?? "https://archive.org")
            ].compactMap { $0 },
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Flow Layout Component
struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(_ data: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }
    
    // MARK: - Flow Layout Body
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
    
    // MARK: - Flow Layout Computation Methods
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
        let rows = computeRows(1000) // Use large width for row calculation
        return CGFloat(rows.count) * 40 + CGFloat(max(0, rows.count - 1)) * spacing
    }
    
    private func itemSize(_ item: Data.Element) -> CGSize {
        // Estimate size - you might want to make this more sophisticated
        return CGSize(width: 100, height: 40)
    }
}

// MARK: - Preview
#Preview("Movie Detail") {
    MovieDetailView(movie: FreeMovie.sampleMovies.first!)
        .environmentObject(AppState())
}