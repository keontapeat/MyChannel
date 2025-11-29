//
//  ShortsDownloadManager.swift
//  MyChannel
//
//  📱🔥 SHORTS DOWNLOAD MANAGER 🔥📱
//  Download Shorts/Flicks for offline viewing
//
//  Features:
//  - Batch download shorts
//  - Smart shorts recommendations
//  - Vertical video optimization
//  - Quick offline access
//  - Storage-efficient encoding
//

import Foundation
import Combine

// MARK: - Shorts Download Manager
@MainActor
final class ShortsDownloadManager: ObservableObject {
    static let shared = ShortsDownloadManager()
    
    // MARK: - Published State
    @Published private(set) var downloadedShorts: [DownloadedShort] = []
    @Published private(set) var downloadQueue: [String] = []
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var currentDownloadProgress: Double = 0
    
    // MARK: - Settings
    @Published var autoDownloadLikedShorts: Bool = false
    @Published var maxShortsToKeep: Int = 100
    @Published var preferredQuality: ShortDownloadQuality = .high
    @Published var downloadFromSubscriptions: Bool = true
    
    // MARK: - Private Properties
    private let nuclearManager = NuclearDownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        loadSettings()
        loadDownloadedShorts()
        
        print("📱 [ShortsDownload] Manager initialized")
    }
    
    // MARK: - Public API
    
    /// Download a short for offline viewing
    func downloadShort(_ short: Flick) async throws -> DownloadedShort {
        // Check if already downloaded
        if let existing = downloadedShorts.first(where: { $0.id == short.id }) {
            return existing
        }
        
        // Convert Flick to Video for nuclear download
        let video = Video(
            id: short.id,
            title: short.caption,
            description: short.caption,
            thumbnailURL: short.thumbnailURL,
            videoURL: short.videoURL,
            duration: short.duration,
            viewCount: short.viewCount,
            likeCount: short.likeCount,
            commentCount: short.commentCount,
            creator: short.creator,
            uploadDate: short.uploadDate,
            isLive: false
        )
        
        // Add to queue
        downloadQueue.append(short.id)
        isDownloading = true
        
        do {
            // Use nuclear download manager
            let download = try await nuclearManager.downloadVideo(
                video,
                quality: mapQuality(preferredQuality),
                priority: .high
            )
            
            // Create downloaded short entry
            let downloadedShort = DownloadedShort(
                id: short.id,
                caption: short.caption,
                thumbnailURL: short.thumbnailURL,
                duration: short.duration,
                creatorId: short.creator.id,
                creatorName: short.creator.displayName,
                creatorAvatar: short.creator.avatarURL ?? "",
                downloadDate: Date(),
                localVideoURL: download.localVideoURL,
                localThumbnailURL: download.localThumbnailURL,
                quality: preferredQuality,
                fileSize: download.totalBytes,
                viewCount: short.viewCount,
                likeCount: short.likeCount,
                isWatched: false,
                watchCount: 0
            )
            
            downloadedShorts.append(downloadedShort)
            downloadQueue.removeAll { $0 == short.id }
            isDownloading = downloadQueue.isEmpty ? false : true
            
            // Enforce max limit
            enforceStorageLimit()
            
            saveDownloadedShorts()
            
            print("📱 [ShortsDownload] Downloaded: \(short.caption)")
            
            return downloadedShort
            
        } catch {
            downloadQueue.removeAll { $0 == short.id }
            isDownloading = downloadQueue.isEmpty ? false : true
            throw error
        }
    }
    
    /// Download multiple shorts
    func downloadShorts(_ shorts: [Flick]) async -> [Result<DownloadedShort, Error>] {
        var results: [Result<DownloadedShort, Error>] = []
        
        for short in shorts {
            do {
                let downloaded = try await downloadShort(short)
                results.append(.success(downloaded))
            } catch {
                results.append(.failure(error))
            }
        }
        
        return results
    }
    
    /// Delete a downloaded short
    func deleteShort(_ id: String) async {
        // Find the short
        guard let short = downloadedShorts.first(where: { $0.id == id }) else { return }
        
        // Find corresponding nuclear download and delete
        if let download = nuclearManager.downloads.first(where: { $0.videoId == id }) {
            try? await nuclearManager.deleteDownload(download.id)
        }
        
        // Remove from local list
        downloadedShorts.removeAll { $0.id == id }
        saveDownloadedShorts()
        
        print("📱 [ShortsDownload] Deleted: \(short.caption)")
    }
    
    /// Delete all downloaded shorts
    func deleteAllShorts() async {
        for short in downloadedShorts {
            if let download = nuclearManager.downloads.first(where: { $0.videoId == short.id }) {
                try? await nuclearManager.deleteDownload(download.id)
            }
        }
        
        downloadedShorts.removeAll()
        saveDownloadedShorts()
        
        print("📱 [ShortsDownload] Deleted all shorts")
    }
    
    /// Check if a short is downloaded
    func isShortDownloaded(_ id: String) -> Bool {
        return downloadedShorts.contains { $0.id == id }
    }
    
    /// Get offline URL for a short
    func getOfflineURL(_ id: String) -> URL? {
        return downloadedShorts.first { $0.id == id }?.localVideoURL
    }
    
    /// Mark short as watched
    func markAsWatched(_ id: String) {
        guard let index = downloadedShorts.firstIndex(where: { $0.id == id }) else { return }
        
        downloadedShorts[index].isWatched = true
        downloadedShorts[index].watchCount += 1
        downloadedShorts[index].lastWatchedAt = Date()
        
        saveDownloadedShorts()
    }
    
    /// Get recommended shorts to download
    func getRecommendedShorts() async -> [Flick] {
        // This would integrate with shorts/flicks service
        // For now, return empty
        return []
    }
    
    /// Auto-download shorts from subscriptions
    func autoDownloadFromSubscriptions() async {
        guard downloadFromSubscriptions else { return }
        guard nuclearManager.networkStatus == .wifi else { return }
        
        let recommended = await getRecommendedShorts()
        let toDownload = recommended.filter { !isShortDownloaded($0.id) }.prefix(10)
        
        for short in toDownload {
            _ = try? await downloadShort(short)
        }
    }
    
    // MARK: - Storage Management
    
    private func enforceStorageLimit() {
        while downloadedShorts.count > maxShortsToKeep {
            // Remove oldest watched shorts first
            if let oldestWatched = downloadedShorts
                .filter({ $0.isWatched })
                .sorted(by: { ($0.lastWatchedAt ?? .distantPast) < ($1.lastWatchedAt ?? .distantPast) })
                .first {
                
                Task {
                    await deleteShort(oldestWatched.id)
                }
            } else if let oldest = downloadedShorts.sorted(by: { $0.downloadDate < $1.downloadDate }).first {
                // Remove oldest if no watched shorts
                Task {
                    await deleteShort(oldest.id)
                }
            } else {
                break
            }
        }
    }
    
    /// Get total storage used by shorts
    var totalStorageUsed: Int64 {
        downloadedShorts.reduce(0) { $0 + $1.fileSize }
    }
    
    /// Get formatted storage string
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
    
    // MARK: - Helpers
    
    private func mapQuality(_ quality: ShortDownloadQuality) -> NuclearDownloadQuality {
        switch quality {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    // MARK: - Persistence
    
    private func saveDownloadedShorts() {
        if let data = try? JSONEncoder().encode(downloadedShorts) {
            userDefaults.set(data, forKey: "downloaded_shorts")
        }
        saveSettings()
    }
    
    private func loadDownloadedShorts() {
        guard let data = userDefaults.data(forKey: "downloaded_shorts"),
              let shorts = try? JSONDecoder().decode([DownloadedShort].self, from: data) else {
            return
        }
        downloadedShorts = shorts
    }
    
    private func saveSettings() {
        userDefaults.set(autoDownloadLikedShorts, forKey: "shorts_auto_download_liked")
        userDefaults.set(maxShortsToKeep, forKey: "shorts_max_keep")
        userDefaults.set(preferredQuality.rawValue, forKey: "shorts_quality")
        userDefaults.set(downloadFromSubscriptions, forKey: "shorts_download_subs")
    }
    
    private func loadSettings() {
        autoDownloadLikedShorts = userDefaults.bool(forKey: "shorts_auto_download_liked")
        maxShortsToKeep = userDefaults.integer(forKey: "shorts_max_keep")
        if maxShortsToKeep == 0 { maxShortsToKeep = 100 }
        
        if let qualityRaw = userDefaults.string(forKey: "shorts_quality"),
           let quality = ShortDownloadQuality(rawValue: qualityRaw) {
            preferredQuality = quality
        }
        
        downloadFromSubscriptions = userDefaults.bool(forKey: "shorts_download_subs")
    }
}

// MARK: - Models

struct DownloadedShort: Identifiable, Codable {
    let id: String
    let caption: String
    let thumbnailURL: String
    let duration: TimeInterval
    let creatorId: String
    let creatorName: String
    let creatorAvatar: String
    let downloadDate: Date
    var localVideoURL: URL?
    var localThumbnailURL: URL?
    let quality: ShortDownloadQuality
    let fileSize: Int64
    let viewCount: Int
    let likeCount: Int
    var isWatched: Bool
    var watchCount: Int
    var lastWatchedAt: Date?
    
    var formattedDuration: String {
        let seconds = Int(duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var downloadTimeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: downloadDate, relativeTo: Date())
    }
}

enum ShortDownloadQuality: String, Codable, CaseIterable {
    case low = "480p"
    case medium = "720p"
    case high = "1080p"
    
    var displayName: String {
        switch self {
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        }
    }
    
    var estimatedSize: String {
        switch self {
        case .low: return "~5MB per short"
        case .medium: return "~10MB per short"
        case .high: return "~20MB per short"
        }
    }
}

// MARK: - Flick Protocol Extension

extension Flick {
    /// Check if this flick is downloaded
    var isDownloaded: Bool {
        ShortsDownloadManager.shared.isShortDownloaded(id)
    }
    
    /// Get offline URL if downloaded
    var offlineURL: URL? {
        ShortsDownloadManager.shared.getOfflineURL(id)
    }
}
