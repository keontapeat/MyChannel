import Foundation
import FirebaseFirestore

/// Phase 49: Watch History Sync Engine
/// Implements an offline-first CRDT (Conflict-free Replicated Data Type) structure to sync watch history.
@MainActor
final class HistorySyncEngine: ObservableObject {
    static let shared = HistorySyncEngine()
    private let db = Firestore.firestore()
    
    // In-memory cache of CRDT states
    @Published var historyData: [String: WatchRecord] = [:]
    
    private init() {
        loadLocalData()
    }
    
    /// Called continuously during playback to record progress
    func updateProgress(for videoId: String, timestamp: Double) {
        let now = Date().timeIntervalSince1970
        
        let record = WatchRecord(
            videoId: videoId,
            lastWatchedTimestamp: timestamp,
            updatedAt: now
        )
        
        // CRDT Logic: Last Write Wins (LWW) based on updatedAt
        if let existing = historyData[videoId] {
            if existing.updatedAt < now {
                historyData[videoId] = record
                saveLocalAndSync(record)
            }
        } else {
            historyData[videoId] = record
            saveLocalAndSync(record)
        }
    }
    
    private func saveLocalAndSync(_ record: WatchRecord) {
        // 1. Save to local UserDefaults immediately
        if let encoded = try? JSONEncoder().encode(historyData) {
            UserDefaults.standard.set(encoded, forKey: "HistorySyncEngine_Data")
        }
        
        // 2. Sync to Firestore (Offline supported natively by Firebase)
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        let docRef = db.collection("users").document(userId).collection("history").document(record.videoId)
        
        docRef.setData([
            "videoId": record.videoId,
            "lastWatchedTimestamp": record.lastWatchedTimestamp,
            "updatedAt": record.updatedAt
        ], merge: true)
    }
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: "HistorySyncEngine_Data"),
           let decoded = try? JSONDecoder().decode([String: WatchRecord].self, from: data) {
            self.historyData = decoded
        }
    }
    
    /// Called on app launch to pull the latest CRDT states from the server
    func pullFromServer() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        do {
            let snapshot = try await db.collection("users").document(userId).collection("history").getDocuments()
            
            var hasChanges = false
            for doc in snapshot.documents {
                let data = doc.data()
                guard let videoId = data["videoId"] as? String,
                      let timestamp = data["lastWatchedTimestamp"] as? Double,
                      let updatedAt = data["updatedAt"] as? Double else { continue }
                
                let incoming = WatchRecord(videoId: videoId, lastWatchedTimestamp: timestamp, updatedAt: updatedAt)
                
                // CRDT Merge: LWW
                if let local = historyData[videoId] {
                    if incoming.updatedAt > local.updatedAt {
                        historyData[videoId] = incoming
                        hasChanges = true
                    }
                } else {
                    historyData[videoId] = incoming
                    hasChanges = true
                }
            }
            
            if hasChanges {
                if let encoded = try? JSONEncoder().encode(historyData) {
                    UserDefaults.standard.set(encoded, forKey: "HistorySyncEngine_Data")
                }
            }
        } catch {
            print("⚠️ [HistorySyncEngine] Failed to pull history: \(error)")
        }
    }
}

struct WatchRecord: Codable, Equatable {
    let videoId: String
    let lastWatchedTimestamp: Double
    let updatedAt: Double
}
