import Foundation
import AVFoundation

/// Phase 93: AVAssetDownloadTask Offline DRM Persistence
/// Downloads HLS streams and requests persistent FairPlay keys so they can be played offline.
@MainActor
final class OfflineDRMDownloader: NSObject, ObservableObject {
    static let shared = OfflineDRMDownloader()
    
    private var downloadSession: AVAssetDownloadURLSession!
    @Published var activeDownloads: [URL: Double] = [:] // URL to Progress
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.mychannel.drm.download")
        downloadSession = AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: .main)
    }
    
    /// Starts downloading an HLS playlist and its DRM keys
    func downloadAsset(url: URL, title: String) {
        let asset = AVURLAsset(url: url)
        
        // When dealing with FairPlay, AVAssetResourceLoaderDelegate would normally
        // intercept key requests. We set it up in DRMEngine.swift.
        
        guard let task = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000] // Prefer lower bitrate for offline
        ) else {
            print("⚠️ [DRMDownloader] Failed to create download task for \(url)")
            return
        }
        
        task.resume()
        activeDownloads[url] = 0.0
        print("📥 [DRMDownloader] Started downloading HLS asset: \(title)")
    }
    
    func cancelDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.cancel()
                Task { @MainActor in
                    self.activeDownloads.removeValue(forKey: url)
                }
            }
        }
    }
}

extension OfflineDRMDownloader: AVAssetDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        
        let url = assetDownloadTask.urlAsset.url
        Task { @MainActor in
            self.activeDownloads[url] = percentComplete
            // print("⏳ [DRMDownloader] Download progress for \(url.lastPathComponent): \(percentComplete * 100)%")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        let url = assetDownloadTask.urlAsset.url
        Task { @MainActor in
            self.activeDownloads.removeValue(forKey: url)
            print("✅ [DRMDownloader] Successfully downloaded HLS asset to: \(location.path)")
            
            // Save the local URL to UserDefaults or SwiftData to play from later
            UserDefaults.standard.set(location.path, forKey: "offline_\(url.absoluteString)")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("⚠️ [DRMDownloader] Download failed: \(error)")
        }
    }
}
