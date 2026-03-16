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

    func addOrUpdateHistoryItem(_ item: WatchHistoryItem, userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("history").document(userId).collection("items").document(item.id)
            try await ref.setData([
                "contentType": item.contentType.rawValue,
                "contentId": item.contentId,
                "title": item.title,
                "thumbnailURL": item.thumbnailURL,
                "creatorName": item.creatorName,
                "creatorId": item.creatorId,
                "duration": item.duration,
                "watchedAt": Timestamp(date: item.watchedAt),
                "watchProgress": item.watchProgress,
                "lastPosition": item.lastPosition
            ], merge: true)
        } catch {
            print("⚠️ Failed to save history item: \(error.localizedDescription)")
        }
        #endif
    }
    
    func updateProgress(itemId: String, userId: String, progress: Double, position: TimeInterval) async {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("history").document(userId).collection("items").document(itemId)
            try await ref.updateData([
                "watchProgress": progress,
                "lastPosition": position,
                "watchedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("⚠️ Failed to update progress: \(error.localizedDescription)")
        }
        #endif
    }

    func logStart(userId: String, video: Video) async {
        let item = WatchHistoryItem.fromVideo(video)
        await addOrUpdateHistoryItem(item, userId: userId)
    }

    func fetch(userId: String, limit: Int = 100) async -> [WatchHistoryItem] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("history").document(userId).collection("items")
                .order(by: "watchedAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                guard let contentTypeRaw = d["contentType"] as? String,
                      let contentType = WatchHistoryItem.ContentType(rawValue: contentTypeRaw),
                      let contentId = d["contentId"] as? String,
                      let title = d["title"] as? String,
                      let thumbnailURL = d["thumbnailURL"] as? String,
                      let creatorName = d["creatorName"] as? String,
                      let creatorId = d["creatorId"] as? String,
                      let duration = d["duration"] as? TimeInterval else {
                    return nil
                }
                
                let watchedAt = (d["watchedAt"] as? Timestamp)?.dateValue() ?? Date()
                let watchProgress = d["watchProgress"] as? Double ?? 0.0
                let lastPosition = d["lastPosition"] as? TimeInterval ?? 0.0
                
                return WatchHistoryItem(
                    id: doc.documentID,
                    contentType: contentType,
                    contentId: contentId,
                    title: title,
                    thumbnailURL: thumbnailURL,
                    creatorName: creatorName,
                    creatorId: creatorId,
                    duration: duration,
                    watchedAt: watchedAt,
                    watchProgress: watchProgress,
                    lastPosition: lastPosition
                )
            }
        } catch {
            print("⚠️ Failed to fetch history: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    func removeItem(itemId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("history").document(userId).collection("items").document(itemId)
            try await ref.delete()
        } catch {
            print("⚠️ Failed to remove history item: \(error.localizedDescription)")
        }
        #endif
    }
    
    func clearAll(userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("history").document(userId).collection("items").getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
        } catch {
            print("⚠️ Failed to clear history: \(error.localizedDescription)")
        }
        #endif
    }
}


