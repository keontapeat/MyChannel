//
//  SubscriptionVideoCard.swift
//  MyChannel
//
//  YouTube-style subscription video card (grid layout)
//

import SwiftUI

struct SubscriptionVideoCard: View {
    let video: Video
    var progress: Double = 0
    var isNew: Bool = false
    var onMore: () -> Void = {}
    var onOpenChannel: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            ZStack(alignment: .bottom) {
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
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Top-row badges (LIVE / NEW)
                VStack {
                    HStack {
                        if isNew && !video.isLiveStream {
                            Text("NEW")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.Colors.primary))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
                
                // Bottom-trailing duration / live badge
                HStack {
                    Spacer()
                    if video.isLiveStream {
                        HStack(spacing: 4) {
                            Circle().fill(Color.white).frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                    } else if video.duration > 0 {
                        Text(formatDuration(video.duration))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.8)))
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                
                // Continue-watching progress bar
                if progress > 0.01 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.black.opacity(0.35))
                            Rectangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: geo.size.width * min(1, progress))
                        }
                    }
                    .frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
            .frame(height: 200)
            
            // Creator info & video details
            HStack(alignment: .top, spacing: 12) {
                // Creator avatar
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onOpenChannel()
                }) {
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
                }
                .buttonStyle(.plain)
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Creator name + verified
                    HStack(spacing: 5) {
                        Text(video.creator.displayName)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                        if video.creator.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // Metadata
                    HStack(spacing: 4) {
                        Text("\(video.formattedViewCount) views")
                        Text("•")
                        Text(video.timeAgo)
                    }
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                }
                
                Spacer()
                
                // More options
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onMore()
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
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
    SubscriptionVideoCard(video: Video.sampleVideos[0], progress: 0.35, isNew: true)
        .padding()
        .background(AppTheme.Colors.background)
}
