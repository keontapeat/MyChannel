import Foundation
import FirebaseFirestore
import Combine

/// Phase 53: Live Real-time Chat Engine
/// Twitch/YouTube style live chat overlay, optimized for high-velocity streams.
@MainActor
final class LiveChatEngine: ObservableObject {
    static let shared = LiveChatEngine()
    private let db = Firestore.firestore()
    
    @Published var messages: [LiveChatMessage] = []
    private var listener: ListenerRegistration?
    
    // In high-velocity streams, we throttle UI updates to 10 FPS to prevent CPU thrashing
    private var messageBuffer: [LiveChatMessage] = []
    private var flushTimer: Timer?
    
    private init() {}
    
    func connectToChat(videoId: String) {
        listener?.remove()
        messages.removeAll()
        messageBuffer.removeAll()
        
        // Setup 10 FPS batch flusher
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushBuffer()
            }
        }
        
        let query = db.collection("videos").document(videoId).collection("liveChat")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            
            // Only process added documents to avoid re-rendering entire list
            snapshot?.documentChanges.forEach { diff in
                if diff.type == .added {
                    let data = diff.document.data()
                    guard let id = data["id"] as? String,
                          let userId = data["userId"] as? String,
                          let username = data["username"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else { return }
                    
                    let isSuperChat = data["isSuperChat"] as? Bool ?? false
                    let amount = data["amount"] as? Double ?? 0.0
                    
                    let msg = LiveChatMessage(id: id, userId: userId, username: username, text: text, timestamp: timestamp.dateValue(), isSuperChat: isSuperChat, amount: amount)
                    self.messageBuffer.append(msg)
                }
            }
        }
    }
    
    func disconnect() {
        listener?.remove()
        listener = nil
        flushTimer?.invalidate()
        flushTimer = nil
    }
    
    private func flushBuffer() {
        guard !messageBuffer.isEmpty else { return }
        
        // Append all buffered messages and sort by timestamp ascending
        var newArray = self.messages + messageBuffer
        newArray.sort(by: { $0.timestamp < $1.timestamp })
        
        // Keep max 100 messages in memory
        if newArray.count > 100 {
            newArray.removeFirst(newArray.count - 100)
        }
        
        self.messages = newArray
        self.messageBuffer.removeAll()
    }
    
    func sendMessage(_ text: String, videoId: String, isSuperChat: Bool = false, amount: Double = 0.0) {
        guard let user = AuthenticationManager.shared.currentUser else { return }
        
        let messageId = UUID().uuidString
        let docRef = db.collection("videos").document(videoId).collection("liveChat").document(messageId)
        
        docRef.setData([
            "id": messageId,
            "userId": user.id,
            "username": user.displayName,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "isSuperChat": isSuperChat,
            "amount": amount
        ])
    }
    struct LiveChatMessage: Identifiable, Codable, Equatable {
        let id: String
        let userId: String
        let username: String
        let text: String
        let timestamp: Date
        let isSuperChat: Bool
        let amount: Double
    }
}
