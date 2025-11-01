import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class SubscriptionsFeedService: ObservableObject {
    static let shared = SubscriptionsFeedService()
    private init() {}

    struct FeedItem: Identifiable, Codable, Equatable {
        let id: String
        let videoId: String
        let ownerUid: String
        let title: String
        let thumb: String
        let createdAt: Date
        let read: Bool
        
        init(id: String = UUID().uuidString, videoId: String, ownerUid: String, title: String, thumb: String, createdAt: Date, read: Bool = false) {
            self.id = id
            self.videoId = videoId
            self.ownerUid = ownerUid
            self.title = title
            self.thumb = thumb
            self.createdAt = createdAt
            self.read = read
        }
    }

    @Published var items: [FeedItem] = []
    private var listener: Any?

    func listen(uid: String) {
        stop()
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        listener = db.collection("feeds").document(uid).collection("items").order(by: "createdAt", descending: true).limit(to: 100).addSnapshotListener { [weak self] snap, _ in
            guard let self = self, let snap = snap else { return }
            self.items = snap.documents.compactMap { doc in
                let d = doc.data()
                return FeedItem(
                    id: doc.documentID,
                    videoId: (d["videoId"] as? String) ?? doc.documentID,
                    ownerUid: (d["ownerUid"] as? String) ?? "",
                    title: (d["title"] as? String) ?? "",
                    thumb: (d["thumb"] as? String) ?? "",
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    read: (d["read"] as? Bool) ?? false
                )
            }
        }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
        listener = nil
    }
}


