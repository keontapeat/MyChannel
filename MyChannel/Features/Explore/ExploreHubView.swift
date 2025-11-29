import SwiftUI

struct ExploreHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                // Clean header
                header
                
                // Topic chips (YouTube style)
                topicChips
                
                // Video list
                if isLoading {
                    loadingView
                } else {
                    videoList
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            Task { await exploreService.loadTrending() }
        }
    }
    
    // MARK: - Clean Header
    private var header: some View {
        HStack {
            Spacer()
            
            Text("Explore")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                HapticManager.shared.impact(style: .light)
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Topic Chips (YouTube Style)
    private var topicChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Trending chip
                chipButton(title: "Trending", isSelected: selectedTopic == nil) {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTopic = nil
                    }
                    Task { await exploreService.loadTrending() }
                }
                
                // Topic chips
                ForEach(topics, id: \.self) { topic in
                    chipButton(title: topic, isSelected: selectedTopic == topic) {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTopic = topic
                        }
                        Task { await exploreService.loadTopic(topic) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }
    
    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected 
                            ? AppTheme.Colors.primary
                            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(colorScheme == .dark ? .white : .black)
            Spacer()
        }
    }
    
    // MARK: - Video List
    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(exploreService.videos) { video in
                    CleanExploreRow(video: video)
                    
                    // Subtle divider
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                        .padding(.leading, 148)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Clean Explore Row (YouTube Style)
struct CleanExploreRow: View {
    let video: Video
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            NotificationCenter.default.post(name: NSNotification.Name("OpenVideoDetail"), object: video)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                thumbnailView
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Text(video.creator.displayName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        }
                    }
                    
                    Text("\(video.formattedViewCount) views · \(video.timeAgo)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 0)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                    .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isPressed 
                ? (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                : Color.clear)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel("\(video.title) by \(video.creator.displayName)")
    }
    
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                        .overlay {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                        }
                @unknown default:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                }
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Duration badge
            Text(video.formattedDuration)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(4)
        }
    }
}

// Legacy support
struct ExploreVideoRow: View {
    let video: Video
    
    var body: some View {
        CleanExploreRow(video: video)
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


