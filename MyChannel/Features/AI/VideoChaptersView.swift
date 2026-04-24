//
//  VideoChaptersView.swift
//  MyChannel
//
//  Phase 25 UI: Chapter markers list + overlay for video player scrubber.
//

import SwiftUI

// MARK: - Chapter List (Displayed below or beside the player)

struct VideoChaptersListView: View {
    let chapters: [VideoChapter]
    let currentTime: Double
    let onSeek: (Double) -> Void

    private var activeIndex: Int? {
        guard !chapters.isEmpty else { return nil }
        for i in stride(from: chapters.count - 1, through: 0, by: -1) {
            if currentTime >= chapters[i].startTime { return i }
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Chapters")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                            ChapterPill(chapter: chapter, isActive: idx == activeIndex)
                                .id(chapter.id)
                                .onTapGesture { onSeek(chapter.startTime) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: activeIndex) { newIdx in
                    if let id = newIdx.flatMap({ chapters[safe: $0]?.id }) {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
    }
}

private struct ChapterPill: View {
    let chapter: VideoChapter
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chapter.formattedStartTime)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isActive ? .white : .secondary)
            Text(chapter.title)
                .font(.caption.bold())
                .foregroundStyle(isActive ? .white : .primary)
                .lineLimit(2)
        }
        .frame(width: 120, alignment: .leading)
        .padding(10)
        .background(isActive ? Color.accentColor : Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Chapter Markers Overlay (sits on top of the scrubber)

struct ChapterMarkersOverlay: View {
    let chapters: [VideoChapter]
    let totalDuration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                ForEach(chapters) { chapter in
                    let fraction = chapter.startTime / max(totalDuration, 1)
                    let x = geo.size.width * fraction

                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2, height: geo.size.height)
                        .offset(x: x)
                        .onTapGesture { onSeek(chapter.startTime) }
                }
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Safe Collection Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let sample: [VideoChapter] = [
        .init(videoId: "test1", title: "Intro", startTime: 0),
        .init(videoId: "test2", title: "Setup", startTime: 30),
        .init(videoId: "test3", title: "Main Content", startTime: 120),
        .init(videoId: "test4", title: "Conclusion", startTime: 300),
    ]
    VStack {
        VideoChaptersListView(chapters: sample, currentTime: 45) { t in print("Seek \(t)") }
            .frame(height: 80)
        ChapterMarkersOverlay(chapters: sample, totalDuration: 360) { t in print("Seek \(t)") }
            .frame(height: 4)
            .background(Color.gray.opacity(0.3))
            .padding(.horizontal)
    }
}
