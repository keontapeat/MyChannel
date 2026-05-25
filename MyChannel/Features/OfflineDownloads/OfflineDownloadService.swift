//
//  OfflineDownloadService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import Foundation
import Combine
import AVFoundation
import SwiftUI
import FirebaseStorage

// MARK: - Offline Download Service (YouTube Premium Parity)
@MainActor
class OfflineDownloadService: ObservableObject {
    static let shared = OfflineDownloadService()
    
    @Published var downloads: [OfflineDownload] = []
    @Published var downloadQueue: [DownloadQueueItem] = []
    @Published var isDownloading = false
    @Published var totalDownloadProgress: Double = 0.0
    @Published var availableStorage: Int64 = 0
    @Published var usedStorage: Int64 = 0
    
    // Download settings
    @Published var downloadQuality: DownloadQuality = .medium
    @Published var downloadOnlyOnWiFi = true
    @Published var autoDeleteWatchedVideos = false
    @Published var maxStorageLimit: Int64 = 5 * 1024 * 1024 * 1024 // 5GB default
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    // Download directory
    private var downloadsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("OfflineVideos")
    }
    
    private init() {
        setupDownloadService()
        loadExistingDownloads()
        updateStorageInfo()
    }
    
    // MARK: - Download Management
    
    /// Download video for offline viewing
    func downloadVideo(
        _ video: Video,
        quality: DownloadQuality? = nil
    ) async throws -> OfflineDownload {
        
        // Check if already downloaded or in queue
        if downloads.contains(where: { $0.videoId == video.id }) {
            throw OfflineDownloadError.alreadyDownloaded
        }
        
        if downloadQueue.contains(where: { $0.download.videoId == video.id }) {
            throw OfflineDownloadError.alreadyInQueue
        }
        
        // Check storage availability
        let estimatedSize = estimateDownloadSize(quality: quality ?? downloadQuality)
        if usedStorage + estimatedSize > maxStorageLimit {
            throw OfflineDownloadError.insufficientStorage
        }
        
        // Check network conditions
        if downloadOnlyOnWiFi && !isOnWiFi() {
            throw OfflineDownloadError.wifiRequired
        }
        
        let download = OfflineDownload(
            id: UUID().uuidString,
            videoId: video.id,
            title: video.title,
            thumbnailURL: video.thumbnailURL,
            duration: video.duration,
            remoteVideoURL: video.videoURL,
            quality: quality ?? downloadQuality,
            status: .queued,
            progress: 0.0,
            downloadedAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            fileSize: 0
        )
        
        // Add to queue
        let queueItem = DownloadQueueItem(
            id: UUID().uuidString,
            download: download,
            priority: OfflineDownloadPriority.normal,
            addedAt: Date()
        )
        
        downloadQueue.append(queueItem)
        
        // Start download if not already downloading
        if !isDownloading {
            await processDownloadQueue()
        }
        
        return download
    }
    
    /// Cancel download
    func cancelDownload(_ downloadId: String) async {
        // Remove from queue
        downloadQueue.removeAll { $0.download.id == downloadId }

        // Mark as failed
        if let index = downloads.firstIndex(where: { $0.id == downloadId }) {
            downloads[index].status = .failed
            persistDownloads()
        }

        // Remove partial files
        let partialURL = downloadsDirectory.appendingPathComponent("\(downloadId).tmp")
        try? fileManager.removeItem(at: partialURL)
    }
    
    /// Delete downloaded video
    func deleteDownload(_ downloadId: String) async throws {
        guard let downloadIndex = downloads.firstIndex(where: { $0.id == downloadId }) else {
            throw OfflineDownloadError.downloadNotFound
        }
        
        let download = downloads[downloadIndex]
        
        // Delete video file
        let videoURL = downloadsDirectory.appendingPathComponent("\(download.videoId).mp4")
        try fileManager.removeItem(at: videoURL)
        
        // Delete thumbnail if exists
        let thumbnailURL = downloadsDirectory.appendingPathComponent("\(download.videoId)_thumb.jpg")
        try? fileManager.removeItem(at: thumbnailURL)
        
        // Remove from downloads
        downloads.remove(at: downloadIndex)
        
        // Update storage info
        updateStorageInfo()
    }
    
    /// Get offline video for playback
    func getOfflineVideo(_ videoId: String) -> URL? {
        guard downloads.contains(where: { $0.videoId == videoId && $0.status == .completed }) else {
            return nil
        }
        
        let videoURL = downloadsDirectory.appendingPathComponent("\(videoId).mp4")
        return fileManager.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    /// Check if video is available offline
    func isVideoAvailableOffline(_ videoId: String) -> Bool {
        return getOfflineVideo(videoId) != nil
    }
    
    // MARK: - Download Queue Processing
    
    private func processDownloadQueue() async {
        guard !downloadQueue.isEmpty && !isDownloading else { return }

        isDownloading = true

        // Sort queue by priority
        downloadQueue.sort(by: { $0.priority.rawValue > $1.priority.rawValue })

        // Process one at a time, wait for completion before next
        while let queueItem = downloadQueue.first {
            await startDownload(queueItem.download)

            // Wait for this download to complete before moving to next
            await waitForDownloadCompletion(downloadId: queueItem.download.id)

            // Remove from queue after completion
            downloadQueue.removeFirst()
        }

        isDownloading = false
    }

    private func waitForDownloadCompletion(downloadId: String) async {
        // Poll for completion (up to 10 minutes)
        for _ in 0..<3000 {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            if let download = downloads.first(where: { $0.id == downloadId }) {
                if download.status == .completed || download.status == .failed {
                    return
                }
            }
        }
    }
    
    private func startDownload(_ download: OfflineDownload) async {
        // Create download directory if needed
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        // Update download status
        if let index = downloads.firstIndex(where: { $0.id == download.id }) {
            downloads[index].status = .downloading
        } else {
            var updatedDownload = download
            updatedDownload.status = .downloading
            downloads.append(updatedDownload)
        }
        persistDownloads()

        // Download using Firebase Storage SDK (handles auth automatically)
        let storage = Storage.storage()
        let gsURL = download.remoteVideoURL

        // Check if it's a gs:// URL or https:// Firebase Storage URL
        let reference: StorageReference?
        if gsURL.hasPrefix("gs://") {
            reference = storage.reference(forURL: gsURL)
        } else {
            // Convert https:// to gs:// format
            let path = gsURL.replacingOccurrences(of: "https://firebasestorage.googleapis.com/v0/b/", with: "gs://")
            reference = storage.reference(forURL: path)
        }

        guard let ref = reference else {
            if let index = downloads.firstIndex(where: { $0.id == download.id }) {
                downloads[index].status = .failed
                persistDownloads()
            }
            return
        }

        let destinationURL = downloadsDirectory.appendingPathComponent("\(download.videoId).mp4")

        do {
            // Download to temp file first, then move to final location
            let tempURL = downloadsDirectory.appendingPathComponent("\(download.videoId).tmp")
            try await ref.write(toFile: tempURL)

            // Move to final location
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)

            // Update download status to completed
            if let index = downloads.firstIndex(where: { $0.id == download.id }) {
                downloads[index].status = .completed
                downloads[index].progress = 1.0
                downloads[index].fileSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                persistDownloads()
                updateStorageInfo()
            }
        } catch {
            if let index = downloads.firstIndex(where: { $0.id == download.id }) {
                downloads[index].status = .failed
                persistDownloads()
            }
            print("Download failed: \(error)")
        }
    }
    
    // MARK: - Storage Management
    
    func updateStorageInfo() {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: downloadsDirectory.path)
            availableStorage = attributes[.systemFreeSize] as? Int64 ?? 0
            
            // Calculate used storage
            usedStorage = calculateUsedStorage()
        } catch {
            print("Failed to get storage info: \(error)")
        }
    }
    
    private func calculateUsedStorage() -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attributes.fileSize ?? 0)
            }
        } catch {
            print("Failed to calculate storage: \(error)")
        }
        
        return totalSize
    }
    
    func cleanupExpiredDownloads() async {
        let now = Date()
        let expiredDownloads = downloads.filter { $0.expiresAt < now }
        
        for download in expiredDownloads {
            try? await deleteDownload(download.id)
        }
    }
    
    func cleanupWatchedVideos() async {
        guard autoDeleteWatchedVideos else { return }
        
        // This would integrate with watch history to identify watched videos
        // For now, we'll implement a simple cleanup based on last accessed time
    }
    
    // MARK: - Utility Methods
    
    private func setupDownloadService() {
        // Monitor network changes
        NotificationCenter.default.publisher(for: .networkDidChange)
            .sink { [weak self] _ in
                Task {
                    await self?.handleNetworkChange()
                }
            }
            .store(in: &cancellables)
        
        // Periodic cleanup
        Timer.publish(every: 3600, on: .main, in: .common) // Every hour
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.cleanupExpiredDownloads()
                    await self?.cleanupWatchedVideos()
                    self?.updateStorageInfo()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadExistingDownloads() {
        let manifestURL = downloadsDirectory.appendingPathComponent("downloads_manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            downloads = []
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let decoded = try JSONDecoder().decode([OfflineDownload].self, from: data)
            downloads = decoded.filter { download in
                let videoURL = downloadsDirectory.appendingPathComponent("\(download.videoId).mp4")
                return download.status != .completed || fileManager.fileExists(atPath: videoURL.path)
            }
        } catch {
            downloads = []
            print("Failed to load offline downloads: \(error)")
        }
    }

    private func estimateDownloadSize(quality: DownloadQuality) -> Int64 {
        // Estimate download size based on quality
        switch quality {
        case .low: return 50 * 1024 * 1024 // 50MB
        case .medium: return 150 * 1024 * 1024 // 150MB
        case .high: return 300 * 1024 * 1024 // 300MB
        case .hd: return 400 * 1024 * 1024 // 400MB
        case .highest: return 500 * 1024 * 1024 // 500MB
        }
    }
    
    private func isOnWiFi() -> Bool {
        // Check if device is connected to WiFi
        // This would use Network framework
        return true // Placeholder
    }
    
    private func handleNetworkChange() async {
        // Firebase Storage downloads handle network changes automatically
    }

    private func persistDownloads() {
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        let manifestURL = downloadsDirectory.appendingPathComponent("downloads_manifest.json")
        do {
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            print("Failed to persist offline downloads: \(error)")
        }
    }
}

// MARK: - Models

struct OfflineDownload: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
    let remoteVideoURL: String
    let quality: DownloadQuality
    var status: DownloadStatus
    var progress: Double
    let downloadedAt: Date
    let expiresAt: Date
    var fileSize: Int
}

struct DownloadQueueItem: Identifiable {
    let id: String
    let download: OfflineDownload
    let priority: OfflineDownloadPriority
    let addedAt: Date
}

enum DownloadStatus: String, Codable {
    case queued, downloading, completed, failed, paused
}

enum OfflineDownloadPriority: Int {
    case low = 1, normal = 2, high = 3
}

enum OfflineDownloadError: LocalizedError {
    case alreadyDownloaded
    case alreadyInQueue
    case insufficientStorage
    case wifiRequired
    case downloadNotFound
    case networkError
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .alreadyDownloaded:
            return "This video is already downloaded"
        case .alreadyInQueue:
            return "This video is already in the download queue"
        case .insufficientStorage:
            return "Not enough storage space available"
        case .wifiRequired:
            return "Wi-Fi connection required for downloads"
        case .downloadNotFound:
            return "Download not found"
        case .networkError:
            return "A network error occurred. Please try again"
        case .fileSystemError:
            return "Unable to save the download. Please try again"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let networkDidChange = Notification.Name("networkDidChange")
}
