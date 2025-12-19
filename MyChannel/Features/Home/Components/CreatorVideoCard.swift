//
//  CreatorVideoCard.swift
//  MyChannel
//
//  YouTube-style video card for creator content
//  Extracted from HomeView for better code organization
//

import SwiftUI

// MARK: - Creator Video Card (YouTube-Style)
struct CreatorVideoCard: View {
    let video: Video
    let onPlay: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onPlay()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    MultiSourceAsyncImage(
                        urls: video.posterCandidates,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 112)
                                .clipped()
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                )
                        }
                    )
                    .frame(width: 200, height: 112)
                    .cornerRadius(12)
                    
                    // Duration badge
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(6)
                }
                
                // Video info
                HStack(alignment: .top, spacing: 10) {
                    // Creator avatar
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Text(video.creator.displayName.prefix(1).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(video.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 4) {
                            Text(video.creator.displayName)
                            if video.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        
                        Text("\(formatViewCount(video.viewCount)) views • \(video.uploadTimeAgo)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 200, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }) { }
        .accessibilityLabel("Video: \(video.title) by \(video.creator.displayName)")
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Preview
#Preview {
    CreatorVideoCard(
        video: Video.sampleVideos.first!,
        onPlay: {}
    )
    .padding()
}
