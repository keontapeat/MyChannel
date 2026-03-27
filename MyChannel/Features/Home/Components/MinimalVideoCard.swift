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

    /// Returns true only for actual live streams with a real HLS manifest (.m3u8).
    /// Regular uploaded videos, Firebase Storage mp4s, and YouTube are excluded.
    private var hasStreamableURL: Bool {
        // Must be marked as a live stream in the data model
        guard video.isLiveStream else { return false }
        let url = video.videoURL.lowercased()
        if url.isEmpty { return false }
        if url.hasPrefix("asset://") { return false }
        if url.contains("youtube.com") || url.contains("youtu.be") { return false }
        if url.contains("firebasestorage.googleapis.com") { return false }
        if url.contains("firebase") { return false }
        // Must be an actual HLS manifest
        return url.contains(".m3u8")
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
                            .frame(width: 180, height: 101)
                    } else {
                        MultiSourceAsyncImage(
                            urls: video.posterCandidates,
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 101)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            },
                            placeholder: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 180, height: 101)
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
                .frame(width: 180, alignment: .leading)
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
