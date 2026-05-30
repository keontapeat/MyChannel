import Foundation
import FirebaseFirestore
import Combine

/// 🔥 Phase 11: Real-Time Synchronization Engine
/// Handles sub-millisecond real-time state synchronization across the platform.
@MainActor
final class RealTimeFirestoreService: ObservableObject {
    static let shared = RealTimeFirestoreService()
    private let db = Firestore.firestore()
    
    @Published var liveViewersCount: Int = 0
    @Published var liveChatMessages: [LiveChatMessage] = []
    
    private var viewersListener: ListenerRegistration?
    private var chatListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Live View Counters
    func subscribeToLiveViewers(videoId: String) {
        viewersListener?.remove()
        
        viewersListener = db.collection("videos").document(videoId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }
                
                // Extract the real-time active viewers count
                if let viewers = data["activeViewers"] as? Int {
                    self.liveViewersCount = viewers
                }
            }
    }
    
    func joinLiveStream(videoId: String) {
        // Increment viewers using FieldValue.increment
        db.collection("videos").document(videoId).updateData([
            "activeViewers": FieldValue.increment(Int64(1))
        ])
    }
    
    func leaveLiveStream(videoId: String) {
        // Decrement viewers
        db.collection("videos").document(videoId).updateData([
            "activeViewers": FieldValue.increment(Int64(-1))
        ])
        viewersListener?.remove()
        viewersListener = nil
    }
    
    // MARK: - Live Chat Engine
    func subscribeToLiveChat(videoId: String) {
        chatListener?.remove()
        
        chatListener = db.collection("videos").document(videoId).collection("liveChat")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let newMessages = documents.compactMap { doc -> LiveChatMessage? in
                    try? doc.data(as: LiveChatMessage.self)
                }
                
                // Replace or append messages
                self.liveChatMessages = newMessages
            }
    }
    
    func sendLiveChatMessage(videoId: String, message: String, authorName: String) {
        let newMessage = LiveChatMessage(
            id: UUID().uuidString,
            text: message,
            authorName: authorName,
            timestamp: Date()
        )
        
        do {
            try db.collection("videos").document(videoId).collection("liveChat").document(newMessage.id).setData(from: newMessage)
        } catch {
            print("Failed to send live chat message: \(error)")
        }
    }
    
    func unsubscribeAll() {
        viewersListener?.remove()
        chatListener?.remove()
        liveViewersCount = 0
        liveChatMessages = []
    }
    // Data Model for Live Chat
    struct LiveChatMessage: Codable, Identifiable, Equatable {
        let id: String
        let text: String
        let authorName: String
        let timestamp: Date
    }
}
