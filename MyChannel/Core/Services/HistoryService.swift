import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class HistoryService: ObservableObject {
    static let shared = HistoryService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func logStart(userId: String, video: Video) async {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("history").document(userId).collection("items").document(video.id)
            try await ref.setData([
                "videoId": video.id,
                "title": video.title,
                "creatorId": video.creator.id,
                "thumbnailURL": video.thumbnailURL,
                "createdAt": FieldValue.serverTimestamp(),
                "lastWatchedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }

    func fetch(userId: String, limit: Int = 50) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("history").document(userId).collection("items")
                .order(by: "lastWatchedAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: "",
                    thumbnailURL: d["thumbnailURL"] as? String ?? "",
                    videoURL: "",
                    duration: 0,
                    viewCount: 0,
                    likeCount: 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .entertainment
                )
            }
        } catch { return [] }
        #else
        return []
        #endif
    }
}


