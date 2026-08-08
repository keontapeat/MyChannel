import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

/// Compatibility wrapper for canonical low-latency live chat and presence.
/// New surfaces should prefer `LiveStreamManager` directly.
@MainActor
final class LiveChatRTDBService: ObservableObject {
    static let shared = LiveChatRTDBService()

    @Published private(set) var messages: [LiveChatMessage] = []
    @Published private(set) var viewerCount: Int = 0

    private let database = Database.database().reference()
    private var activeStreamId: String?
    private var presenceRef: DatabaseReference?
    private var messagesQuery: DatabaseQuery?
    private var messagesHandle: DatabaseHandle?
    private var viewerCountRef: DatabaseReference?
    private var viewerCountHandle: DatabaseHandle?

    private init() {}

    struct LiveChatMessage: Identifiable, Codable {
        let id: String
        let userId: String
        let displayName: String
        let text: String
        let timestamp: TimeInterval
    }

    func joinLiveStream(streamId: String, username: String) {
        guard isValidStreamId(streamId),
              let userId = Auth.auth().currentUser?.uid else { return }

        cleanupCurrentSession()
        activeStreamId = streamId
        messages.removeAll(keepingCapacity: true)

        let connectionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let liveViewersRef = database.child("live_viewers").child(streamId)
        let newPresenceRef = liveViewersRef
            .child("viewers").child(userId).child(connectionId)
        presenceRef = newPresenceRef
        newPresenceRef.onDisconnectRemoveValue()
        newPresenceRef.setValue([
            "joinedAt": ServerValue.timestamp(),
            "displayName": String(username.prefix(100))
        ])

        let countRef = liveViewersRef.child("viewerCount")
        viewerCountRef = countRef
        viewerCountHandle = countRef.observe(.value) { [weak self] snapshot in
            let count = max(0, (snapshot.value as? NSNumber)?.intValue ?? 0)
            Task { @MainActor in self?.viewerCount = count }
        }

        let query = database.child("live_chat").child(streamId).child("messages")
            .queryOrdered(byChild: "timestamp")
            .queryLimited(toLast: 100)
        messagesQuery = query
        messagesHandle = query.observe(.childAdded) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let text = data["text"] as? String,
                  let senderId = data["userId"] as? String,
                  let displayName = data["displayName"] as? String,
                  let timestamp = data["timestamp"] as? NSNumber else { return }

            let message = LiveChatMessage(
                id: snapshot.key,
                userId: senderId,
                displayName: displayName,
                text: text,
                timestamp: timestamp.doubleValue
            )
            Task { @MainActor in
                guard let self else { return }
                self.messages.append(message)
                if self.messages.count > 200 {
                    self.messages.removeFirst(self.messages.count - 200)
                }
            }
        }
    }

    func leaveLiveStream(streamId: String) {
        guard activeStreamId == streamId else { return }
        cleanupCurrentSession()
    }

    func sendMessage(streamId: String, text: String, username: String) {
        guard isValidStreamId(streamId),
              let userId = Auth.auth().currentUser?.uid else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 500 else { return }

        database.child("live_chat").child(streamId).child("messages")
            .childByAutoId().setValue([
                "userId": userId,
                "displayName": String(username.prefix(100)),
                "text": normalized,
                "timestamp": ServerValue.timestamp()
            ])
    }

    private func cleanupCurrentSession() {
        presenceRef?.cancelDisconnectOperations()
        presenceRef?.removeValue()
        presenceRef = nil

        if let messagesQuery, let messagesHandle {
            messagesQuery.removeObserver(withHandle: messagesHandle)
        }
        if let viewerCountRef, let viewerCountHandle {
            viewerCountRef.removeObserver(withHandle: viewerCountHandle)
        }
        self.messagesQuery = nil
        self.messagesHandle = nil
        self.viewerCountRef = nil
        self.viewerCountHandle = nil
        activeStreamId = nil
        messages.removeAll()
        viewerCount = 0
    }

    private func isValidStreamId(_ streamId: String) -> Bool {
        guard !streamId.isEmpty, streamId.count <= 128 else { return false }
        return streamId.range(
            of: "^[A-Za-z0-9_-]+$",
            options: .regularExpression
        ) != nil
    }
}
