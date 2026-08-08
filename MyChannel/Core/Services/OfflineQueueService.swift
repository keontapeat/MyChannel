//
//  OfflineQueueService.swift
//  MyChannel
//
//  Phase 4: Network Resilience — offline-first write queue.
//  Queues writes (likes, comments, uploads) when offline and retries when network returns.
//

import Foundation
import Network
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

enum QueuedActionType: String, Codable {
    case like
    case unlike
    case comment
    case subscribe
    case unsubscribe
    case watchProgress
}

struct QueuedAction: Identifiable, Codable {
    let id: String
    let type: QueuedActionType
    let payload: [String: String]   // key-value pairs for the action
    let createdAt: Date
    var retryCount: Int

    init(id: String = UUID().uuidString, type: QueuedActionType,
         payload: [String: String], createdAt: Date = Date(), retryCount: Int = 0) {
        self.id = id; self.type = type; self.payload = payload
        self.createdAt = createdAt; self.retryCount = retryCount
    }
}

// MARK: - Service

@MainActor
final class OfflineQueueService: ObservableObject {
    static let shared = OfflineQueueService()

    @Published private(set) var isOnline: Bool = true
    @Published private(set) var queueCount: Int = 0

    private var queue: [QueuedAction] = []
    private let maxRetries = 5
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mychannel.networkMonitor")
    private var isProcessing = false
    private let persistKey = "offlineQueue_v1"

    private init() {
        loadFromDisk()
        startMonitoring()
    }

    // MARK: - Enqueue

    func enqueue(_ action: QueuedAction) {
        queue.append(action)
        queueCount = queue.count
        saveToDisk()

        if isOnline {
            Task { await processQueue() }
        }
    }

    /// Convenience: enqueue a like action
    func enqueueLike(videoId: String, userId: String) {
        enqueue(QueuedAction(type: .like, payload: ["videoId": videoId, "userId": userId]))
    }

    /// Convenience: enqueue a comment action
    func enqueueComment(videoId: String, userId: String, text: String, parentId: String? = nil) {
        var payload = ["videoId": videoId, "userId": userId, "text": text]
        if let pid = parentId { payload["parentId"] = pid }
        enqueue(QueuedAction(type: .comment, payload: payload))
    }

    /// Convenience: enqueue a subscribe action
    func enqueueSubscribe(channelId: String, userId: String) {
        enqueue(QueuedAction(type: .subscribe, payload: ["channelId": channelId, "userId": userId]))
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let online = path.status == .satisfied
                self?.isOnline = online
                if online { await self?.processQueue() }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Process Queue

    func processQueue() async {
        guard !isProcessing, !queue.isEmpty, isOnline else { return }
        isProcessing = true
        defer { isProcessing = false }

        var failedActions: [QueuedAction] = []

        for action in queue {
            do {
                try await execute(action)
                print("✅ [OfflineQueue] Executed: \(action.type.rawValue) (\(action.id))")
            } catch {
                var failed = action
                failed.retryCount += 1
                if failed.retryCount < maxRetries {
                    failedActions.append(failed)
                    print("⚠️ [OfflineQueue] Retry \(failed.retryCount)/\(maxRetries): \(action.type.rawValue)")
                } else {
                    print("🚨 [OfflineQueue] Dropped after \(maxRetries) retries: \(action.type.rawValue)")
                }
            }
        }

        queue = failedActions
        queueCount = queue.count
        saveToDisk()
    }

    // MARK: - Execute Action

    private func execute(_ action: QueuedAction) async throws {
        let p = action.payload

        switch action.type {
        case .like:
            guard let videoId = p["videoId"], let userId = p["userId"] else { return }
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            let videoRef = db.collection("videos").document(videoId)
            let likeRef = videoRef.collection("likes").document(userId)
            let eventRef = videoRef.collection("events").document("offline_\(action.id)")
            let batch = db.batch()
            batch.setData(["userId": userId, "createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
            batch.setData([
                "userId": userId,
                "type": "like",
                "sessionId": action.id,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: eventRef)
            try await batch.commit()
            #endif

        case .unlike:
            guard let videoId = p["videoId"], let userId = p["userId"] else { return }
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            let videoRef = db.collection("videos").document(videoId)
            let likeRef = videoRef.collection("likes").document(userId)
            let eventRef = videoRef.collection("events").document("offline_\(action.id)")
            let batch = db.batch()
            batch.deleteDocument(likeRef)
            batch.setData([
                "userId": userId,
                "type": "unlike",
                "sessionId": action.id,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: eventRef)
            try await batch.commit()
            #endif

        case .comment:
            guard let videoId = p["videoId"], let userId = p["userId"], let text = p["text"] else { return }
            try await CommentsFirestoreService.shared.post(
                videoId: videoId, userId: userId, text: text, parentId: p["parentId"]
            )

        case .subscribe:
            guard let channelId = p["channelId"], let userId = p["userId"] else { return }
            #if canImport(FirebaseFirestore)
            try await Firestore.firestore().collection("users").document(userId)
                .collection("subscriptions").document(channelId)
                .setData(["subscribedAt": FieldValue.serverTimestamp(), "isActive": true], merge: true)
            #endif

        case .unsubscribe:
            guard let channelId = p["channelId"], let userId = p["userId"] else { return }
            #if canImport(FirebaseFirestore)
            try await Firestore.firestore().collection("users").document(userId)
                .collection("subscriptions").document(channelId).delete()
            #endif

        case .watchProgress:
            guard let videoId = p["videoId"], let userId = p["userId"],
                  let posStr = p["position"], let pos = Double(posStr) else { return }
            #if canImport(FirebaseFirestore)
            try await Firestore.firestore().collection("users").document(userId)
                .collection("watch_history").document(videoId).setData([
                    "contentId": videoId,
                    "contentType": "video",
                    "watchProgress": pos,
                    "lastWatchedAt": FieldValue.serverTimestamp()
                ], merge: true)
            #endif
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: persistKey),
           let saved = try? JSONDecoder().decode([QueuedAction].self, from: data) {
            queue = saved
            queueCount = queue.count
        }
    }
}
