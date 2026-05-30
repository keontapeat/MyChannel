import Foundation
import CloudKit

/// Phase 83: CloudKit Public Database Sync
/// Acts as a global config fallback (e.g., retrieving featured channels or emergency killswitches) if Firestore is unreachable.
@MainActor
final class CloudKitFallbackEngine: ObservableObject {
    static let shared = CloudKitFallbackEngine()
    
    private let container = CKContainer.default()
    private let publicDB: CKDatabase
    
    @Published var featuredChannels: [String] = []
    @Published var emergencyMessage: String?
    
    private init() {
        self.publicDB = container.publicCloudDatabase
    }
    
    /// Fetches global config from CloudKit
    func fetchGlobalConfig() async {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "GlobalConfig", predicate: predicate)
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query)
            
            for (_, recordResult) in matchResults {
                if let record = try? recordResult.get() {
                    // Extract fields
                    if let channels = record["featuredChannels"] as? [String] {
                        self.featuredChannels = channels
                        print("☁️ [CloudKit] Fetched \(channels.count) featured channels as fallback.")
                    }
                    
                    if let message = record["emergencyMessage"] as? String {
                        self.emergencyMessage = message
                        print("🚨 [CloudKit] Emergency message received: \(message)")
                    }
                }
            }
        } catch {
            print("⚠️ [CloudKit] Failed to fetch global config: \(error)")
        }
    }
}
