import SwiftUI

struct HashtagSearchSheet: View {
    let hashtag: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = AdvancedSearchService()
    @State private var results: [SearchResult] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching #\(hashtag)…")
                } else {
                    ModernSearchResultsList(
                        results: results,
                        searchCorrection: nil,
                        relatedSearches: [],
                        isLoadingMore: false,
                        onCorrectionTap: { _ in },
                        onRelatedTap: { _ in },
                        onLoadMore: { }
                    )
                }
            }
            .navigationTitle("#\(hashtag)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            let response = try? await searchService.search(query: "#\(hashtag)", userId: AppState.shared.currentUser?.id)
            results = response?.results ?? []
            isLoading = false
        }
    }
}
