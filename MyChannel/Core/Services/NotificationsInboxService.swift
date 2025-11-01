import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct InboxNotification: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let body: String
    let type: String
    let createdAt: Date
    var read: Bool
}

@MainActor
final class NotificationsInboxService: ObservableObject {
    static let shared = NotificationsInboxService()
    private init() {}

    @Published var items: [InboxNotification] = []

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    func listen(userId: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = db.collection("notifications").document(userId).collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                guard let docs = snapshot?.documents else { return }
                self.items = docs.compactMap { doc in
                    let d = doc.data()
                    return InboxNotification(
                        id: doc.documentID,
                        title: (d["title"] as? String) ?? "",
                        body: (d["body"] as? String) ?? "",
                        type: (d["type"] as? String) ?? "system",
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        read: (d["read"] as? Bool) ?? false
                    )
                }
            }
        #endif
    }

    func markRead(userId: String, id: String, read: Bool = true) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("notifications").document(userId).collection("items").document(id).setData(["read": read], merge: true)
        } catch { }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove(); listener = nil
        #endif
    }
}




