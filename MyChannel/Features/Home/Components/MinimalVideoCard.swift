//
//  MinimalVideoCard.swift
//  MyChannel
//
//  Extracted from HomeView for better code organization
//

import SwiftUI

// MARK: - Minimal Video Card
struct MinimalVideoCard: View {
    let video: Video
    let action: () -> Void
    var useLivePreview: Bool = false
    var cardWidth: CGFloat? = nil

    /// Resolved width: explicit cardWidth, or environment adaptive width, or 180pt fallback
    @Environment(\.adaptiveCardWidth) private var envCardWidth
    private var resolvedWidth: CGFloat { cardWidth ?? envCardWidth }
    private var resolvedHeight: CGFloat { (resolvedWidth * 9 / 16).rounded() }

    /// Returns true ONLY for content that can be previewed via a native AVPlayer
    /// (direct HLS/MP4/MOV links and Firebase Storage URLs).
    ///
    /// ⛔️ YouTube is intentionally EXCLUDED. YouTube previews run inside a WKWebView
    /// IFrame player, and when YouTube blocks embedding (region lock, age gate, or
    /// "playback on other websites disabled") the iframe paints its OWN error screen
    /// — e.g. "This video is unavailable. Error code: 152-4" — directly where the
    /// thumbnail should be. A user must never see that, so YouTube always falls back
    /// to a static cover image via `MultiSourceAsyncImage`/`posterCandidates`.
    private var hasStreamableURL: Bool {
        // Never live-preview YouTube content in a card — static image only.
        if video.contentSource == .youtube { return false }
        let url = video.videoURL.lowercased()
        if url.isEmpty { return false }
        if url.hasPrefix("asset://") { return false }
        if url.contains("youtube.com") || url.contains("youtu.be") { return false }
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else { return false }
        return url.contains(".m3u8") || url.contains(".mp4") || url.contains(".mov") || url.contains("firebasestorage.googleapis.com")
    }

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let showLive = useLivePreview && !isPreview && hasStreamableURL
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if showLive {
                        // ⚡ Live player — NO .drawingGroup() here.
                        // drawingGroup() rasterizes to a flat GPU bitmap which kills
                        // AVPlayer and WKWebView (YouTube) since they render outside
                        // SwiftUI's layer hierarchy.
                        VideoLiveThumbnailView(video: video, cornerRadius: 12)
                            .frame(width: resolvedWidth, height: resolvedHeight)
                    } else {
                        MultiSourceAsyncImage(
                            urls: video.posterCandidates,
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: resolvedWidth, height: resolvedHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            },
                            placeholder: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemGray6))
                                    .frame(width: resolvedWidth, height: resolvedHeight)
                                    .overlay(
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        )
                        .drawingGroup() // ⚡ GPU flatten only for static images, safe here
                    }
                }
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(video.formattedDuration)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.7)))
                                .padding(8)
                        }
                    }
                )
                .onAppear {
                    if !showLive, let url = video.posterCandidates.first {
                        ImagePrefetcher.shared.prefetch(url: url)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)

                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("\(video.formattedViewCount) views")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: resolvedWidth, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
}

// MARK: - Preview
#Preview {
    MinimalVideoCard(
        video: Video.sampleVideos.first!,
        action: {}
    )
    .padding()
}
