//
//  SubscriptionShortsShelf.swift
//  MyChannel
//
//  YouTube-style Shorts shelf for the subscriptions feed.
//

import SwiftUI

struct SubscriptionShortsShelf: View {
    let shorts: [Video]
    var onTap: (Video) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "play.square.stack.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("Shorts")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shorts) { short in
                        Button {
                            HapticManager.shared.impact(style: .light)
                            onTap(short)
                        } label: {
                            shortCard(short)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func shortCard(_ short: Video) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: URL(string: short.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 150, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Gradient scrim for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: 150, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(short.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("\(short.formattedViewCount) views")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(10)
            .frame(width: 150, alignment: .leading)
        }
        .frame(width: 150, height: 260)
    }
}

#Preview {
    SubscriptionShortsShelf(shorts: Array(Video.sampleVideos.prefix(5)), onTap: { _ in })
        .background(AppTheme.Colors.background)
}
