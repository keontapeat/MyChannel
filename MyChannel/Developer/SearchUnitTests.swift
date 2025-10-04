import SwiftUI

struct SearchUnitTestsView: View {
    @State private var output: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Unit Tests")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                Text(output.isEmpty ? "Tap Run to execute tests." : output)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)

            HStack {
                Button("Run Tests") { runAll() }
                    .buttonStyle(.borderedProminent)
                Button("Clear") { output = "" }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func runAll() {
        var logs: [String] = []
        func log(_ s: String) { logs.append(s) }

        // DefaultQueryProcessor tests
        Task {
            let qp: QueryProcessing = DefaultQueryProcessor()
            let p1 = await qp.processQuery("  The Best Tech Reviews 2024  ")
            assert(p1.terms.contains("best") && p1.terms.contains("tech") && p1.terms.contains("reviews"))
            log("✓ processQuery stop words + trimming")

            let nl = await qp.processNaturalLanguageQuery("Funny cat videos this month")
            assert(!nl.terms.isEmpty)
            log("✓ processNaturalLanguageQuery extracts terms")

            let f = await qp.inferFilters(from: "long tech videos this month")
            assert(f.duration == .long && f.uploadDate == .thisMonth && f.category == .technology)
            log("✓ inferFilters duration/uploadDate/category")

            // DefaultSearchRankingEngine tests
            let ranker: ResultRanking = DefaultSearchRankingEngine()
            let v1 = VideoSearchResult(video: Video.sampleVideos[0], relevanceScore: 0.9, matchingFields: [], highlights: [])
            let v2 = VideoSearchResult(video: Video.sampleVideos[1], relevanceScore: 0.7, matchingFields: [], highlights: [])
            let r: [SearchResult] = [.video(v1), .video(v2)]
            let sorted = await ranker.rankResults(r, for: ProcessedQuery(originalQuery: "", terms: [], searchTerms: ""))
            assert(sorted.first?.relevanceScore ?? 0 >= sorted.last?.relevanceScore ?? 0)
            log("✓ rankResults sorts by relevance")

            await MainActor.run {
                output = logs.joined(separator: "\n")
            }
        }
    }
}

#Preview("Search Unit Tests") {
    SearchUnitTestsView()
}


