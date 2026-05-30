import Foundation
import UIKit
import Combine

/// Phase 69: Memory Pressure Handler
/// Responds to UIApplication.didReceiveMemoryWarningNotification and clears caches automatically.
@MainActor
final class MemoryPressureMonitor: ObservableObject {
    static let shared = MemoryPressureMonitor()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        print("🚨 [MemoryPressure] Received memory warning! Purging caches...")
        
        // 1. Clear unused players in PlayerPoolManager
        PlayerPoolManager.shared.clearPool()
        
        // 2. Clear URLCache disk and memory
        URLCache.shared.removeAllCachedResponses()
        
        // 3. Force garbage collection (autoreleasepool boundary)
        // Swift uses ARC, but we can nudge it by clearing published states if needed
    }
}

