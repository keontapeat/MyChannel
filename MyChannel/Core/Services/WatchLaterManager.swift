import Foundation
import Combine

/// Phase 18: Smart Watch-Later Queue (Persistent Local Database)
/// Manages a persistent queue of videos to watch later.
@MainActor
final class WatchLaterManager: ObservableObject {
    static let shared = WatchLaterManager()
    
    @Published private(set) var queue: [String] = [] // Array of Video IDs
    
    private let queueKey = "mychannel.watchLaterQueue"
    
    private init() {
        loadQueue()
    }
    
    private func loadQueue() {
        if let saved = UserDefaults.standard.stringArray(forKey: queueKey) {
            queue = saved
        }
    }
    
    private func saveQueue() {
        UserDefaults.standard.set(queue, forKey: queueKey)
    }
    
    func addToQueue(videoId: String) {
        guard !queue.contains(videoId) else { return }
        queue.append(videoId)
        saveQueue()
    }
    
    func removeFromQueue(videoId: String) {
        queue.removeAll { $0 == videoId }
        saveQueue()
    }
    
    func popNextVideoId() -> String? {
        guard !queue.isEmpty else { return nil }
        let nextId = queue.removeFirst()
        saveQueue()
        return nextId
    }
    
    func clearQueue() {
        queue.removeAll()
        saveQueue()
    }
}
