import SwiftUI

import SwiftUI

struct VideoMoreOptionsSheet: View {
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("More Options")
                    .font(.title)
                    .bold()
                
                Text("Video: \(video.title)")
                    .font(.subheadline)
                
                Button(action: {
                    isWatchLater.toggle()
                }) {
                    HStack {
                        Image(systemName: isWatchLater ? "bookmark.fill" : "bookmark")
                        Text(isWatchLater ? "Remove from Watch Later" : "Save to Watch Later")
                        Spacer()
                    }
                }
                
                Button(action: {
                    isSubscribed.toggle()
                }) {
                    HStack {
                        Image(systemName: isSubscribed ? "bell.slash" : "bell")
                        Text(isSubscribed ? "Unsubscribe" : "Subscribe")
                        Spacer()
                    }
                }
                
                Button("Report") {
                    // Handle report
                }
                
                Button("Copy Video Link") {
                    // Handle copy link
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VideoMoreOptionsSheet(
        video: Video.sampleVideos[0],
        isSubscribed: .constant(false),
        isWatchLater: .constant(false)
    )
}
