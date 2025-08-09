import SwiftUI

// MARK: - Premium Movies Hub Section
struct PremiumMoviesHubSection: View {
    let onMovieTap: (FreeMovie) -> Void
    
    @State private var selectedGenre: FreeMovie.MovieGenre = .action
    @State private var isShowingAllMovies: Bool = false
    
    private var movies: [FreeMovie] {
        FreeMovie.sampleMovies
    }
    
    private var filteredMovies: [FreeMovie] {
        movies.filter { $0.genre.contains(selectedGenre) }
    }
    
    private var featuredMovie: FreeMovie? {
        movies.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎬 MyChannel Movies")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Exclusive Library • Premium Quality")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button("See All") {
                    isShowingAllMovies = true
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            // Featured Movie Hero Banner
            if let featured = featuredMovie {
                FeaturedMovieBanner(movie: featured) {
                    onMovieTap(featured)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            
            // Streaming Sources
            StreamingSourcesRow()
                .padding(.horizontal, AppTheme.Spacing.md)
            
            // Genre Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FreeMovie.MovieGenre.allCases.prefix(8), id: \.self) { genre in
                        GenreChip(
                            genre: genre,
                            isSelected: selectedGenre == genre,
                            movieCount: movies.filter { $0.genre.contains(genre) }.count
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedGenre = genre
                            }
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            
            // Movie Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(filteredMovies.prefix(8)) { movie in
                        PremiumMovieCard(movie: movie) {
                            onMovieTap(movie)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.background.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .fullScreenCover(isPresented: $isShowingAllMovies) {
            FreeMoviesView()
        }
    }
}

// MARK: - Featured Movie Banner
struct FeaturedMovieBanner: View {
    let movie: FreeMovie
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Image
                AsyncImage(url: URL(string: movie.backdropURL ?? movie.posterURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure(_):
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    case .empty:
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
                .clipped()
                
                // Gradient Overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content Overlay
                VStack(alignment: .leading) {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            // MyChannel Original Badge
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("MyChannel Original")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary.opacity(0.9))
                            )
                            
                            // Movie Title
                            Text(movie.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            // Movie Info
                            HStack(spacing: 8) {
                                Text(movie.rating)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.white.opacity(0.2))
                                    )
                                
                                Text("⭐ \(movie.imdbRating, specifier: "%.1f")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(movie.formattedRuntime)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("\(movie.year)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            // Genre Tags
                            HStack(spacing: 6) {
                                ForEach(Array(movie.genre.prefix(3)), id: \.self) { genre in
                                    Text(genre.rawValue.capitalized)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.2))
                                        )
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Play Button
                        VStack(spacing: 8) {
                            Button(action: action) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                            
                            Text("WATCH")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Colors.primary)
                                )
                        }
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.1),
            radius: 12,
            x: 0,
            y: 4
        )
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Streaming Sources Row
struct StreamingSourcesRow: View {
    private let sources = FreeMovie.StreamingSource.allCases
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 MyChannel Originals")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Replace streaming sources with MyChannel categories
                    MyChannelCategoryChip(title: "🔥 Trending", color: .red)
                    MyChannelCategoryChip(title: "⭐ Top Rated", color: .yellow)
                    MyChannelCategoryChip(title: "🆕 New Releases", color: .blue)
                    MyChannelCategoryChip(title: "🎬 Blockbusters", color: .purple)
                    MyChannelCategoryChip(title: "🏆 Award Winners", color: .green)
                }
            }
        }
    }
}

// MARK: - MyChannel Category Chip
struct MyChannelCategoryChip: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Genre Chip
struct GenreChip: View {
    let genre: FreeMovie.MovieGenre
    let isSelected: Bool
    let movieCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(genreDisplayName(for: genre))
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("(\(movieCount))")
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                
                if isSelected {
                    Rectangle()
                        .fill(.white)
                        .frame(height: 2)
                        .cornerRadius(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        AppTheme.Colors.gradient
                    } else {
                        AppTheme.Colors.surface
                    }
                    
                    if isPressed {
                        Color.black.opacity(0.1)
                    }
                }
            )
            .cornerRadius(AppTheme.CornerRadius.md)
            .shadow(
                color: isSelected ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private func genreDisplayName(for genre: FreeMovie.MovieGenre) -> String {
        switch genre {
        case .action: return "🎬 Action"
        case .comedy: return "😂 Comedy"
        case .drama: return "🎭 Drama"
        case .horror: return "👻 Horror"
        case .thriller: return "😱 Thriller"
        case .romance: return "💕 Romance"
        case .scifi: return "🚀 Sci-Fi"
        case .fantasy: return "🧙‍♂️ Fantasy"
        case .documentary: return "📽️ Documentary"
        case .animation: return "🎨 Animation"
        case .crime: return "🔍 Crime"
        case .mystery: return "🕵️ Mystery"
        case .adventure: return "🗺️ Adventure"
        case .family: return "👨‍👩‍👧‍👦 Family"
        case .western: return "🤠 Western"
        case .war: return "⚔️ War"
        case .musical: return "🎵 Musical"
        case .biography: return "📚 Biography"
        }
    }
}

// MARK: - Premium Movie Card
struct PremiumMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: {
            print("🎬 MOVIE CLICKED: \(movie.title)")
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .center) {
                    AsyncImage(url: URL(string: movie.posterURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        case .failure(_):
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "film.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                )
                        case .empty:
                            SkeletonView()
                                .aspectRatio(2/3, contentMode: .fill)
                                .cornerRadius(12)
                        @unknown default:
                            Color.clear
                        }
                    }
                    .frame(width: 140, height: 210)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
                    
                    // Play overlay
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .opacity(isPressed ? 1.0 : 0.9)
                    
                    // Badges and meta
                    VStack {
                        HStack {
                            Spacer()
                            Text("MC")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Colors.primary)
                                        .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: 3, x: 0, y: 1)
                                )
                        }
                        .padding(6)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text("\(movie.imdbRating, specifier: "%.1f")")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.7)))
                            
                            Text(movie.formattedRuntime)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.7)))
                        }
                        .padding(8)
                    }
                    .frame(width: 140, height: 210)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
                    HStack(spacing: 4) {
                        Text("\(movie.year)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("HD")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    HStack(spacing: 4) {
                        ForEach(Array(movie.genre.prefix(2)), id: \.self) { genre in
                            Text(genre.rawValue.capitalized)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Colors.surface)
                                )
                        }
                        Spacer()
                    }
                }
                .frame(width: 140)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(movie.title)
        .accessibilityHint("Double tap to watch movie")
    }
}

#Preview {
    PremiumMoviesHubSection { movie in
        print("Selected movie: \(movie.title)")
    }
    .environmentObject(AppState())
}