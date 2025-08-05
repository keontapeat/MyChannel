import SwiftUI

struct CommentComposerView: View {
    let video: Video
    let onCommentAdded: (VideoComment) -> Void
    
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Compose Comment")
                    .font(.title)
                
                Text("Video: \(video.title)")
                
                TextField("Your comment", text: $commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...10)
                
                Button("Post Comment") {
                    // Create a dummy comment for now
                    let comment = VideoComment(
                        author: User.sampleUsers[0],
                        text: commentText
                    )
                    onCommentAdded(comment)
                    dismiss()
                }
                .disabled(commentText.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CommentComposerView(video: Video.sampleVideos[0]) { _ in }
}
