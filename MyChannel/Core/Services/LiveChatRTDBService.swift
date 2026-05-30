import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

/// Manages ultra-low latency live chat messages and user presence
/// during a live stream using Firebase Realtime Database.
final class LiveChatRTDBService: ObservableObject {
    static let shared = LiveChatRTDBService()
    
    private let db = Database.database().reference()
    
    @Published var messages: [LiveChatMessage] = []
    @Published var viewerCount: Int = 0
    
    private var messagesHandle: DatabaseHandle?
    private var viewersHandle: DatabaseHandle?
    
    private init() {}
    
    struct LiveChatMessage: Identifiable, Codable {
        var id: String
        let userId: String
        let username: String
        let text: String
        let timestamp: TimeInterval
        let isSuperChat: Bool
        let superChatAmount: Double?
    }
    
    /// Joins a live stream chat room, sets up presence, and starts listening for messages
    func joinLiveStream(streamId: String, username: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let streamRef = db.child("live_streams").child(streamId)
        
        // 1. Presence System
        let myConnectionsRef = streamRef.child("viewers").child(userId)
        
        // Add to connected list when online
        myConnectionsRef.setValue(true)
        
        // Remove from connected list when disconnected (automatically handled by RTDB)
        myConnectionsRef.onDisconnectRemoveValue()
        
        // Track overall viewer count
        viewersHandle = streamRef.child("viewers").observe(.value) { [weak self] snapshot in
            self?.viewerCount = Int(snapshot.childrenCount)
        }
        
        // 2. Chat Messages Listener
        messagesHandle = streamRef.child("messages")
            .queryOrdered(byChild: "timestamp")
            .queryLimited(toLast: 100)
            .observe(.childAdded) { [weak self] snapshot in
                guard let data = snapshot.value as? [String: Any],
                      let text = data["text"] as? String,
                      let senderId = data["userId"] as? String,
                      let senderName = data["username"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval else { return }
                
                let isSuperChat = data["isSuperChat"] as? Bool ?? false
                let amount = data["superChatAmount"] as? Double
                
                let message = LiveChatMessage(
                    id: snapshot.key,
                    userId: senderId,
                    username: senderName,
                    text: text,
                    timestamp: timestamp,
                    isSuperChat: isSuperChat,
                    superChatAmount: amount
                )
                
                DispatchQueue.main.async {
                    self?.messages.append(message)
                    // Keep memory bounded
                    if self?.messages.count ?? 0 > 200 {
                        self?.messages.removeFirst()
                    }
                }
            }
    }
    
    /// Leaves the live stream, cleaning up listeners and presence
    func leaveLiveStream(streamId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let streamRef = db.child("live_streams").child(streamId)
        streamRef.child("viewers").child(userId).removeValue()
        
        if let messagesHandle = messagesHandle {
            streamRef.child("messages").removeObserver(withHandle: messagesHandle)
        }
        if let viewersHandle = viewersHandle {
            streamRef.child("viewers").removeObserver(withHandle: viewersHandle)
        }
        
        self.messages.removeAll()
        self.viewerCount = 0
    }
    
    /// Sends a message to the live stream
    func sendMessage(streamId: String, text: String, username: String, isSuperChat: Bool = false, amount: Double? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let streamRef = db.child("live_streams").child(streamId)
        let messageRef = streamRef.child("messages").childByAutoId()
        
        var messageData: [String: Any] = [
            "userId": userId,
            "username": username,
            "text": text,
            "timestamp": ServerValue.timestamp()
        ]
        
        if isSuperChat {
            messageData["isSuperChat"] = true
            messageData["superChatAmount"] = amount
        }
        
        messageRef.setValue(messageData)
    }
}
