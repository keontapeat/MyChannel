import SwiftUI

struct StoryArchiveView: View {
    let stories: [Story]
    let onAddToHighlight: (Story) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(stories) { story in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: story.mediaURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 56, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.caption ?? story.text ?? "Story")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                        Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Highlight") {
                        onAddToHighlight(story)
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Story Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
