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
        print("💾 [VideoFirestoreService] Saving video to Firestore:")
        print("  - ID: \(video.id)")
        print("  - Title: \(video.title)")
        print("  - Creator ID: \(video.creator.id)")
        print("  - Video URL: \(video.videoURL)")
        print("  - Thumbnail URL: \(video.thumbnailURL)")
        
        let ref = db.collection("videos").document(video.id)
        let data: [String: Any] = [
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
        ]
        
        try await ref.setData(data)
        print("✅ [VideoFirestoreService] Video saved successfully to Firestore")
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
            print("📺 [VideoFirestoreService] Fetching videos for creator: \(creatorId)")
            let snap = try await db.collection("videos")
                .whereField("userId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            print("📺 [VideoFirestoreService] Found \(snap.documents.count) videos in Firestore")
            
            let videos = snap.documents.compactMap { doc in
                let d = doc.data()
                print("  - Video: \(d["title"] as? String ?? "untitled") (id: \(doc.documentID))")
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
            print("✅ [VideoFirestoreService] Returning \(videos.count) videos")
            return videos
        } catch {
            print("🚨 [VideoFirestoreService] Error fetching videos: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    // Alias method for getUserVideos
    func getUserVideos(userId: String, limit: Int = 24) async throws -> [Video] {
        return await fetchVideosByCreator(creatorId: userId, limit: limit)
    }
    
    // MARK: - Real-time View Count Updates
    func incrementViewCount(videoId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            print("👁️ [VideoFirestoreService] Incrementing view count for video: \(videoId)")
            let ref = db.collection("videos").document(videoId)
            
            // Increment the video's view count
            try await ref.updateData([
                "viewCount": FieldValue.increment(Int64(1))
            ])
            print("✅ [VideoFirestoreService] View count incremented successfully")
            
            // Get the video's creator ID to update their total views
            let videoDoc = try await ref.getDocument()
            if let videoData = videoDoc.data(),
               let creatorId = videoData["userId"] as? String {
                print("👤 [VideoFirestoreService] Incrementing total views for creator: \(creatorId)")
                let userRef = db.collection("users").document(creatorId)
                try await userRef.updateData([
                    "totalViews": FieldValue.increment(Int64(1))
                ])
                print("✅ [VideoFirestoreService] Creator total views incremented")
                
                // Update local user if it's the current user
                if let currentUser = AppState.shared.currentUser, currentUser.id == creatorId {
                    if let updatedUserData = try? await userRef.getDocument().data() {
                        let updatedUser = User(
                            id: currentUser.id,
                            username: currentUser.username,
                            displayName: currentUser.displayName,
                            email: currentUser.email,
                            profileImageURL: currentUser.profileImageURL,
                            bannerImageURL: currentUser.bannerImageURL,
                            bio: currentUser.bio,
                            subscriberCount: currentUser.subscriberCount,
                            videoCount: currentUser.videoCount,
                            isVerified: currentUser.isVerified,
                            isCreator: currentUser.isCreator,
                            createdAt: currentUser.createdAt,
                            location: currentUser.location,
                            website: currentUser.website,
                            socialLinks: currentUser.socialLinks,
                            followerCount: currentUser.followerCount,
                            followingCount: currentUser.followingCount,
                            joinDate: currentUser.joinDate,
                            totalViews: (updatedUserData["totalViews"] as? Int) ?? ((currentUser.totalViews ?? 0) + 1),
                            totalEarnings: currentUser.totalEarnings,
                            membershipTiers: currentUser.membershipTiers,
                            bannerVideoURL: currentUser.bannerVideoURL,
                            bannerVideoMuted: currentUser.bannerVideoMuted,
                            bannerVideoContentMode: currentUser.bannerVideoContentMode
                        )
                        await MainActor.run {
                            AppState.shared.currentUser = updatedUser
                            AuthenticationManager.shared.currentUser = updatedUser
                        }
                        print("✅ [VideoFirestoreService] Local user totalViews updated to: \(updatedUser.totalViews)")
                    }
                }
            }
            
            // Notify profile and Creator Studio to refresh stats
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCreatorStudio"), object: videoId)
            }
        } catch {
            print("⚠️ [VideoFirestoreService] Failed to increment view count: \(error)")
        }
        #endif
    }
}


