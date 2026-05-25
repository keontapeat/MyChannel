//
//  SubscriptionVideoCard.swift
//  MyChannel
//
//  YouTube-style subscription video card
//

import SwiftUI

struct SubscriptionVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Duration badge
                if video.duration > 0 {
                    Text(formatDuration(video.duration))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                        )
                        .padding(8)
                }
            }
            
            // Creator info & video details
            HStack(alignment: .top, spacing: 12) {
                // Creator avatar
                CachedAsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Creator name
                    Text(video.creator.displayName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    // Metadata
                    HStack(spacing: 4) {
                        Text("\(video.formattedViewCount) views")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("•")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(video.timeAgo)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // More options
                Button(action: {
                    // Show options menu
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    SubscriptionVideoCard(video: Video.sampleVideos[0])
        .padding()
        .background(AppTheme.Colors.background)
}

