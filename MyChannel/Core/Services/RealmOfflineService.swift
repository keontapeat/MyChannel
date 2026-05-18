#if canImport(RealmSwift)
import RealmSwift
#endif
import Foundation

// MARK: - Realm Models

#if canImport(RealmSwift)
final class RealmCachedVideo: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var title: String = ""
    @Persisted var thumbnailURL: String = ""
    @Persisted var creatorName: String = ""
    @Persisted var viewCount: Int = 0
    @Persisted var cachedAt: Date = Date()
}

final class RealmWatchLaterEntry: Object {
    @Persisted(primaryKey: true) var videoId: String = ""
    @Persisted var addedAt: Date = Date()
}

final class RealmOfflineDownload: Object {
    @Persisted(primaryKey: true) var videoId: String = ""
    @Persisted var localPath: String = ""
    @Persisted var quality: String = "720p"
    @Persisted var downloadedAt: Date = Date()
    @Persisted var fileSizeBytes: Int = 0
}
#endif

/// Realm Offline-First Edge Database
/// Stores videos, watch-later, and downloaded content locally for 0ms cold starts.
@MainActor
final class RealmOfflineService: ObservableObject {
    static let shared = RealmOfflineService()

    @Published var cachedVideoCount: Int = 0
    @Published var offlineDownloadCount: Int = 0

    #if canImport(RealmSwift)
    private var realm: Realm? {
        try? Realm()
    }
    #endif

    private init() {
        Task { await refreshCounts() }
    }

    func refreshCounts() async {
        #if canImport(RealmSwift)
        guard let r = realm else { return }
        cachedVideoCount = r.objects(RealmCachedVideo.self).count
        offlineDownloadCount = r.objects(RealmOfflineDownload.self).count
        #endif
    }

    func cacheVideoMetadata(id: String, title: String, thumbnail: String, creator: String, views: Int) {
        #if canImport(RealmSwift)
        guard let r = realm else { return }
        let obj = RealmCachedVideo()
        obj.id = id; obj.title = title; obj.thumbnailURL = thumbnail
        obj.creatorName = creator; obj.viewCount = views
        try? r.write { r.add(obj, update: .modified) }
        cachedVideoCount = r.objects(RealmCachedVideo.self).count
        #endif
    }

    func getCachedVideos() -> [[String: Any]] {
        #if canImport(RealmSwift)
        guard let r = realm else { return [] }
        return r.objects(RealmCachedVideo.self).map {
            ["id": $0.id, "title": $0.title, "thumbnail": $0.thumbnailURL, "creator": $0.creatorName]
        }
        #else
        return []
        #endif
    }

    func saveOfflineDownload(videoId: String, localPath: String, quality: String, size: Int) {
        #if canImport(RealmSwift)
        guard let r = realm else { return }
        let obj = RealmOfflineDownload()
        obj.videoId = videoId; obj.localPath = localPath
        obj.quality = quality; obj.fileSizeBytes = size
        try? r.write { r.add(obj, update: .modified) }
        offlineDownloadCount = r.objects(RealmOfflineDownload.self).count
        print("✅ [Realm] Offline download saved: \(videoId) (\(quality))")
        #endif
    }

    func deleteOfflineDownload(videoId: String) {
        #if canImport(RealmSwift)
        guard let r = realm,
              let obj = r.object(ofType: RealmOfflineDownload.self, forPrimaryKey: videoId) else { return }
        try? r.write { r.delete(obj) }
        offlineDownloadCount = r.objects(RealmOfflineDownload.self).count
        #endif
    }

    func clearAll() {
        #if canImport(RealmSwift)
        guard let r = realm else { return }
        try? r.write { r.deleteAll() }
        cachedVideoCount = 0; offlineDownloadCount = 0
        print("✅ [Realm] All offline data cleared.")
        #endif
    }
}
