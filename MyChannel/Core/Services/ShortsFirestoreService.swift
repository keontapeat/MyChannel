import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class ShortsFirestoreService: ObservableObject {
    static let shared = ShortsFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var lastSnapshot: DocumentSnapshot?
    #endif

    func resetPaging() {
        #if canImport(FirebaseFirestore)
        lastSnapshot = nil
        #endif
    }

    func fetchNextPage(limit: Int = 10) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            var query: Query = db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            if let last = lastSnapshot { query = query.start(afterDocument: last) }
            let snap = try await query.getDocuments()
            lastSnapshot = snap.documents.last
            return snap.documents.compactMap { doc in
                let d = doc.data()
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? (d["thumbnailURL"] as? String ?? ""),
                    videoURL: d["videoUrl"] as? String ?? (d["videoURL"] as? String ?? ""),
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .shorts,
                    aspectRatio: .portrait,
                    isLiveStream: false
                )
            }
        } catch {
            return []
        }
        #else
        return []
        #endif
    }
}




