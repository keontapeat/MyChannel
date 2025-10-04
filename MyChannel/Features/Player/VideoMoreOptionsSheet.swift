import SwiftUI

struct VideoMoreOptionsSheet: View {
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var showReportAlert = false
    @State private var showCopyToast = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Label("Video: \(video.title)", systemImage: "film")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: {
                        isWatchLater.toggle()
                        feedback()
                    }) {
                        HStack {
                            Label(
                                isWatchLater ? "Remove from Watch Later" : "Save to Watch Later",
                                systemImage: isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        isSubscribed.toggle()
                        feedback()
                    }) {
                        HStack {
                            Label(
                                isSubscribed ? "Unsubscribe" : "Subscribe",
                                systemImage: isSubscribed ? "bell.slash.fill" : "bell.fill"
                            )
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showReportAlert = true
                        feedback()
                    } label: {
                        Label("Report", systemImage: "flag.fill")
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = video.link // Assuming `video.link` exists
                        showCopyToast = true
                        feedback()
                    }) {
                        Label("Copy Video Link", systemImage: "link")
                    }
                }
            }
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Report this video?", isPresented: $showReportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) {
                    // Handle real report action
                }
            }
            .overlay(
                Group {
                    if showCopyToast {
                        ToastView(text: "Link copied!")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showCopyToast = false
                                    }
                                }
                            }
                    }
                },
                alignment: .bottom
            )
        }
        .presentationDetents([.medium])
    }
    
    func feedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    VideoMoreOptionsSheet(
        video: Video.sampleVideos[0],
        isSubscribed: .constant(false),
        isWatchLater: .constant(false)
    )
}

