import SwiftUI

struct VideoChaptersSheet: View {
    let video: Video
    let onSelect: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
            List(filteredChapters, id: \.chapter.id) { item in
                Button {
                    onSelect(item.chapter.start)
                    Task { await AnalyticsService.shared.trackEvent("chapter_tap", parameters: ["videoId": video.id, "title": item.chapter.title, "start": item.chapter.start]) }
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
            .searchable(text: $searchText, prompt: "Search chapters")
        }
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.medium(), .large()],
                    largestUndimmedDetentIdentifier: .large,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: false,
                    preferredCornerRadius: 28
                )
            )
        )
    }
    
    private var chaptersWithEnd: [(chapter: Video.Chapter, end: TimeInterval?)] {
        let base = (video.chapters?.isEmpty == false) ? (video.chapters ?? []) : video.parsedChaptersFromDescription
        guard !base.isEmpty else { return [] }
        let sorted = base.sorted { $0.start < $1.start }
        var result: [(Video.Chapter, TimeInterval?)] = []
        for (i, ch) in sorted.enumerated() {
            let end = i < sorted.count - 1 ? sorted[i+1].start : nil
            result.append((ch, end))
        }
        return result
    }

    private var filteredChapters: [(chapter: Video.Chapter, end: TimeInterval?)] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return chaptersWithEnd }
        return chaptersWithEnd.filter { item in
            item.chapter.title.lowercased().contains(query) || timeString(item.chapter.start).contains(query)
        }
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


