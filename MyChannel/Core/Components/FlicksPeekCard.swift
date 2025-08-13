//
//  FlicksPeekCard.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

struct FlicksPeekCard: View {
    let video: Video

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.caption.bold())
                    Text(video.formattedViewCount + " views")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "waveform.and.mic")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(10)
                .background(AppTheme.Colors.surface, in: Circle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
    }
}

#Preview("FlicksPeekCard") {
    FlicksPeekCard(video: Video.sampleVideos.first!)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.light)
}