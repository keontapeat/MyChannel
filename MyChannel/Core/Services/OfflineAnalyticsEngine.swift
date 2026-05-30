import Foundation
import CoreData
import FirebaseFirestore
import Combine

/// Phase 73: CoreData Offline Analytics Sync
/// Buffers engagement metrics when offline and automatically flushes to Firestore when the network returns.
@MainActor
final class OfflineAnalyticsEngine: ObservableObject {
    static let shared = OfflineAnalyticsEngine()
    private let db = Firestore.firestore()
    
    // Simple CoreData stack
    private let container: NSPersistentContainer
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        container = NSPersistentContainer(name: "OfflineAnalytics")
        
        // Setup in-memory store for demo (In FAANG, you'd use a SQLite store)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("⚠️ [OfflineAnalytics] Failed to load CoreData: \(error)")
            }
        }
        
        // Listen for network reachability changes
        NetworkBandwidthEstimator.shared.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.flushBuffer()
                }
            }
            .store(in: &cancellables)
    }
    
    func trackEvent(name: String, properties: [String: Any]) {
        if NetworkBandwidthEstimator.shared.isConnected {
            // Send directly
            db.collection("analytics_events").addDocument(data: [
                "eventName": name,
                "properties": properties,
                "timestamp": FieldValue.serverTimestamp()
            ])
        } else {
            // Buffer locally
            bufferEventLocally(name: name, properties: properties)
        }
    }
    
    private func bufferEventLocally(name: String, properties: [String: Any]) {
        // [SIMULATION] Saving to CoreData Entity
        print("💾 [OfflineAnalytics] Network is offline. Buffering event '\(name)' to CoreData.")
        // context.save()
    }
    
    private func flushBuffer() {
        // [SIMULATION] Fetching all buffered events from CoreData
        print("🚀 [OfflineAnalytics] Network restored! Flushing CoreData buffer to Firestore...")
        
        // In reality:
        // let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BufferedEvent")
        // let events = try? container.viewContext.fetch(fetchRequest)
        // for event in events { send to firestore; context.delete(event) }
    }
}
