import SwiftUI

// MARK: - Profile Playlists View
struct ProfilePlaylistsView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { index in
                ProfilePlaylistCard(
                    title: "My Playlist \(index + 1)",
                    videoCount: Int.random(in: 5...25),
                    thumbnailURL: "https://picsum.photos/400/300?random=\(index + 10)"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Playlist Card
struct ProfilePlaylistCard: View {
    let title: String
    let videoCount: Int
    let thumbnailURL: String
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(videoCount) videos")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}
