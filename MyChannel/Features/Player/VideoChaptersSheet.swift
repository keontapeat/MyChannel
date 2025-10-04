import SwiftUI

struct VideoChaptersSheet: View {
    let video: Video
    let onSelect: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(chaptersWithEnd, id: \.chapter.id) { item in
                Button {
                    onSelect(item.chapter.start)
                    Task { await AnalyticsService.shared.trackChapterTap(videoId: video.id, title: item.chapter.title, start: item.chapter.start) }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        chapterThumbnail(for: item.chapter)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.chapter.title)
                                .font(.system(size: 16, weight: .semibold))
                            Text(timeString(item.chapter.start))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    
    private var chaptersWithEnd: [(chapter: Video.Chapter, end: TimeInterval?)] {
        guard let chapters = video.chapters else { return [] }
        let sorted = chapters.sorted { $0.start < $1.start }
        var result: [(Video.Chapter, TimeInterval?)] = []
        for (i, ch) in sorted.enumerated() {
            let end = i < sorted.count - 1 ? sorted[i+1].start : nil
            result.append((ch, end))
        }
        return result
    }
    
    @ViewBuilder
    private func chapterThumbnail(for chapter: Video.Chapter) -> some View {
        if let url = chapter.thumbnailURL, let u = URL(string: url) {
            AsyncImage(url: u) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: { Color.gray.opacity(0.2) }
            .frame(width: 120, height: 68)
            .clipped()
            .cornerRadius(8)
        } else {
            Rectangle().fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 68)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "film").foregroundColor(.secondary)
                )
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}


