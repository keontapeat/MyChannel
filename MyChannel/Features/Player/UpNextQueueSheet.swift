import SwiftUI

struct UpNextQueueSheet: View {
    let current: Video
    let queue: [Video]
    let onSelect: (Video) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(queue.filter { $0.id != current.id }) { v in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: v.thumbnailURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(width: 96, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(v.title).font(.subheadline).lineLimit(2)
                            Text(v.creator.displayName).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { onSelect(v) }) {
                            Image(systemName: "play.fill").foregroundColor(.white).padding(8).background(AppTheme.Colors.primary).clipShape(Circle())
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(v) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Up next")
        }
    }
}


