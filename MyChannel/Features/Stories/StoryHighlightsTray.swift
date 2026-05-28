import SwiftUI

struct StoryHighlightsTray: View {
    let creatorId: String
    let onSelect: (StoryHighlight) -> Void

    @StateObject private var highlightsService = StoryHighlightsService.shared

    var body: some View {
        Group {
            if !highlightsService.highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(highlightsService.highlights) { highlight in
                            Button {
                                onSelect(highlight)
                            } label: {
                                VStack(spacing: 8) {
                                    CachedAsyncImage(url: URL(string: highlight.coverImageURL)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle().fill(AppTheme.Colors.surface)
                                    }
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))

                                    Text(highlight.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(width: 78)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .task {
            await highlightsService.loadHighlights(creatorId: creatorId)
        }
    }
}
