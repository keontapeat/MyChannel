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
    
    // MARK: - Save Flick
    
    /// Save a Flick (short-form video) to Firestore
    func saveFlick(
        id: String? = nil,
        title: String,
        description: String,
        videoURL: String,
        thumbnailURL: String,
        duration: TimeInterval,
        tags: [String] = [],
        musicTrack: (title: String, artist: String)? = nil,
        userId: String,
        username: String,
        userDisplayName: String,
        userProfileImageURL: String = "",
        userIsVerified: Bool = false
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        let flickId = id ?? UUID().uuidString
        
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "videoUrl": videoURL,
            "thumbnailUrl": thumbnailURL,
            "duration": duration,
            "viewCount": 0,
            "likeCount": 0,
            "commentCount": 0,
            "shareCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "creatorId": userId,
            "creatorUsername": username,
            "creatorDisplayName": userDisplayName,
            "creatorProfileImage": userProfileImageURL,
            "creatorIsVerified": userIsVerified,
            "tags": tags,
            "aspectRatio": "portrait",
            "isPublic": true,
            "category": "shorts"
        ]
        
        if let music = musicTrack {
            data["musicTrack"] = [
                "title": music.title,
                "artist": music.artist
            ]
        }
        
        try await db.collection("shorts").document(flickId).setData(data)
        print("✅ [ShortsFirestore] Saved Flick: \(flickId)")
        
        return flickId
        #else
        throw NSError(domain: "ShortsFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }
    
    // MARK: - Update Engagement
    
    /// Increment like count
    func incrementLikeCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).updateData([
            "likeCount": FieldValue.increment(Int64(1))
        ])
        #endif
    }
    
    /// Increment view count
    func incrementViewCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
        #endif
    }
    
    /// Increment comment count
    func incrementCommentCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).updateData([
            "commentCount": FieldValue.increment(Int64(1))
        ])
        #endif
    }
    
    /// Increment share count
    func incrementShareCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).updateData([
            "shareCount": FieldValue.increment(Int64(1))
        ])
        #endif
    }
    
    // MARK: - Delete Flick
    
    /// Delete a Flick from Firestore
    func deleteFlick(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).delete()
        print("✅ [ShortsFirestore] Deleted Flick: \(flickId)")
        #endif
    }
}




