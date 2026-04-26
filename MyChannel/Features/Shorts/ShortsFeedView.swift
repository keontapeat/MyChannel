import SwiftUI

struct ShortsFeedView: View {
    @State private var shorts: [Video] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                VerticalShortsView()
                    .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .task { await loadShorts() }
    }

    private func loadShorts() async {
        let videos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 50)
        await MainActor.run {
            shorts = videos.filter { $0.duration <= 60 }
            isLoading = false
        }
    }
}

struct ShortsFeedView_Previews: PreviewProvider {
    static var previews: some View {
        ShortsFeedView()
    }
}
