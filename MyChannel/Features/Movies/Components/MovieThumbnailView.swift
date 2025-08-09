import SwiftUI

struct MovieThumbnailView: View {
    let movie: FreeMovie
    let itemWidth: CGFloat
    let posterHeight: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                poster
                gradientOverlay
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    HStack(spacing: 6) {
                        chip(text: "HD")
                        chip(text: "\(movie.year)")
                    }
                }
                .padding(8)
                
                HStack {
                    Spacer()
                    badge
                }
                .padding(6)
            }
            .frame(width: itemWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.Colors.divider.opacity(0.6), lineWidth: 0.8)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: itemWidth, alignment: .leading)
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text("\(movie.imdbRating, specifier: "%.1f")")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer(minLength: 0)
                }
                .frame(width: itemWidth, alignment: .leading)
            }
        }
        .frame(width: itemWidth)
        .contentShape(Rectangle())
    }
    
    private var poster: some View {
        MultiSourceAsyncImage(
            urls: movie.posterCandidates,
            content: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: itemWidth, height: posterHeight)
                    .clipped()
                    .transition(.opacity.combined(with: .scale))
            },
            placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: itemWidth, height: posterHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "film").foregroundColor(AppTheme.Colors.textTertiary))
                    )
                    .shimmer(active: true)
            }
        )
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: itemWidth, height: posterHeight)
        .allowsHitTesting(false)
    }
    
    private var badge: some View {
        Text("MC")
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppTheme.Colors.primary, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
    }
    
    private func chip(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.15), in: Capsule())
    }
}

#Preview("Movie Thumbnail") {
    MovieThumbnailView(movie: FreeMovie.sampleMovies.first!, itemWidth: 120, posterHeight: 180)
        .padding()
        .background(AppTheme.Colors.background)
}