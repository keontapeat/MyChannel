//
//  ChannelArtworkView.swift
//  MyChannel
//
//  🔥 Bulletproof Live TV channel artwork.
//  Uses the validated SmartYouTubeThumbnail loader so dead / 404 / placeholder
//  thumbnails NEVER render as the grey "•••" box. When artwork is missing or
//  invalid, we render a premium, branded category card instead — so the Live TV
//  grid always looks intentional and complete (YouTube TV parity).
//

import SwiftUI

struct ChannelArtworkView: View {
    let channel: LiveTVChannel
    var cornerRadius: CGFloat = 0

    var body: some View {
        SmartYouTubeThumbnailView(
            url: channel.logoURL,
            placeholder: { BrandedChannelPlaceholder(channel: channel) },
            onLoaded: {}
        )
        .modifier(OptionalRoundedClip(cornerRadius: cornerRadius))
    }
}

// MARK: - Branded fallback (no grey boxes, ever)

struct BrandedChannelPlaceholder: View {
    let channel: LiveTVChannel

    private var color: Color { channel.category.color }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0.55), color.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle diagonal sheen so it reads as designed art, not an empty box
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addQuadCurve(to: CGPoint(x: w, y: h * 0.6),
                                      control: CGPoint(x: w * 0.5, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.08))
            }

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 38, height: 38)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)

                Text(channel.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
    }

    private var categoryIcon: String {
        switch channel.category {
        case .anime: return "sparkles.tv.fill"
        case .scifi: return "moon.stars.fill"
        case .reality: return "person.3.fill"
        case .comedy: return "face.smiling.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .entertainment: return "tv.fill"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        case .classic: return "clock.fill"
        }
    }
}

// MARK: - Helper: optionally clip with a rounded rect

private struct OptionalRoundedClip: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        if cornerRadius > 0 {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }
}
