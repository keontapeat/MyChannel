//
//  TrendingFeedView.swift
//  MyChannel
//
//  Phase 13 UI: Trending feed page powered by TrendingEngineService.
//

import SwiftUI

struct TrendingFeedView: View {
    @StateObject private var engine = TrendingEngineService.shared
    @State private var videos: [Video] = []
    @State private var selectedCategory: String? = nil
    let onPlayVideo: (Video) -> Void

    private let categories = ["All", "Music", "Gaming", "Sports", "Entertainment", "Education", "News"]

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { cat in
                        let isSelected = (cat == "All" && selectedCategory == nil) || cat.lowercased() == selectedCategory
                        Button {
                            selectedCategory = cat == "All" ? nil : cat.lowercased()
                            Task { await loadTrending() }
                        } label: {
                            Text(cat)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()

            if engine.isLoading && videos.isEmpty {
                Spacer()
                ProgressView("Loading trending...")
                Spacer()
            } else if videos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "flame")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("No trending videos yet")
                        .font(.headline)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(videos.enumerated()), id: \.element.id) { idx, video in
                            TrendingFeedRow(rank: idx + 1, video: video)
                                .onTapGesture { onPlayVideo(video) }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Trending")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadTrending() }
    }

    private func loadTrending() async {
        guard let feed = try? await engine.fetchTrending(category: selectedCategory) else { return }
        let ids = feed.items.map(\.videoId)
        if !ids.isEmpty {
            videos = (try? await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: Array(ids.prefix(30)))) ?? []
        }
    }
}

private struct TrendingFeedRow: View {
    let rank: Int
    let video: Video

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40)

            AsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Color(.systemGray4)
            }
            .frame(width: 140, height: 79)
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

#Preview {
    NavigationStack {
        TrendingFeedView { _ in }
    }
}
