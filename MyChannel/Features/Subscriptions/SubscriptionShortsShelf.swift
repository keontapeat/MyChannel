//
//  SubscriptionShortsShelf.swift
//  MyChannel
//
//  YouTube-parity Shorts shelf for the subscriptions feed.
//  Horizontal scroll of compact 9:16 portrait cards, with the red "S"
//  Shorts header + ">" see-all chevron.
//

import SwiftUI

struct SubscriptionShortsShelf: View {
    let shorts: [Video]
    var onTap: (Video) -> Void
    var onSeeAll: (() -> Void)? = nil

    // Compact portrait card sizing (YouTube subs feed parity)
    private let cardWidth: CGFloat = 140
    private var cardHeight: CGFloat { cardWidth * 16 / 9 } // ≈ 249pt

    // Up to 12 in the horizontal rail
    private var displayedShorts: [Video] { Array(shorts.prefix(12)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(displayedShorts) { short in
                        shortCard(short)
                            .onTapGesture {
                                HapticManager.shared.impact(style: .light)
                                onTap(short)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Header
    private var header: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            onSeeAll?()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Flicks")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Short Card (9:16 portrait, overlaid title + views)
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
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Gradient scrim for text legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .allowsHitTesting(false)

            // Title + views at bottom
            VStack(alignment: .leading, spacing: 3) {
                Text(short.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(short.formattedViewCount) views")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(10)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}

#Preview {
    SubscriptionShortsShelf(
        shorts: Array(Video.sampleVideos.prefix(6)),
        onTap: { _ in }
    )
    .background(AppTheme.Colors.background)
}
