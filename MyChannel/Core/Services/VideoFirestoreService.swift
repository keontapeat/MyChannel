//
//  VideoFirestoreService.swift
//  MyChannel
//
//  Firestore-backed video reads and likes.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class VideoFirestoreService: ObservableObject {
    static let shared = VideoFirestoreService()
    private init() {}
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func toggleLike(videoId: String, userId: String, add: Bool) async {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId).collection("likes").document(userId)
        do {
            if add { try await ref.setData(["likedAt": FieldValue.serverTimestamp()]) }
            else { try await ref.delete() }
        } catch { print("video like error: \(error)") }
        #endif
    }

    func saveVideo(_ video: Video) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(video.id)
        try await ref.setData([
            "userId": video.creator.id,
            "title": video.title,
            "description": video.description,
            "thumbnailUrl": video.thumbnailURL,
            "videoUrl": video.videoURL,
            "duration": video.duration,
            "viewCount": video.viewCount,
            "likeCount": video.likeCount,
            "commentCount": video.commentCount,
            "category": video.category.rawValue,
            "tags": video.tags,
            "isPublic": video.isPublic,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    func deleteVideo(videoId: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId)
        try await ref.delete()
        #endif
    }

    func fetchVideosByCreator(creatorId: String, limit: Int = 24) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("videos")
                .whereField("userId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                    videoURL: d["videoUrl"] as? String ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .entertainment
                )
            }
        } catch { return [] }
        #else
        return []
        #endif
    }
    
    // Alias method for getUserVideos
    func getUserVideos(userId: String, limit: Int = 24) async throws -> [Video] {
        return await fetchVideosByCreator(creatorId: userId, limit: limit)
    }
}


