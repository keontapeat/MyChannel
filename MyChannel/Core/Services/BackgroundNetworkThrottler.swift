import Foundation

/// Phase 56: Background Network Throttler
/// Configures URLSession for background task network throttling.
final class BackgroundNetworkThrottler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let shared = BackgroundNetworkThrottler()
    
    private(set) var backgroundSession: URLSession!
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.mychannel.background.uploads")
        
        // Optimize for background performance and device battery
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForResource = 60 * 60 * 24 // Allow up to 24 hours for large uploads
        
        // Let the OS throttle based on network conditions
        config.networkServiceType = .background
        
        self.backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func scheduleBackgroundUpload(fileURL: URL, destinationURL: URL) {
        var request = URLRequest(url: destinationURL)
        request.httpMethod = "PUT"
        
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.resume()
        print("☁️ [BackgroundThrottler] Scheduled background upload task.")
    }
    
    // MARK: - URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("⚠️ [BackgroundThrottler] Upload failed in background: \(error)")
        } else {
            print("✅ [BackgroundThrottler] Upload completed in background.")
        }
    }
}
