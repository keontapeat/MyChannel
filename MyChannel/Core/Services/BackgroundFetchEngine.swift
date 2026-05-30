import Foundation
import BackgroundTasks

/// Phase 88: Background Tasks Framework
/// Uses BGTaskScheduler to wake the app up overnight and pre-download the user's favorite channel uploads.
@MainActor
final class BackgroundFetchEngine {
    static let shared = BackgroundFetchEngine()
    
    private let refreshTaskId = "com.mychannel.background.refresh"
    
    private init() {}
    
    /// Must be called early in application(_:didFinishLaunchingWithOptions:)
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskId, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        print("🌙 [BackgroundFetch] Registered BGAppRefreshTask: \(refreshTaskId)")
    }
    
    /// Schedules the next background fetch. Call when the app goes into the background.
    func scheduleNextFetch() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        
        // Fetch no earlier than 6 hours from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🕒 [BackgroundFetch] Scheduled next background fetch.")
        } catch {
            print("⚠️ [BackgroundFetch] Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the *next* operation as soon as we wake up
        scheduleNextFetch()
        
        task.expirationHandler = {
            // OS says we are out of time, cancel any pending network requests
            print("⚠️ [BackgroundFetch] Background task expired.")
        }
        
        print("📥 [BackgroundFetch] Woke up in background. Pre-caching recommended videos...")
        
        // [SIMULATED] Fetch recommended videos from Firestore and use SmartPrecacheEngine
        Task.detached {
            // E.g., await Firestore query...
            let fakeURLs = [
                URL(string: "https://mychannel.app/videos/overnight_1.mp4")!,
                URL(string: "https://mychannel.app/videos/overnight_2.mp4")!
            ]
            
            await SmartPrecacheEngine.shared.prefetchTopRecommendations(urls: fakeURLs)
            
            // Tell the OS we finished successfully
            print("✅ [BackgroundFetch] Finished background caching.")
            task.setTaskCompleted(success: true)
        }
    }
}
