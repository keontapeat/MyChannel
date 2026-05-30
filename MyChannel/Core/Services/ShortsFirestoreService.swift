import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseStorage
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

    // MARK: - Helper: Resolve creator from shorts document
    #if canImport(FirebaseFirestore)
    private func resolveCreator(from data: [String: Any]) async -> User {
        let creatorId =
            (data["creatorId"] as? String) ??
            (data["userId"] as? String) ??
            (data["ownerUid"] as? String) ??
            ""
        
        if !creatorId.isEmpty {
            do {
                let userDoc = try await db.collection("users").document(creatorId).getDocument()
                if let userData = userDoc.data() {
                    return User(
                        id: creatorId,
                        username: (userData["username"] as? String) ?? (data["creatorUsername"] as? String) ?? "user",
                        displayName: (userData["displayName"] as? String) ?? (data["creatorDisplayName"] as? String) ?? "Creator",
                        email: (userData["email"] as? String) ?? "",
                        profileImageURL: (userData["profileImageURL"] as? String)
                            ?? (userData["profileImageUrl"] as? String)
                            ?? (data["creatorProfileImage"] as? String),
                        bannerImageURL: (userData["bannerImageURL"] as? String) ?? (userData["bannerImageUrl"] as? String),
                        bio: userData["bio"] as? String,
                        subscriberCount: (userData["subscriberCount"] as? Int) ?? 0,
                        videoCount: (userData["videoCount"] as? Int) ?? 0,
                        isVerified: (userData["isVerified"] as? Bool) ?? (data["creatorIsVerified"] as? Bool) ?? false,
                        isCreator: true,
                        createdAt: (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            } catch {
                print("⚠️ [ShortsFirestoreService] Failed to resolve creator \(creatorId): \(error)")
            }
        }
        
        let fallbackUsername = (data["creatorUsername"] as? String) ?? "user"
        let fallbackDisplayName = (data["creatorDisplayName"] as? String) ?? "Creator"
        let profileImage = data["creatorProfileImage"] as? String
        let verified = (data["creatorIsVerified"] as? Bool) ?? false
        
        return User(
            id: creatorId.isEmpty ? UUID().uuidString : creatorId,
            username: fallbackUsername,
            displayName: fallbackDisplayName,
            email: "",
            profileImageURL: profileImage,
            bannerImageURL: nil,
            bio: nil,
            subscriberCount: 0,
            videoCount: 0,
            isVerified: verified,
            isCreator: true,
            createdAt: Date()
        )
    }
    #endif

    func fetchNextPage(limit: Int = 10) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            var query: Query = db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            if let last = lastSnapshot { query = query.start(afterDocument: last) }
            let snap = try await query.getDocuments()
            lastSnapshot = snap.documents.last
            
            var results: [Video] = []
            for doc in snap.documents {
                let d = doc.data()
                let creator = await resolveCreator(from: d)
                
                var videoURL = d["videoUrl"] as? String ?? (d["videoURL"] as? String ?? "")
                var thumbnailURL = d["thumbnailUrl"] as? String ?? (d["thumbnailURL"] as? String ?? "")
                
                // 🔥 Auto-refresh expired Firebase Storage URLs
                if videoURL.contains("firebasestorage.googleapis.com") {
                    do {
                        let ref = try Storage.storage().reference(forURL: videoURL)
                        videoURL = try await ref.downloadURL().absoluteString
                    } catch {
                        print("⚠️ [ShortsFirestore] Failed to refresh video URL: \(error)")
                    }
                }
                
                if thumbnailURL.contains("firebasestorage.googleapis.com") {
                    do {
                        let ref = try Storage.storage().reference(forURL: thumbnailURL)
                        thumbnailURL = try await ref.downloadURL().absoluteString
                    } catch {
                        print("⚠️ [ShortsFirestore] Failed to refresh thumbnail URL: \(error)")
                    }
                }
                
                let video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: thumbnailURL,
                    videoURL: videoURL,
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: creator,
                    category: .shorts,
                    aspectRatio: .portrait,
                    isLiveStream: false
                )
                results.append(video)
            }
            return results
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
        try await writeShortEvent(flickId: flickId, type: "like")
        #endif
    }
    
    /// Increment view count
    func incrementViewCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await writeShortEvent(flickId: flickId, type: "view")
        #endif
    }
    
    /// Increment comment count
    func incrementCommentCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await writeShortEvent(flickId: flickId, type: "comment")
        #endif
    }
    
    /// Increment share count
    func incrementShareCount(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await writeShortEvent(flickId: flickId, type: "share")
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func writeShortEvent(flickId: String, type: String) async throws {
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        try await db.collection("shorts").document(flickId)
            .collection("events").document()
            .setData([
                "type": type,
                "userId": userId,
                "createdAt": FieldValue.serverTimestamp(),
                "deviceType": "iOS"
            ])
    }
    #endif
    
    // MARK: - Delete Flick
    
    /// Delete a Flick from Firestore
    func deleteFlick(flickId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("shorts").document(flickId).delete()
        print("✅ [ShortsFirestore] Deleted Flick: \(flickId)")
        #endif
    }
}




