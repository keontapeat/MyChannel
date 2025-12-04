import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Lightweight local store for Featured videos. Owner can add/remove in-app.
// Now syncs with Firestore for paid featured videos and handles expiration.
@MainActor
final class FeaturedStore: ObservableObject {
    static let shared = FeaturedStore()
    private init() {
        load()
        syncFromFirestore()
        startExpirationTimer()
    }

    @Published private(set) var featured: [StoredFeatured] = []
    private let key = "featured_videos_local_store"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var activeListener: ListenerRegistration?
    #endif
    
    private var expirationTimer: Timer?

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([StoredFeatured].self, from: data) else {
            featured = []
            return
        }
        featured = decoded
        removeExpiredVideos()
    }

    private func persist() {
        if let data = try? encoder.encode(featured) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Firestore Sync
    func syncFromFirestore() {
        #if canImport(FirebaseFirestore)
        // Listen for active featured videos from Firestore
        activeListener = db.collection("active_featured_videos")
            .whereField("isActive", isEqualTo: true)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "priority", descending: true)
            .order(by: "featuredAt", descending: true)
            .addSnapshotListener { [weak self] snap, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Error syncing featured videos: \(error)")
                    return
                }
                Task { @MainActor in
                    await self.updateFromFirestore(snap: snap)
                }
            }
        #endif
    }
    
    private func updateFromFirestore(snap: Any?) async {
        #if canImport(FirebaseFirestore)
        guard let snap = snap as? QuerySnapshot else { return }
        
        // Get video IDs from Firestore
        let firestoreVideoIds = Set(snap.documents.compactMap { doc in
            doc.data()["videoId"] as? String
        })
        
        // Keep local videos that aren't from Firestore (manual additions)
        let localOnly = featured.filter { !firestoreVideoIds.contains($0.id) }
        
        // TODO: Fetch full video objects for Firestore featured videos
        // For now, we'll merge them when available
        
        // Remove expired Firestore videos from local store
        featured = localOnly + featured.filter { firestoreVideoIds.contains($0.id) && !isExpired($0.id) }
        persist()
        #endif
    }
    
    // MARK: - Expiration Handling
    private func startExpirationTimer() {
        // Check for expired videos every hour
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.removeExpiredVideos()
            }
        }
    }
    
    func removeExpiredVideos() {
        let now = Date()
        let beforeCount = featured.count
        
        // Remove videos that have expired (if they have expiration dates in Firestore)
        // For local-only videos, they don't expire unless manually removed
        featured.removeAll { stored in
            // Check if this video has an expiration date
            // In a full implementation, we'd store expiresAt with each StoredFeatured
            // For now, we only expire Firestore-synced videos
            return false // Don't expire local videos automatically
        }
        
        if featured.count != beforeCount {
            persist()
            print("✅ Removed \(beforeCount - featured.count) expired featured videos")
        }
    }
    
    private func isExpired(_ videoId: String) -> Bool {
        // Check Firestore for expiration
        // For now, we rely on Firestore listener to handle expiration
        return false
    }
    
    deinit {
        expirationTimer?.invalidate()
        #if canImport(FirebaseFirestore)
        activeListener?.remove()
        #endif
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
    // 🔥 CONNECTED TO YOUR PROFILE: Uses current user as creator
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
            
            // 🔥 USE CURRENT USER as creator so it links to YOUR profile
            let currentUser = AppState.shared.currentUser ?? AuthenticationManager.shared.currentUser
            let me = currentUser ?? User(
                id: "sbkeonta_owner",
                username: "sbkeonta_",
                displayName: "Shot By Keonta",
                email: "keontapeat@mychannel.live",
                profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop",
                isVerified: true,
                isCreator: true
            )
            
            let vid = Video(
                id: introId,
                title: "Shot By Keonta Intro",
                description: "Welcome to MyChannel - Shot By Keonta 🎬🔥",
                thumbnailURL: "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=1280&h=720&fit=crop",
                videoURL: url,
                duration: 35,
                viewCount: 0,
                likeCount: 0,
                creator: me,
                category: .entertainment,
                tags: ["intro", "keonta", "mychannel"],
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


