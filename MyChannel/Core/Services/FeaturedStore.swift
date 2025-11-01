import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

    func move(fromOffsets: IndexSet, toOffset: Int) {
        featured.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    // Ensure owner's intro video is at the top if bundled locally
    func ensureOwnerIntroFirstIfAvailable() {
        let introId = "owner_intro_video"
        if let existingIndex = featured.firstIndex(where: { $0.id == introId }) {
            if existingIndex != 0 {
                featured.move(fromOffsets: IndexSet(integer: existingIndex), toOffset: 0)
                persist()
            }
            return
        }
        // Build video from bundle if present
        if let path = Bundle.main.path(forResource: "Shot By Keonta Intro 4k", ofType: "MP4") {
            let url = URL(fileURLWithPath: path).absoluteString
            let me = User(username: "sbkeonta_", displayName: "sbkeonta_", email: "keontapeat@mychannel.live", isVerified: true, isCreator: true)
            let vid = Video(
                id: introId,
                title: "MyChannel Intro",
                description: "Intro by Keonta",
                thumbnailURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
                videoURL: url,
                duration: 11,
                viewCount: 0,
                likeCount: 0,
                creator: me,
                category: .entertainment,
                tags: ["intro","owner"],
                isPublic: true
            )
            add(vid)
        }
    }

    // MARK: - Add From Local (Camera Roll / Files)
    func addLocalVideo(copiedFrom sourceURL: URL, title: String, creatorName: String = "Owner") throws {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("FeaturedVideos", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let ext = sourceURL.pathExtension.isEmpty ? (UTType.movie.preferredFilenameExtension ?? "mp4") : sourceURL.pathExtension
        let dest = dir.appendingPathComponent(UUID().uuidString + "." + ext)
        // If source is a security-scoped resource (e.g., Photos sandbox), try to copy
        var didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        if fileManager.fileExists(atPath: dest.path) {
            try? fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: sourceURL, to: dest)

        let owner = User(username: creatorName.replacingOccurrences(of: " ", with: "_").lowercased(),
                         displayName: creatorName,
                         email: "keontapeat@mychannel.live",
                         isVerified: true,
                         isCreator: true)
        let v = Video(
            id: "local_" + dest.lastPathComponent,
            title: title.isEmpty ? "Featured Video" : title,
            description: "Added from camera roll",
            thumbnailURL: "",
            videoURL: dest.absoluteString,
            duration: 0,
            viewCount: 0,
            likeCount: 0,
            creator: owner,
            category: .entertainment,
            tags: ["featured","local"],
            isPublic: true
        )
        add(v)
    }
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

final class PinnedVideosStore {
    static let shared = PinnedVideosStore()
    private let defaults = UserDefaults.standard
    private init() {}
    
    func key(for userId: String) -> String { "pinned_videos_\(userId)" }
    
    func getPinned(for userId: String) -> [String] {
        return defaults.stringArray(forKey: key(for: userId)) ?? []
    }
    
    func isPinned(_ videoId: String, for userId: String) -> Bool {
        return getPinned(for: userId).contains(videoId)
    }
    
    func pin(_ videoId: String, for userId: String) {
        var arr = getPinned(for: userId)
        if !arr.contains(videoId) { arr.insert(videoId, at: 0) }
        defaults.set(arr, forKey: key(for: userId))
        NotificationCenter.default.post(name: .userProfileUpdated, object: nil)
    }
    
    func unpin(_ videoId: String, for userId: String) {
        var arr = getPinned(for: userId)
        arr.removeAll { $0 == videoId }
        defaults.set(arr, forKey: key(for: userId))
        NotificationCenter.default.post(name: .userProfileUpdated, object: nil)
    }
}


