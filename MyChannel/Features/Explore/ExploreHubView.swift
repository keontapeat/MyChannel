import SwiftUI

struct ExploreHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exploreService = ExploreService()
    @State private var selectedTopic: String? = nil
    @State private var isLoading = false
    
    private let topics = [
        "Gaming", "Music", "Tech", "Cooking", "Travel", "Comedy", 
        "Beauty", "Fitness", "Education", "News", "Sports", "Art"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Topic chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button("Trending") {
                            selectedTopic = nil
                            Task { await exploreService.loadTrending() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTopic == nil ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                        .foregroundColor(selectedTopic == nil ? .white : AppTheme.Colors.textPrimary)
                        .cornerRadius(20)
                        
                        ForEach(topics, id: \.self) { topic in
                            Button(topic) {
                                selectedTopic = topic
                                Task { await exploreService.loadTopic(topic) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTopic == topic ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .foregroundColor(selectedTopic == topic ? .white : AppTheme.Colors.textPrimary)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                
                if isLoading {
                    ProgressView("Loading \(selectedTopic ?? "Trending")...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(exploreService.videos) { video in
                            NavigationLink {
                                VideoDetailView(video: video)
                            } label: {
                                ExploreVideoRow(video: video)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            Task { await exploreService.loadTrending() }
        }
    }
}

struct ExploreVideoRow: View {
    let video: Video
    
    var body: some View {
        HStack(spacing: 12) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: { Color(.systemGray6) }
            )
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                
                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

@MainActor
final class ExploreService: ObservableObject {
    @Published var videos: [Video] = []
    
    func loadTrending() async {
        videos = Video.sampleVideos.sorted { $0.viewCount > $1.viewCount }
    }
    
    func loadTopic(_ topic: String) async {
        let category = mapTopicToCategory(topic)
        videos = Video.sampleVideos.filter { $0.category == category }.shuffled()
    }
    
    private func mapTopicToCategory(_ topic: String) -> VideoCategory {
        switch topic.lowercased() {
        case "gaming": return .gaming
        case "music": return .music
        case "tech": return .technology
        case "cooking": return .cooking
        case "travel": return .travel
        case "comedy": return .comedy
        case "beauty": return .beauty
        case "fitness": return .fitness
        case "education": return .education
        case "news": return .news
        case "sports": return .sports
        case "art": return .art
        default: return .entertainment
        }
    }
}

#Preview {
    ExploreHubView()
        .environmentObject(AppState())
}


