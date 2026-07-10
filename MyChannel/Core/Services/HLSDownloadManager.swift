import Foundation
import AVFoundation

/// HLS offline downloader used by `OfflineDownloadService` for m3u8 / DRM streams.
/// Progressive MP4 downloads stay on Firebase Storage; this path is HLS-only.
final class HLSDownloadManager: NSObject, ObservableObject {
    static let shared = HLSDownloadManager()

    @Published var activeDownloads: [URL: Double] = [:]

    private var downloadSession: AVAssetDownloadURLSession!
    private var continuations: [URL: CheckedContinuation<URL, Error>] = [:]
    private var progressHandlers: [URL: (Double) -> Void] = [:]
    private var destinationTitles: [URL: String] = [:]

    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.mychannel.hls.download")
        downloadSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
    }

    /// Starts an HLS download and suspends until the asset is on disk (or fails).
    func downloadAndWait(
        url: URL,
        title: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            DispatchQueue.main.async {
                if self.continuations[url] != nil {
                    continuation.resume(throwing: HLSDownloadError.alreadyInProgress)
                    return
                }
                self.continuations[url] = continuation
                self.progressHandlers[url] = progressHandler
                self.destinationTitles[url] = title
                self.startDownload(url: url, title: title)
            }
        }
    }

    /// Starts an HLS download (fire-and-forget). Prefer `downloadAndWait` from OfflineDownloadService.
    func startDownload(url: URL, title: String) {
        let asset = AVURLAsset(url: url)
        let options: [String: Any] = [
            AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000
        ]

        guard let task = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title,
            assetArtworkData: nil,
            options: options
        ) else {
            fail(url: url, error: HLSDownloadError.taskCreationFailed)
            return
        }

        activeDownloads[url] = 0.0
        task.resume()
        print("📥 [HLSDownload] Started downloading: \(title)")
    }

    func pauseDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.suspend()
            }
        }
    }

    func resumeDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.resume()
            }
        }
    }

    func cancelDownload(url: URL) {
        downloadSession.getAllTasks { tasks in
            if let task = tasks.first(where: { ($0 as? AVAssetDownloadTask)?.urlAsset.url == url }) {
                task.cancel()
                DispatchQueue.main.async {
                    self.activeDownloads.removeValue(forKey: url)
                    self.fail(url: url, error: HLSDownloadError.cancelled)
                }
            }
        }
    }

    private func fail(url: URL, error: Error) {
        activeDownloads.removeValue(forKey: url)
        progressHandlers.removeValue(forKey: url)
        destinationTitles.removeValue(forKey: url)
        if let cont = continuations.removeValue(forKey: url) {
            cont.resume(throwing: error)
        }
    }

    private func succeed(url: URL, location: URL) {
        activeDownloads.removeValue(forKey: url)
        progressHandlers.removeValue(forKey: url)
        destinationTitles.removeValue(forKey: url)
        if let cont = continuations.removeValue(forKey: url) {
            cont.resume(returning: location)
        }
    }
}

enum HLSDownloadError: LocalizedError {
    case alreadyInProgress
    case taskCreationFailed
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress: return "HLS download already in progress"
        case .taskCreationFailed: return "Could not create HLS download task"
        case .cancelled: return "HLS download cancelled"
        case .unknown: return "Unknown HLS download error"
        }
    }
}

extension HLSDownloadManager: AVAssetDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        var percentComplete: Double = 0.0
        let expected = timeRangeExpectedToLoad.duration.seconds
        guard expected > 0 else { return }
        for value in loadedTimeRanges {
            percentComplete += value.timeRangeValue.duration.seconds / expected
        }
        let url = assetDownloadTask.urlAsset.url
        DispatchQueue.main.async {
            self.activeDownloads[url] = percentComplete
            self.progressHandlers[url]?(min(1.0, percentComplete))
        }
    }

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let url = assetDownloadTask.urlAsset.url
        print("✅ [HLSDownload] Finished downloading to: \(location)")
        DispatchQueue.main.async {
            self.succeed(url: url, location: location)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        guard let assetTask = task as? AVAssetDownloadTask else { return }
        let url = assetTask.urlAsset.url
        print("⚠️ [HLSDownload] Task completed with error: \(error)")
        DispatchQueue.main.async {
            self.fail(url: url, error: error)
        }
    }
}
