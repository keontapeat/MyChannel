//
//  RealVideoFeedService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Foundation

@MainActor
class RealVideoFeedService: ObservableObject {
    static let shared = RealVideoFeedService()
    
    @Published var isLoading: Bool = false
    @Published var videos: [Video] = []
    @Published var featuredVideos: [Video] = []
    @Published var trendingVideos: [Video] = []
    
    private init() {
        loadInitialVideos()
    }
    
    // MARK: - Real Video URLs from Various Free Sources
    private let realVideoSources: [VideoSource] = [
        // Internet Archive - Free videos
        VideoSource(
            title: "Big Buck Bunny (4K)",
            description: "Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself. When the local rodent gang leader, Frank, and his sidekicks Rinky & Gamera, decide to pick on the smaller woodland creatures, Big Buck Bunny decides he's had enough.",
            thumbnailURL: "https://ia801504.us.archive.org/11/items/BigBuckBunny_124/BigBuckBunny_124.thumbs/BigBuckBunny_124_000005.jpg",
            videoURL: "https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4",
            duration: 596,
            category: .animation
        ),
        VideoSource(
            title: "Sintel - Blender Open Movie",
            description: "A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend Scales.",
            thumbnailURL: "https://ia601404.us.archive.org/2/items/Sintel/Sintel.thumbs/Sintel_000001.jpg",
            videoURL: "https://archive.org/download/Sintel/Sintel.mp4",
            duration: 888,
            category: .animation
        ),
        VideoSource(
            title: "Tears of Steel",
            description: "Tears of Steel was realized with crowd-funding by users of the open source 3D creation tool Blender. Target was to improve and test a complete open and free pipeline for visual effects in film.",
            thumbnailURL: "https://ia801406.us.archive.org/33/items/TearOfSteel/TearOfSteel.thumbs/TearOfSteel_000001.jpg",
            videoURL: "https://archive.org/download/TearOfSteel/TearOfSteel.mp4",
            duration: 734,
            category: .entertainment
        ),
        VideoSource(
            title: "Elephant's Dream",
            description: "The story of two strange characters exploring a capricious and seemingly infinite machine. The elder, Proog, acts as a tour-guide and protector, happily showing off the sights and dangers of the machine.",
            thumbnailURL: "https://ia601508.us.archive.org/10/items/ElephantsDream/ElephantsDream.thumbs/ElephantsDream_000001.jpg",
            videoURL: "https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4",
            duration: 654,
            category: .art
        ),
        // Sample MP4 videos from various sources
        VideoSource(
            title: "Sample Nature Video",
            description: "Beautiful nature footage showcasing the wonders of our planet. Perfect for relaxation and meditation.",
            thumbnailURL: "https://sample-videos.com/zip/10/mp4/480/big_buck_bunny_480p_1mb.jpg",
            videoURL: "https://sample-videos.com/zip/10/mp4/480/big_buck_bunny_480p_1mb.mp4",
            duration: 60,
            category: .documentary
        ),
        VideoSource(
            title: "Tech Demo Reel",
            description: "Cutting-edge technology demonstrations and innovations that are shaping our future.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            duration: 60,
            category: .technology
        ),
        VideoSource(
            title: "Creative Coding Session",
            description: "Watch as we create amazing visual effects using code. Learn programming through creative expression.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            duration: 15,
            category: .education
        ),
        VideoSource(
            title: "Music Production Tutorial",
            description: "Learn how to create amazing beats and melodies using modern production techniques.",
            thumbnailURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg",
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
            duration: 15,
            category: .music
        )
    ]
    
    // MARK: - Load Videos
    func loadInitialVideos() {
        isLoading = true
        
        Task {
            // Simulate loading delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let generatedVideos = generateVideosFromSources()
            
            await MainActor.run {
                self.videos = Video.sampleVideos + generatedVideos
                self.featuredVideos = Array(self.videos.shuffled().prefix(5))
                self.trendingVideos = self.videos.sorted { $0.viewCount > $1.viewCount }.prefix(8).map { $0 }
                self.isLoading = false
            }
        }
    }
    
    func refreshVideos() async {
        isLoading = true
        
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let newVideos = generateVideosFromSources()
        
        videos = Video.sampleVideos + newVideos.shuffled()
        featuredVideos = Array(videos.shuffled().prefix(5))
        trendingVideos = videos.sorted { $0.viewCount > $1.viewCount }.prefix(8).map { $0 }
        
        isLoading = false
    }
    
    func loadMoreVideos() async -> [Video] {
        // Simulate loading more videos
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        return generateVideosFromSources(startIndex: videos.count)
    }
    
    // MARK: - Video Generation
    private func generateVideosFromSources(startIndex: Int = 0) -> [Video] {
        return realVideoSources.enumerated().map { index, source in
            let adjustedIndex = startIndex + index
            return Video(
                title: source.title,
                description: source.description,
                thumbnailURL: source.thumbnailURL,
                videoURL: source.videoURL,
                duration: source.duration,
                viewCount: Int.random(in: 10000...5000000),
                likeCount: Int.random(in: 500...100000),
                dislikeCount: Int.random(in: 10...5000),
                commentCount: Int.random(in: 50...10000),
                createdAt: Calendar.current.date(byAdding: .hour, value: -Int.random(in: 1...168), to: Date()) ?? Date(),
                creator: User.sampleUsers[adjustedIndex % User.sampleUsers.count],
                tags: generateTagsForCategory(source.category),
                category: source.category,
                isShort: source.duration < 60,
                monetization: VideoMonetization(
                    hasAds: true,
                    adRevenue: Double.random(in: 100...2000),
                    tipRevenue: Double.random(in: 50...500)
                )
            )
        }
    }
    
    private func generateTagsForCategory(_ category: VideoCategory) -> [String] {
        switch category {
        case .animation:
            return ["Animation", "3D", "Blender", "Art", "Creative"]
        case .technology:
            return ["Tech", "Innovation", "Future", "Digital", "AI"]
        case .education:
            return ["Tutorial", "Learning", "Programming", "Skills", "Knowledge"]
        case .music:
            return ["Music", "Beats", "Production", "Audio", "Sound"]
        case .documentary:
            return ["Nature", "Wildlife", "Documentary", "Educational", "Planet"]
        case .art:
            return ["Art", "Creative", "Design", "Visual", "Artistic"]
        case .entertainment:
            return ["Entertainment", "Fun", "Comedy", "Popular", "Trending"]
        default:
            return ["Video", "Content", "Popular", "Trending"]
        }
    }
    
    // MARK: - Search and Filter
    func searchVideos(query: String) -> [Video] {
        guard !query.isEmpty else { return videos }
        
        return videos.filter { video in
            video.title.localizedCaseInsensitiveContains(query) ||
            video.description.localizedCaseInsensitiveContains(query) ||
            video.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func getVideosByCategory(_ category: VideoCategory) -> [Video] {
        return videos.filter { $0.category == category }
    }
    
    func getFeaturedVideos() -> [Video] {
        return featuredVideos
    }
    
    func getTrendingVideos() -> [Video] {
        return trendingVideos
    }
}

// MARK: - Supporting Models
struct VideoSource {
    let title: String
    let description: String
    let thumbnailURL: String
    let videoURL: String
    let duration: TimeInterval
    let category: VideoCategory
}

// MARK: - Preview
#Preview("Real Video Feed") {
    VStack {
        Text("Real Video Feed Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        if RealVideoFeedService.shared.isLoading {
            ProgressView("Loading videos...")
        } else {
            Text("\(RealVideoFeedService.shared.videos.count) videos available")
                .font(.headline)
            
            Text("Featured: \(RealVideoFeedService.shared.featuredVideos.count)")
            Text("Trending: \(RealVideoFeedService.shared.trendingVideos.count)")
        }
        
        Button("Refresh Videos") {
            Task {
                await RealVideoFeedService.shared.refreshVideos()
            }
        }
        .primaryButtonStyle()
        .padding()
        
        Spacer()
    }
    .padding()
}