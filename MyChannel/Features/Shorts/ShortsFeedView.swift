import SwiftUI

struct ShortsFeedView: View {
    @State private var shorts: [Video] = []
    @State private var isLoading = true

    var body: some View {
        VerticalShortsView()
        .tabViewStyle(.page(indexDisplayMode: .never))
        .task { await loadShorts() }
    }

    private func loadShorts() async {
        // TODO: Fetch from Firestore shorts collection with prefetch
        await MainActor.run {
            isLoading = false
        }
    }
}

struct ShortsFeedView_Previews: PreviewProvider {
    static var previews: some View {
        ShortsFeedView()
    }
}

