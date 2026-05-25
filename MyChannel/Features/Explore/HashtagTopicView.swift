//
//  HashtagTopicView.swift
//  MyChannel
//
//  Phase 14 UI: Hashtag/Topic aggregation page.
//

import SwiftUI

struct HashtagTopicView: View {
    let tag: HashtagTopic
    let onPlayVideo: (Video) -> Void

    @State private var videos: [Video] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(tag.tag)
                        .font(.largeTitle.bold())
                    HStack(spacing: 16) {
                        Label("\(tag.videoCount) videos", systemImage: "play.rectangle.fill")
                        Label("\(tag.viewCount.formatted()) views", systemImage: "eye.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Related tags
                if !tag.relatedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tag.relatedTags, id: \.self) { related in
                                NavigationLink {
                                    HashtagTopicView(
                                        tag: HashtagTopic(tag: related),
                                        onPlayVideo: onPlayVideo
                                    )
                                } label: {
                                    Text(related)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Divider()

                // Videos
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                } else if videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No videos with this tag yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(videos) { video in
                            HashtagVideoRow(video: video)
                                .onTapGesture { onPlayVideo(video) }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            videos = await HashtagService.shared.fetchVideos(for: tag.tag)
            isLoading = false
        }
    }
}

private struct HashtagVideoRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Color(.systemGray4)
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(video.viewCount.formatted()) views")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Trending Tags Grid

struct TrendingHashtagsView: View {
    @StateObject private var service = HashtagService.shared
    let onPlayVideo: (Video) -> Void

    var body: some View {
        ScrollView {
            if service.isLoading {
                ProgressView().padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(service.trendingTags) { tag in
                        NavigationLink {
                            HashtagTopicView(tag: tag, onPlayVideo: onPlayVideo)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tag.tag)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(tag.videoCount) videos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Trending Tags")
        .task { await service.fetchTrending() }
    }
}

#Preview {
    NavigationStack {
        TrendingHashtagsView { _ in }
    }
}
