import SwiftUI

struct StoryHighlightViewer: View {
    let highlight: StoryHighlight

    @Environment(\.dismiss) private var dismiss
    @State private var stories: [Story] = []

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty {
                    ProgressView()
                        .tint(AppTheme.Colors.primary)
                } else {
                    TabView {
                        ForEach(stories) { story in
                            ZStack {
                                Color.black.ignoresSafeArea()
                                AsyncImage(url: URL(string: story.mediaURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .navigationTitle(highlight.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadStories()
        }
    }

    private func loadStories() async {
        guard !highlight.storyIds.isEmpty else { return }
        if let allStories = try? await DatabaseService.shared.fetchStoriesByCreator(creatorId: highlight.creatorId, includeExpired: true) {
            let mapped = allStories.filter { highlight.storyIds.contains($0.id) }
            await MainActor.run {
                stories = mapped.sorted { lhs, rhs in
                    guard let left = highlight.storyIds.firstIndex(of: lhs.id),
                          let right = highlight.storyIds.firstIndex(of: rhs.id) else {
                        return lhs.createdAt < rhs.createdAt
                    }
                    return left < right
                }
            }
        }
    }
}
