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
    private let urlSession: URLSession
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Download directory
    private var downloadsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("OfflineVideos")
    }
    
    private init() {
        // Configure URL session for downloads
        let config = URLSessionConfiguration.background(withIdentifier: "com.mychannel.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        urlSession = URLSession(configuration: config, delegate: DownloadDelegate(), delegateQueue: nil)
        
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
        
        // Cancel active download task
        if let task = downloadTasks[downloadId] {
            task.cancel()
            downloadTasks.removeValue(forKey: downloadId)
        }
        
        // Remove partial files
        await cleanupPartialDownload(downloadId)
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
        
        while let queueItem = downloadQueue.first {
            do {
                await startDownload(queueItem.download)
                downloadQueue.removeFirst()
            } catch {
                print("Download failed: \(error)")
                downloadQueue.removeFirst()
            }
        }
        
        isDownloading = false
    }
    
    private func startDownload(_ download: OfflineDownload) async {
        // Get video stream URL
        guard let streamURL = await getVideoStreamURL(download.videoId, quality: download.quality) else {
            return
        }
        
        // Create download directory if needed
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        // Start download task
        let downloadTask = urlSession.downloadTask(with: streamURL)
        downloadTasks[download.id] = downloadTask
        
        // Update download status
        if let index = downloads.firstIndex(where: { $0.id == download.id }) {
            downloads[index].status = .downloading
        } else {
            var updatedDownload = download
            updatedDownload.status = .downloading
            downloads.append(updatedDownload)
        }
        
        downloadTask.resume()
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
        // Load downloads from persistent storage
        // This would typically use Core Data or similar
        downloads = [] // Placeholder
    }
    
    private func getVideoStreamURL(_ videoId: String, quality: DownloadQuality) async -> URL? {
        // Get appropriate stream URL based on quality
        // This would integrate with your video streaming service
        return URL(string: "https://example.com/stream/\(videoId)")
    }
    
    private func estimateDownloadSize(quality: DownloadQuality) -> Int64 {
        // Estimate download size based on quality
        switch quality {
        case .low: return 50 * 1024 * 1024 // 50MB
        case .medium: return 150 * 1024 * 1024 // 150MB
        case .high: return 300 * 1024 * 1024 // 300MB
        case .highest: return 500 * 1024 * 1024 // 500MB
        }
    }
    
    private func isOnWiFi() -> Bool {
        // Check if device is connected to WiFi
        // This would use Network framework
        return true // Placeholder
    }
    
    private func handleNetworkChange() async {
        if downloadOnlyOnWiFi && !isOnWiFi() {
            // Pause all downloads
            for (_, task) in downloadTasks {
                task.suspend()
            }
        } else {
            // Resume downloads
            for (_, task) in downloadTasks {
                task.resume()
            }
        }
    }
    
    private func cleanupPartialDownload(_ downloadId: String) async {
        // Clean up any partial download files
        let partialURL = downloadsDirectory.appendingPathComponent("\(downloadId).tmp")
        try? fileManager.removeItem(at: partialURL)
    }
}

// MARK: - Download Delegate

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handle completed download
        Task { @MainActor in
            await OfflineDownloadService.shared.handleDownloadCompletion(task: downloadTask, location: location)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Update download progress
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            await OfflineDownloadService.shared.updateDownloadProgress(task: downloadTask, progress: progress)
        }
    }
}

// MARK: - Download Completion Handling

extension OfflineDownloadService {
    func handleDownloadCompletion(task: URLSessionDownloadTask, location: URL) async {
        // Find the download associated with this task
        guard let downloadId = downloadTasks.first(where: { $0.value == task })?.key,
              let downloadIndex = downloads.firstIndex(where: { $0.id == downloadId }) else {
            return
        }
        
        var download = downloads[downloadIndex]
        
        do {
            // Move downloaded file to final location
            let finalURL = downloadsDirectory.appendingPathComponent("\(download.videoId).mp4")
            try fileManager.moveItem(at: location, to: finalURL)
            
            // Update download status
            download.status = .completed
            download.progress = 1.0
            download.fileSize = try finalURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            
            downloads[downloadIndex] = download
            
            // Clean up
            downloadTasks.removeValue(forKey: downloadId)
            
            // Update storage info
            updateStorageInfo()
            
        } catch {
            download.status = .failed
            downloads[downloadIndex] = download
            print("Failed to complete download: \(error)")
        }
    }
    
    func updateDownloadProgress(task: URLSessionDownloadTask, progress: Double) async {
        guard let downloadId = downloadTasks.first(where: { $0.value == task })?.key,
              let downloadIndex = downloads.firstIndex(where: { $0.id == downloadId }) else {
            return
        }
        
        downloads[downloadIndex].progress = progress
        
        // Update total progress
        let totalProgress = downloads.reduce(0.0) { $0 + $1.progress } / Double(downloads.count)
        self.totalDownloadProgress = totalProgress
    }
}

// MARK: - Models

struct OfflineDownload: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
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
