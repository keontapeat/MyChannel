//
//  SubscriptionVideoListRow.swift
//  MyChannel
//
//  YouTube-style compact list row for the subscriptions feed (List layout).
//

import SwiftUI

struct SubscriptionVideoListRow: View {
    let video: Video
    var progress: Double = 0
    var isNew: Bool = false
    var onMore: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail with duration + progress bar
            ZStack(alignment: .bottom) {
                CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(ProgressView())
                }
                .frame(width: 160, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Live / duration badge
                HStack {
                    Spacer()
                    if video.isLiveStream {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                    } else if video.duration > 0 {
                        Text(formatDuration(video.duration))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.8)))
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .bottomTrailing)
                
                // Progress bar (continue watching)
                if progress > 0.01 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                            Rectangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: geo.size.width * min(1, progress))
                        }
                    }
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            }
            .frame(width: 160, height: 90)
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    if video.creator.shouldShowVerificationBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                HStack(spacing: 4) {
                    if isNew {
                        Text("NEW")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.15)))
                    }
                    Text("\(video.formattedViewCount) views • \(video.timeAgo)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
            
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    VStack {
        SubscriptionVideoListRow(video: Video.sampleVideos[0], progress: 0.4, isNew: true)
        SubscriptionVideoListRow(video: Video.sampleVideos[1])
    }
    .padding()
    .background(AppTheme.Colors.background)
}
