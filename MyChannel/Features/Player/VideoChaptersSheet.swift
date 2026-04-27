import SwiftUI

// MARK: - Chapter Performance Tier
enum ChapterPerformanceTier {
    case top, high, mid, low

    var label: String {
        switch self {
        case .top:  return "Top"
        case .high: return "High"
        case .mid:  return "Mid"
        case .low:  return "Low"
        }
    }

    var icon: String {
        switch self {
        case .top:  return "flame.fill"
        case .high: return "chart.line.uptrend.xyaxis"
        case .mid:  return "chart.bar"
        case .low:  return "chart.line.downtrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .top:  return .orange
        case .high: return .green
        case .mid:  return .blue
        case .low:  return .secondary
        }
    }
}

struct VideoChaptersSheet: View {
    let video: Video
    let onSelect: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var searchText: String = ""
    @State private var pinnedChapterIds: Set<String> = []
    @State private var bookmarkedChapterIds: Set<String> = []
    @State private var showChapterActions = false
    @State private var actionChapter: Video.Chapter?

    private var isOwner: Bool {
        authManager.currentUser?.id == video.creator.id
    }

    var body: some View {
        NavigationView {
            List(filteredChapters, id: \.chapter.id) { item in
                Button {
                    onSelect(item.chapter.start)
                    Task { await AnalyticsService.shared.trackEvent("chapter_tap", parameters: ["videoId": video.id, "title": item.chapter.title, "start": item.chapter.start]) }
                    dismiss()
                } label: {
                    chapterRow(item: item)
                }
                .contextMenu { chapterContextMenu(for: item) }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .searchable(text: $searchText, prompt: "Search chapters")
        }
        .onAppear { loadPinnedChapters() }
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

    // MARK: - Chapter Row with Preview Badges

    @ViewBuilder
    private func chapterRow(item: (chapter: Video.Chapter, end: TimeInterval?)) -> some View {
        HStack(spacing: 12) {
            chapterThumbnail(for: item.chapter)
                .overlay(alignment: .topTrailing) {
                    chapterBadgeStack(for: item.chapter)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.chapter.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)

                    if let tier = performanceTier(for: item) {
                        Image(systemName: tier.icon)
                            .font(.caption2)
                            .foregroundStyle(tier.color)
                    }
                }

                HStack(spacing: 8) {
                    Text(timeString(item.chapter.start))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let end = item.end {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(chapterDuration(from: item.chapter.start, to: end))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Preview Badge Stack (Pinned / Monetized / Performance)

    @ViewBuilder
    private func chapterBadgeStack(for chapter: Video.Chapter) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if pinnedChapterIds.contains(chapter.id) {
                badgeView(icon: "pin.fill", color: .orange, label: "Pinned")
            }
            if isChapterMonetized(chapter) {
                badgeView(icon: "dollarsign.circle.fill", color: .green, label: "Monetized")
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func badgeView(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(label)
                .font(.system(size: 7, weight: .bold))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.85))
        .clipShape(Capsule())
        .foregroundColor(.white)
    }

    // MARK: - Context Menu (Sectioned: Content / Organization / Destructive)

    @ViewBuilder
    private func chapterContextMenu(for item: (chapter: Video.Chapter, end: TimeInterval?)) -> some View {
        // — Content Actions —
        Section {
            Button {
                HapticManager.shared.impact(style: .light)
                onSelect(item.chapter.start)
                dismiss()
            } label: {
                Label("Play from here", systemImage: "play.fill")
            }

            Button {
                HapticManager.shared.impact(style: .light)
                let timestamp = timeString(item.chapter.start)
                UIPasteboard.general.string = "https://mychannel.app/watch/\(video.id)?t=\(Int(item.chapter.start))"
                Task { await AnalyticsService.shared.trackEvent("chapter_link_copied", parameters: ["videoId": video.id, "chapterId": item.chapter.id]) }
            } label: {
                Label("Copy chapter link", systemImage: "link")
            }

            Button {
                HapticManager.shared.impact(style: .light)
                let timestamp = timeString(item.chapter.start)
                let items: [Any] = ["Check out \"\(item.chapter.title)\" at \(timestamp) on MyChannel! https://mychannel.app/watch/\(video.id)?t=\(Int(item.chapter.start))"]
                let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            } label: {
                Label("Share chapter", systemImage: "square.and.arrow.up")
            }
        }

        // — Organization Actions —
        Section {
            Button {
                HapticManager.shared.impact(style: .medium)
                togglePin(for: item.chapter)
            } label: {
                Label(
                    pinnedChapterIds.contains(item.chapter.id) ? "Unpin chapter" : "Pin chapter",
                    systemImage: pinnedChapterIds.contains(item.chapter.id) ? "pin.slash" : "pin"
                )
            }

            Button {
                HapticManager.shared.impact(style: .light)
                toggleBookmark(for: item.chapter)
            } label: {
                Label(
                    bookmarkedChapterIds.contains(item.chapter.id) ? "Remove bookmark" : "Bookmark chapter",
                    systemImage: bookmarkedChapterIds.contains(item.chapter.id) ? "bookmark.slash" : "bookmark"
                )
            }
        }

        // — Destructive Actions (owner only) —
        if isOwner {
            Section {
                Button(role: .destructive) {
                    HapticManager.shared.notification(type: .warning)
                    removeChapter(item.chapter)
                } label: {
                    Label("Remove chapter", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Chapter Data Helpers

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

    private func performanceTier(for item: (chapter: Video.Chapter, end: TimeInterval?)) -> ChapterPerformanceTier? {
        guard video.viewCount > 0 else { return nil }
        let chapterFraction = chapterDurationFraction(for: item)
        guard chapterFraction > 0 else { return nil }

        // Monetized chapters with ad breaks in this segment get a tier boost
        let hasAdBreak = isChapterMonetized(item.chapter)
        let effectiveFraction = hasAdBreak ? chapterFraction * 1.3 : chapterFraction

        switch effectiveFraction {
        case 0.25...:  return .top
        case 0.15..<0.25: return .high
        case 0.05..<0.15: return .mid
        default:       return .low
        }
    }

    private func chapterDurationFraction(for item: (chapter: Video.Chapter, end: TimeInterval?)) -> Double {
        guard video.duration > 0, let end = item.end else { return 0 }
        let chapterLen = end - item.chapter.start
        return chapterLen / video.duration
    }

    private func isChapterMonetized(_ chapter: Video.Chapter) -> Bool {
        guard let monetization = video.monetization, monetization.isMonetized else { return false }
        // Check if any ad break falls within this chapter's time range
        if let adBreaks = monetization.adBreakTimestamps {
            return adBreaks.contains { ad in
                ad.timeStamp >= chapter.start && ad.timeStamp < (chapter.start + 300)
            }
        }
        // If mid-roll ads enabled, chapters past the first 30s are monetized
        if let adBreaks = monetization.adBreaks, adBreaks.midRoll, chapter.start > 30 {
            return true
        }
        return false
    }

    // MARK: - Pin / Bookmark / Remove

    private func loadPinnedChapters() {
        guard let uid = authManager.currentUser?.id else { return }
        let key = "pinned_chapters_\(uid)_\(video.id)"
        pinnedChapterIds = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let bmKey = "bookmarked_chapters_\(uid)_\(video.id)"
        bookmarkedChapterIds = Set(UserDefaults.standard.stringArray(forKey: bmKey) ?? [])
    }

    private func togglePin(for chapter: Video.Chapter) {
        guard let uid = authManager.currentUser?.id else { return }
        let key = "pinned_chapters_\(uid)_\(video.id)"
        if pinnedChapterIds.contains(chapter.id) {
            pinnedChapterIds.remove(chapter.id)
        } else {
            pinnedChapterIds.insert(chapter.id)
        }
        UserDefaults.standard.set(Array(pinnedChapterIds), forKey: key)
    }

    private func toggleBookmark(for chapter: Video.Chapter) {
        guard let uid = authManager.currentUser?.id else { return }
        let key = "bookmarked_chapters_\(uid)_\(video.id)"
        if bookmarkedChapterIds.contains(chapter.id) {
            bookmarkedChapterIds.remove(chapter.id)
        } else {
            bookmarkedChapterIds.insert(chapter.id)
        }
        UserDefaults.standard.set(Array(bookmarkedChapterIds), forKey: key)
    }

    private func removeChapter(_ chapter: Video.Chapter) {
        guard var chapters = video.chapters else { return }
        chapters.removeAll { $0.id == chapter.id }
        pinnedChapterIds.remove(chapter.id)
        bookmarkedChapterIds.remove(chapter.id)
        Task {
            try? await VideoChapterService.shared.deleteChapter(chapter.id, from: video.id)
        }
    }

    // MARK: - Thumbnail & Formatting

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
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func chapterDuration(from start: TimeInterval, to end: TimeInterval) -> String {
        let d = end - start
        let m = Int(d) / 60
        let s = Int(d) % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }
}


