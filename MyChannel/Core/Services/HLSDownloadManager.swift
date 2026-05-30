import Foundation
import AVFoundation

/// Phase 45: HLS Offline Download Manager
/// Uses AVAssetDownloadTask to securely download DRM-protected HLS streams.
final class HLSDownloadManager: NSObject, ObservableObject {
    static let shared = HLSDownloadManager()
    
    @Published var activeDownloads: [URL: Double] = [:] // URL to Progress
    
    private var downloadSession: AVAssetDownloadURLSession!
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.mychannel.hls.download")
        downloadSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
    }
    
    /// Starts an HLS download
    func startDownload(url: URL, title: String) {
        let asset = AVURLAsset(url: url)
        
        // Target 1080p if available (or highest quality under 20Mbps)
        let options: [String: Any] = [
            AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 20_000_000
        ]
        
        guard let task = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title,
            assetArtworkData: nil,
            options: options
        ) else { return }
        
        activeDownloads[url] = 0.0
        task.resume()
        print("📥 [HLSDownload] Started downloading: \(title)")
    }
    
    func pauseDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.suspend()
                print("⏸️ [HLSDownload] Paused download.")
            }
        }
    }
    
    func resumeDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.resume()
                print("▶️ [HLSDownload] Resumed download.")
            }
        }
    }
    
    func cancelDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.cancel()
                DispatchQueue.main.async {
                    self.activeDownloads.removeValue(forKey: url)
                }
                print("❌ [HLSDownload] Cancelled download.")
            }
        }
    }
}

extension HLSDownloadManager: AVAssetDownloadDelegate {
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        
        var percentComplete: Double = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        
        let url = assetDownloadTask.urlAsset.url
        DispatchQueue.main.async {
            self.activeDownloads[url] = percentComplete
        }
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        print("✅ [HLSDownload] Finished downloading to: \(location)")
        // In a real app, you would persist this bookmark data to UserDefaults or CoreData.
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        print("⚠️ [HLSDownload] Task completed with error: \(error)")
    }
}
