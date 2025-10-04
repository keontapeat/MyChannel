//
//  FlicksPeekCard.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

struct FlicksPeekCard: View {
    let video: Video
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text(video.formattedViewCount + " views")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(8)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.97))
        .accessibilityLabel("Open Flicks")
        .accessibilityHint("View vertical short videos")
        .padding(.horizontal, 20)
    }
}

#Preview("FlicksPeekCard") {
    FlicksPeekCard(video: Video.sampleVideos.first ?? Video.sampleVideos[0]) { }
        .padding()
        .background(Color(white: 0.95).ignoresSafeArea())
        .preferredColorScheme(.light)
}