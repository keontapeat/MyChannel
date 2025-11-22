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
        
        // 🔥 FIX: Check if video already exists to preserve viewCount
        let existingDoc = try? await ref.getDocument()
        let existingViewCount = existingDoc?.data()?["viewCount"] as? Int
        
        // 🔥 FIX: Preserve existing viewCount if video already exists
        // NEVER reset viewCount to 0 when updating video metadata
        let viewCountToSave: Int
        if let existingCount = existingViewCount {
            // Video exists - ALWAYS preserve existing count (even if 0)
            viewCountToSave = existingCount
            print("  🔥 Preserving existing viewCount: \(existingCount)")
        } else {
            // New video - initialize to 0 (or use video's count if provided)
            viewCountToSave = max(video.viewCount, 0)
            print("  📊 Initializing viewCount for new video: \(viewCountToSave)")
        }
        
        let data: [String: Any] = [
            "userId": video.creator.id,
            "title": video.title,
            "description": video.description,
            "thumbnailUrl": video.thumbnailURL,
            "videoUrl": video.videoURL,
            "duration": video.duration,
            "viewCount": viewCountToSave,  // 🔥 FIX: Preserve existing count
            "likeCount": video.likeCount,
            "commentCount": video.commentCount,
            "category": video.category.rawValue,
            "tags": video.tags,
            "isPublic": video.visibility == .public,
            "visibility": video.visibility.rawValue,
            "createdAt": existingDoc?.data()?["createdAt"] ?? FieldValue.serverTimestamp(),  // Preserve original createdAt
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // 🔥 FIX: Use merge: true to preserve existing fields (especially viewCount)
        try await ref.setData(data, merge: true)
        print("✅ [VideoFirestoreService] Video saved successfully to Firestore (viewCount preserved: \(viewCountToSave))")
        #endif
    }
    
    func deleteVideo(videoId: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId)
        try await ref.delete()
        #endif
    }
    
    func updateVideoVisibility(videoId: String, visibility: Video.VisibilityStatus) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId)
        try await ref.updateData([
            "visibility": visibility.rawValue,
            "isPublic": visibility == .public,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    // 🔥 THERMONUCLEAR: Batch operations for 10x faster writes
    func saveMultipleVideos(_ videos: [Video]) async throws {
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        
        // Firestore batch limit is 500 operations
        for video in videos.prefix(500) {
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
            batch.setData(data, forDocument: ref, merge: true)
        }
        
        try await batch.commit()
        print("✅ [VideoFirestore] Batch saved \(min(videos.count, 500)) videos in ONE operation!")
        #endif
    }
    
    // 🔥 THERMONUCLEAR: Batch increment view counts
    func incrementMultipleViewCounts(_ videoIds: [String]) async throws {
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        
        for videoId in videoIds.prefix(500) {
            let ref = db.collection("videos").document(videoId)
            batch.updateData(["viewCount": FieldValue.increment(Int64(1))], forDocument: ref)
        }
        
        try await batch.commit()
        print("✅ [VideoFirestore] Batch incremented \(min(videoIds.count, 500)) view counts!")
        #endif
    }
    
    // 🔥 THERMONUCLEAR: Batch fetch multiple videos (faster than individual fetches)
    func fetchMultipleVideos(videoIds: [String]) async throws -> [Video] {
        #if canImport(FirebaseFirestore)
        guard !videoIds.isEmpty else { return [] }
        
        // Firestore 'in' query limit is 10
        var allVideos: [Video] = []
        
        for chunk in videoIds.chunked(into: 10) {
            let snapshot = try await db.collection("videos")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            let videos = snapshot.documents.compactMap { doc -> Video? in
                try? doc.data(as: Video.self)
            }
            allVideos.append(contentsOf: videos)
        }
        
        print("✅ [VideoFirestore] Batch fetched \(allVideos.count) videos")
        return allVideos
        #else
        return []
        #endif
    }

    func fetchVideosByCreator(creatorId: String, limit: Int = 24, startAfter: DocumentSnapshot? = nil) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            print("📺 [VideoFirestoreService] Fetching videos for creator: \(creatorId), limit: \(limit)")
            var query: Query = db.collection("videos")
                .whereField("userId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            // ⚡ PERFORMANCE: Add pagination support
            if let startAfter = startAfter {
                query = query.start(afterDocument: startAfter)
            }
            
            // 🔥 THERMONUCLEAR: Try cache first for instant loads (only if no pagination)
            if startAfter == nil {
                if let cachedSnapshot = try? await query.getDocuments(source: .cache) {
                    let cachedVideos = cachedSnapshot.documents.compactMap { doc -> Video? in
                        try? doc.data(as: Video.self)
                    }
                    if !cachedVideos.isEmpty {
                        print("⚡ [VideoFirestore] Loaded \(cachedVideos.count) creator videos from cache (instant!)")
                        return cachedVideos
                    }
                }
            }
            
            let snap = try await query.getDocuments()
            print("📺 [VideoFirestoreService] Found \(snap.documents.count) videos in Firestore")
            
            // 🔥 FIX: Use for-loop instead of compactMap since we need async/await
            var videos: [Video] = []
            for doc in snap.documents {
                let d = doc.data()
                
                // 🔥 FIX: ALWAYS fetch viewCount from Firestore first (never default to 0)
                var viewCount = 0
                if let firestoreCount = d["viewCount"] as? Int {
                    viewCount = firestoreCount
                } else if let firestoreCount = d["viewCount"] as? Int64 {
                    viewCount = Int(firestoreCount)
                } else {
                    // Field doesn't exist - initialize it to 0 in Firestore
                    print("  ⚠️ [VideoFirestoreService] viewCount missing for \(doc.documentID), initializing to 0")
                    try? await db.collection("videos").document(doc.documentID).updateData([
                        "viewCount": 0
                    ])
                }
                
                print("  - Video: \(d["title"] as? String ?? "untitled") (id: \(doc.documentID)) - Firestore viewCount: \(viewCount)")
                
                // 🔥 FIX: Get real-time view count from tracker (which fetches from Firestore)
                // This ensures we have the most up-to-date count
                let trackerCount = await RealtimeViewTracker.shared.getViewCount(for: doc.documentID)
                
                // Use the higher of the two (Firestore or tracker cache)
                let finalViewCount = max(viewCount, trackerCount)
                
                if trackerCount != viewCount {
                    print("  📊 View count sync: Firestore=\(viewCount), Tracker=\(trackerCount), Using=\(finalViewCount)")
                }
                
                let storedIsPublic = (d["isPublic"] as? Bool) ?? true
                let storedVisibilityRaw = (d["visibility"] as? String)?.lowercased()
                let visibilityStatus = Video.VisibilityStatus(rawValue: storedVisibilityRaw ?? "") ?? (storedIsPublic ? .public : .private)
                
                let video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                    videoURL: d["videoUrl"] as? String ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: finalViewCount, // 🔥 FIX: Use the synced count
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .entertainment,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: storedIsPublic,
                    visibility: visibilityStatus
                )
                videos.append(video)
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
    
    // ⚡ PERFORMANCE: Paginated fetch with last document tracking
    func fetchVideosByCreatorPaginated(creatorId: String, limit: Int = 24, lastDocument: DocumentSnapshot? = nil) async throws -> (videos: [Video], lastDocument: DocumentSnapshot?) {
        #if canImport(FirebaseFirestore)
        do {
            var query: Query = db.collection("videos")
                .whereField("userId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }
            
            let snap = try await query.getDocuments()
            let lastDoc = snap.documents.last
            
            var videos: [Video] = []
            for doc in snap.documents {
                let d = doc.data()
                
                // 🔥 FIX: ALWAYS fetch viewCount from Firestore first (same as fetchVideosByCreator)
                var viewCount = 0
                if let firestoreCount = d["viewCount"] as? Int {
                    viewCount = firestoreCount
                } else if let firestoreCount = d["viewCount"] as? Int64 {
                    viewCount = Int(firestoreCount)
                } else {
                    // Field doesn't exist - initialize it to 0 in Firestore
                    print("  ⚠️ [VideoFirestoreService] viewCount missing for \(doc.documentID), initializing to 0")
                    try? await db.collection("videos").document(doc.documentID).updateData([
                        "viewCount": 0
                    ])
                }
                
                // 🔥 FIX: Get real-time view count from tracker (which fetches from Firestore)
                let trackerCount = await RealtimeViewTracker.shared.getViewCount(for: doc.documentID)
                
                // Use the higher of the two (Firestore or tracker cache)
                let finalViewCount = max(viewCount, trackerCount)
                
                let storedIsPublic = (d["isPublic"] as? Bool) ?? true
                let storedVisibilityRaw = (d["visibility"] as? String)?.lowercased()
                let visibilityStatus = Video.VisibilityStatus(rawValue: storedVisibilityRaw ?? "") ?? (storedIsPublic ? .public : .private)
                
                let video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                    videoURL: d["videoUrl"] as? String ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: finalViewCount, // 🔥 FIX: Use the synced count
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: .entertainment,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: storedIsPublic,
                    visibility: visibilityStatus
                )
                videos.append(video)
            }
            
            return (videos, lastDoc)
        } catch {
            print("🚨 [VideoFirestoreService] Error fetching paginated videos: \(error)")
            return ([], nil)
        }
        #else
        return ([], nil)
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
            
            // 🔥 FIX: Check if document exists first
            let doc = try await ref.getDocument()
            if !doc.exists {
                print("⚠️ [VideoFirestoreService] Video document doesn't exist, creating with viewCount: 1")
                try await ref.setData([
                    "viewCount": 1,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
                print("✅ [VideoFirestoreService] Created video document with viewCount: 1")
                return
            }
            
            // Check if viewCount field exists
            let data = doc.data()
            if data?["viewCount"] == nil {
                print("⚠️ [VideoFirestoreService] viewCount field missing, initializing to 1")
                try await ref.setData([
                    "viewCount": 1
                ], merge: true)
                print("✅ [VideoFirestoreService] Initialized viewCount to 1")
            } else {
                // Field exists, use increment
                try await ref.updateData([
                    "viewCount": FieldValue.increment(Int64(1))
                ])
                print("✅ [VideoFirestoreService] View count incremented successfully")
            }
            
            // 🔥 FIX: Fetch updated count to verify
            let updatedDoc = try await ref.getDocument()
            if let updatedData = updatedDoc.data(),
               let newCount = updatedData["viewCount"] as? Int {
                print("📊 [VideoFirestoreService] Updated view count: \(videoId) → \(newCount) views")
            } else if let updatedData = updatedDoc.data(),
                      let newCount64 = updatedData["viewCount"] as? Int64 {
                print("📊 [VideoFirestoreService] Updated view count: \(videoId) → \(Int(newCount64)) views")
            }
            
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
                        print("✅ [VideoFirestoreService] Local user totalViews updated to: \(updatedUser.totalViews ?? 0)")
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


