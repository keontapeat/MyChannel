import SwiftUI

// MARK: - Profile Shorts View
struct ProfileShortsView: View {
    let videos: [Video]
    let user: User
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ], spacing: 8) {
            ForEach(videos.prefix(12)) { video in
                ProfileShortCard(video: video)
                    .onTapGesture {
                        HapticManager.shared.impact(style: .light)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Short Card
struct ProfileShortCard: View {
    let video: Video
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = URL(string: video.thumbnailURL), !video.thumbnailURL.isEmpty {
                    AppAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(9/16, contentMode: .fill)
                            .clipped()
                    } placeholder: { shortPlaceholder }
                } else {
                    shortPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                    
                    ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.1), radius: 3, x: 0, y: 1)
        .contextMenu {
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Save to Watch Later", systemImage: "bookmark")
            }
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityLabel("\(video.title) short")
    }
    
    private var shortPlaceholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.textTertiary.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
            .overlay(
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            )
    }
}
