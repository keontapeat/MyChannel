import Foundation
import FirebaseFirestore
import Combine

/// Phase 42: Live Interactive Polling System
/// Manages real-time synced polling during live broadcasts.
@MainActor
final class LivePollingService: ObservableObject {
    static let shared = LivePollingService()
    private let db = Firestore.firestore()
    
    @Published var currentPoll: Poll?
    private var listener: ListenerRegistration?
    
    private init() {}
    
    func startListeningForPolls(videoId: String) {
        listener?.remove()
        
        let docRef = db.collection("videos").document(videoId).collection("polls").document("active")
        listener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else {
                self?.currentPoll = nil
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let poll = try JSONDecoder().decode(Poll.self, from: jsonData)
                self.currentPoll = poll
            } catch {
                print("⚠️ [LivePollingService] Failed to parse poll: \(error)")
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        currentPoll = nil
    }
    
    func vote(optionId: String, videoId: String) {
        // In a real FAANG app, use FieldValue.increment(1) to avoid race conditions
        let docRef = db.collection("videos").document(videoId).collection("polls").document("active")
        docRef.updateData([
            "options.\(optionId).votes": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("⚠️ [LivePollingService] Failed to vote: \(error)")
            } else {
                print("✅ [LivePollingService] Vote cast successfully.")
            }
        }
    }
    struct Poll: Codable, Equatable {
        let id: String
        let question: String
        var options: [String: PollOption]
    }
    
    struct PollOption: Codable, Equatable {
        let id: String
        let text: String
        var votes: Int
    }
}
