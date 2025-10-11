import Foundation
import SwiftUI

// Lightweight local store for Featured videos. Owner can add/remove in-app.
@MainActor
final class FeaturedStore: ObservableObject {
    static let shared = FeaturedStore()
    private init() { load() }

    @Published private(set) var featured: [StoredFeatured] = []
    private let key = "featured_videos_local_store"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([StoredFeatured].self, from: data) else {
            featured = []
            return
        }
        featured = decoded
    }

    private func persist() {
        if let data = try? encoder.encode(featured) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func isFeatured(_ id: String) -> Bool { featured.contains(where: { $0.id == id }) }

    func add(_ video: Video) {
        guard !isFeatured(video.id) else { return }
        featured.insert(StoredFeatured(from: video), at: 0)
        persist()
    }

    func remove(_ id: String) {
        featured.removeAll { $0.id == id }
        persist()
    }

    func toggle(video: Video) {
        if isFeatured(video.id) { remove(video.id) } else { add(video) }
    }

    func toVideos() -> [Video] { featured.map { $0.toVideo() } }
}

struct StoredFeatured: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let desc: String
    let thumb: String
    let url: String
    let duration: TimeInterval
    let creatorName: String
    let category: String

    init(from v: Video) {
        id = v.id
        title = v.title
        desc = v.description
        thumb = v.thumbnailURL
        url = v.videoURL
        duration = v.duration
        creatorName = v.creator.displayName
        category = v.category.rawValue
    }

    func toVideo() -> Video {
        Video(
            id: id,
            title: title,
            description: desc,
            thumbnailURL: thumb,
            videoURL: url,
            duration: max(1, duration),
            viewCount: 0,
            likeCount: 0,
            creator: User(username: creatorName.replacingOccurrences(of: " ", with: "_").lowercased(), displayName: creatorName, email: ""),
            category: VideoCategory(rawValue: category) ?? .entertainment,
            tags: [],
            isPublic: true
        )
    }
}


