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

            // 🔥 RANKING FIX: Keep an aggregate likeCount on the video AND roll it
            // up to the creator's users/{uid}.likeCount so engagement actually
            // feeds TopRankMLService's engagement score in real time.
            let delta: Int64 = add ? 1 : -1
            let videoRef = db.collection("videos").document(videoId)
            try await videoRef.setData(["likeCount": FieldValue.increment(delta)], merge: true)

            if let creatorId = try await videoRef.getDocument().data()?["userId"] as? String, !creatorId.isEmpty {
                try await db.collection("users").document(creatorId).setData([
                    "likeCount": FieldValue.increment(delta)
                ], merge: true)
            }
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
            "creatorId": video.creator.id,
            "ownerUid": video.creator.id,
            "creatorUsername": video.creator.username,
            "creatorDisplayName": video.creator.displayName,
            "creatorName": video.creator.displayName,
            "creatorProfileImage": video.creator.profileImageURL ?? "",
            "creatorAvatarURL": video.creator.profileImageURL ?? "",
            "creatorVerified": video.creator.isVerified,
            "title": video.title,
            "description": video.description,
            "thumbnailUrl": video.thumbnailURL,
            "thumbnailURL": video.thumbnailURL,
            "videoUrl": video.videoURL,
            "videoURL": video.videoURL,
            "duration": video.duration,
            "viewCount": viewCountToSave,  // 🔥 FIX: Preserve existing count
            "likeCount": video.likeCount,
            "dislikeCount": video.dislikeCount,
            "commentCount": video.commentCount,
            "shareCount": existingDoc?.data()?["shareCount"] as? Int ?? 0,
            "category": video.category.rawValue,
            "tags": video.tags,
            "language": video.language ?? "en",
            "isPublic": video.visibility == .public,
            "visibility": video.visibility.rawValue,
            "status": "published",
            "processingStatus": "completed",
            "ageRestricted": video.ageRestricted ?? false,
            "madeForKids": video.madeForKids ?? false,
            "allowComments": video.allowComments ?? (existingDoc?.data()?["allowComments"] as? Bool ?? true),
            "filmingLocation": video.filmingLocation ?? (existingDoc?.data()?["filmingLocation"] as? String ?? ""),
            "isPremiere": video.isPremiere ?? (existingDoc?.data()?["isPremiere"] as? Bool ?? false),
            "scheduledAt": video.scheduledAt.map { Timestamp(date: $0) } ?? existingDoc?.data()?["scheduledAt"] ?? NSNull(),
            "createdAt": existingDoc?.data()?["createdAt"] ?? FieldValue.serverTimestamp(),  // Preserve original createdAt
            "updatedAt": FieldValue.serverTimestamp(),
            "publishedAt": existingDoc?.data()?["publishedAt"] ?? FieldValue.serverTimestamp()
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
    
    // MARK: - 📝 Update Video Metadata (Only changed fields)
    func updateVideoMetadata(
        videoId: String,
        title: String? = nil,
        description: String? = nil,
        category: VideoCategory? = nil,
        tags: [String]? = nil,
        visibility: Video.VisibilityStatus? = nil,
        madeForKids: Bool? = nil,
        ageRestricted: Bool? = nil,
        allowComments: Bool? = nil
    ) async throws {
        #if canImport(FirebaseFirestore)
        var updateData: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Only update fields that are provided (not nil)
        if let title = title {
            updateData["title"] = title
        }
        if let description = description {
            updateData["description"] = description
        }
        if let category = category {
            updateData["category"] = category.rawValue
        }
        if let tags = tags {
            updateData["tags"] = tags
        }
        // 🔥 YouTube parity: visibility (keeps isPublic mirror in sync)
        if let visibility = visibility {
            updateData["visibility"] = visibility.rawValue
            updateData["isPublic"] = visibility == .public
        }
        // 🔥 COPPA: Made for kids
        if let madeForKids = madeForKids {
            updateData["madeForKids"] = madeForKids
        }
        if let ageRestricted = ageRestricted {
            updateData["ageRestricted"] = ageRestricted
        }
        if let allowComments = allowComments {
            updateData["allowComments"] = allowComments
        }
        
        let ref = db.collection("videos").document(videoId)
        try await ref.updateData(updateData)
        print("📝 [VideoFirestoreService] Updated video metadata for: \(videoId) — keys: \(updateData.keys.sorted())")
        #endif
    }
    
    // MARK: - 💰 Update Monetization Settings (YouTube-style ads)
    func updateMonetization(videoId: String, monetization: Video.MonetizationSettings) async throws {
        #if canImport(FirebaseFirestore)
        var monetizationData: [String: Any] = [
            "isMonetized": monetization.isMonetized,
            "donationEnabled": monetization.donationEnabled,
            "totalRevenue": monetization.totalRevenue
        ]
        
        // Add ad breaks if present
        if let adBreaks = monetization.adBreaks {
            monetizationData["adBreaks"] = [
                "preRoll": adBreaks.preRoll,
                "midRoll": adBreaks.midRoll,
                "postRoll": adBreaks.postRoll,
                "midRollInterval": adBreaks.midRollInterval ?? 480
            ]
        }
        
        // Add sponsor segments if present
        if let sponsorSegments = monetization.sponsorSegments {
            monetizationData["sponsorSegments"] = sponsorSegments.map { segment in
                [
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "sponsor": segment.sponsor,
                    "category": segment.category.rawValue
                ]
            }
        }
        
        // Add merchandise if present
        if let merchandise = monetization.merchandise {
            monetizationData["merchandise"] = merchandise.map { item in
                [
                    "name": item.name,
                    "description": item.description,
                    "price": item.price,
                    "currency": item.currency,
                    "imageURL": item.imageURL,
                    "purchaseURL": item.purchaseURL
                ]
            }
        }
        
        // Add subscription tier if present
        if let subscriptionTier = monetization.subscriptionTier {
            monetizationData["subscriptionTier"] = subscriptionTier.rawValue
        }
        
        let ref = db.collection("videos").document(videoId)
        try await ref.updateData([
            "monetization": monetizationData,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        print("💰 [VideoFirestoreService] Updated monetization for video: \(videoId), isMonetized: \(monetization.isMonetized)")
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
            
            let trackerCounts: [String: Int] = await withTaskGroup(of: (String, Int).self) { group in
                for doc in snap.documents {
                    let docId = doc.documentID
                    group.addTask { (docId, await RealtimeViewTracker.shared.getViewCount(for: docId)) }
                }
                var result: [String: Int] = [:]
                for await (id, count) in group { result[id] = count }
                return result
            }
            
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
                
                let trackerCount = trackerCounts[doc.documentID] ?? 0
                
                // Use the higher of the two (Firestore or tracker cache)
                let finalViewCount = max(viewCount, trackerCount)
                
                if trackerCount != viewCount {
                    print("  📊 View count sync: Firestore=\(viewCount), Tracker=\(trackerCount), Using=\(finalViewCount)")
                }
                
                let storedIsPublic = (d["isPublic"] as? Bool) ?? true
                let storedVisibilityRaw = (d["visibility"] as? String)?.lowercased()
                let visibilityStatus = Video.VisibilityStatus(rawValue: storedVisibilityRaw ?? "") ?? (storedIsPublic ? .public : .private)

                let creator = User(
                    id: (d["creatorId"] as? String) ?? (d["userId"] as? String) ?? creatorId,
                    username: d["creatorUsername"] as? String ?? AppState.shared.currentUser?.username ?? "creator",
                    displayName: d["creatorDisplayName"] as? String ?? AppState.shared.currentUser?.displayName ?? "Creator",
                    email: AppState.shared.currentUser?.email ?? "",
                    profileImageURL: d["creatorProfileImage"] as? String ?? AppState.shared.currentUser?.profileImageURL,
                    bannerImageURL: AppState.shared.currentUser?.bannerImageURL,
                    bio: AppState.shared.currentUser?.bio,
                    subscriberCount: AppState.shared.currentUser?.subscriberCount ?? 0,
                    videoCount: AppState.shared.currentUser?.videoCount ?? 0,
                    isVerified: (d["creatorVerified"] as? Bool) ?? AppState.shared.currentUser?.isVerified ?? false,
                    isCreator: true,
                    createdAt: AppState.shared.currentUser?.createdAt ?? Date()
                )

                let thumbnailURL = (d["thumbnailUrl"] as? String) ?? (d["thumbnailURL"] as? String) ?? ""
                let videoURL = (d["videoUrl"] as? String) ?? (d["videoURL"] as? String) ?? ""
                let categoryRaw = (d["category"] as? String)?.lowercased() ?? "entertainment"
                let category = VideoCategory(rawValue: categoryRaw) ?? .entertainment

                // 🔥 Parse scheduled date + monetization + restrictions for management UI
                let scheduledAt = (d["scheduledAt"] as? Timestamp)?.dateValue()
                var monetization: Video.MonetizationSettings? = nil
                if let m = d["monetization"] as? [String: Any] {
                    var adBreaks: Video.AdBreaks? = nil
                    if let ab = m["adBreaks"] as? [String: Any] {
                        adBreaks = Video.AdBreaks(
                            preRoll: (ab["preRoll"] as? Bool) ?? false,
                            midRoll: (ab["midRoll"] as? Bool) ?? false,
                            postRoll: (ab["postRoll"] as? Bool) ?? false,
                            midRollInterval: ab["midRollInterval"] as? Int
                        )
                    }
                    monetization = Video.MonetizationSettings(
                        isMonetized: (m["isMonetized"] as? Bool) ?? false,
                        adBreaks: adBreaks,
                        donationEnabled: (m["donationEnabled"] as? Bool) ?? false,
                        totalRevenue: (m["totalRevenue"] as? Double) ?? 0
                    )
                }
                let hasCopyrightStrike = (d["hasCopyrightStrike"] as? Bool)
                    ?? (((d["copyrightClaims"] as? [String])?.isEmpty == false) ? true : nil)

                var video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: thumbnailURL,
                    videoURL: videoURL,
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: finalViewCount, // 🔥 FIX: Use the synced count
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    commentCount: (d["commentCount"] as? Int) ?? 0,
                    creator: creator,
                    category: category,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: storedIsPublic,
                    visibility: visibilityStatus,
                    scheduledAt: scheduledAt,
                    monetization: monetization,
                    ageRestricted: d["ageRestricted"] as? Bool,
                    madeForKids: d["madeForKids"] as? Bool,
                    allowComments: d["allowComments"] as? Bool,
                    filmingLocation: d["filmingLocation"] as? String,
                    isPremiere: d["isPremiere"] as? Bool
                )
                video.hasCopyrightStrike = hasCopyrightStrike
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
    
    // 🔥🔥🔥 FETCH ALL PUBLIC VIDEOS - For HomeView "New From Creators" Section! 🔥🔥🔥
    // This powers the home feed with REAL videos from your beta testers
    func fetchAllPublicVideos(limit: Int = 24) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            print("🔥 [VideoFirestoreService] Fetching ALL public videos for home feed (limit: \(limit))")
            
            // Query all videos ordered by most recent first
            // We'll filter for public visibility client-side since some videos may use different field names
            let query: Query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: limit * 2) // Fetch extra in case some are private
            
            let snap = try await query.getDocuments()
            print("📺 [VideoFirestoreService] Found \(snap.documents.count) public videos in Firestore")
            
            var videos: [Video] = []
            for doc in snap.documents {
                let d = doc.data()
                
                // 🔥 Check if video is public (handle both visibility and isPublic fields)
                let visibilityRaw = (d["visibility"] as? String)?.lowercased() ?? ""
                let isPublicField = (d["isPublic"] as? Bool) ?? true
                let isPublic = visibilityRaw == "public" || (visibilityRaw.isEmpty && isPublicField)
                
                // Skip private/unlisted videos
                guard isPublic else {
                    print("  ⏭️ Skipping non-public video: \(d["title"] as? String ?? "untitled")")
                    continue
                }
                
                // Skip records that are not yet ready (processing or missing URL)
                let processingStatus = (d["processingStatus"] as? String)?.lowercased() ?? "completed"
                let rawVideoUrl = (d["videoUrl"] as? String) ?? (d["videoURL"] as? String) ?? ""
                if rawVideoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || processingStatus != "completed" {
                    print("  ⏭️ Skipping not-ready video (processingStatus=\(processingStatus)) id=\(doc.documentID)")
                    continue
                }

                // Get view count
                var viewCount = 0
                if let firestoreCount = d["viewCount"] as? Int {
                    viewCount = firestoreCount
                } else if let firestoreCount = d["viewCount"] as? Int64 {
                    viewCount = Int(firestoreCount)
                }
                
                // Get creator info from Firestore
                let creatorId = d["userId"] as? String ?? ""
                var creator = User.defaultUser
                
                let embeddedName = d["creatorDisplayName"] as? String ?? d["creatorName"] as? String ?? ""
                if !creatorId.isEmpty && !embeddedName.isEmpty {
                    creator = User(
                        id: creatorId,
                        username: d["creatorUsername"] as? String ?? "user",
                        displayName: embeddedName,
                        email: "",
                        profileImageURL: d["creatorProfileImage"] as? String ?? d["creatorAvatarURL"] as? String,
                        bannerImageURL: nil,
                        bio: nil,
                        subscriberCount: 0,
                        videoCount: 0,
                        isVerified: (d["creatorVerified"] as? Bool) ?? false,
                        isCreator: true,
                        createdAt: Date()
                    )
                } else if !creatorId.isEmpty {
                    if let creatorDoc = try? await db.collection("users").document(creatorId).getDocument(),
                       creatorDoc.exists,
                       let creatorData = creatorDoc.data() {
                        creator = User(
                            id: creatorId,
                            username: creatorData["username"] as? String ?? "user",
                            displayName: creatorData["displayName"] as? String ?? "Creator",
                            email: creatorData["email"] as? String ?? "",
                            profileImageURL: creatorData["profileImageURL"] as? String ?? creatorData["profileImageUrl"] as? String,
                            bannerImageURL: creatorData["bannerImageURL"] as? String ?? creatorData["bannerImageUrl"] as? String,
                            bio: creatorData["bio"] as? String,
                            subscriberCount: (creatorData["subscriberCount"] as? Int) ?? 0,
                            videoCount: (creatorData["videoCount"] as? Int) ?? 0,
                            isVerified: (creatorData["isVerified"] as? Bool) ?? false,
                            isCreator: true,
                            createdAt: (creatorData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                }
                
                let video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? d["thumbnailURL"] as? String ?? "",
                    videoURL: rawVideoUrl,
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: viewCount,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: creator, // 🔥 Use the actual creator, not current user
                    category: VideoCategory(rawValue: d["category"] as? String ?? "") ?? .entertainment,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: true,
                    visibility: .public
                )
                
                videos.append(video)
                print("  ✅ Video: \(video.title) by \(creator.displayName)")
                
                // Stop if we have enough public videos
                if videos.count >= limit {
                    break
                }
            }
            
            print("🔥 [VideoFirestoreService] Successfully loaded \(videos.count) public videos for home feed")
            return videos
        } catch {
            print("🚨 [VideoFirestoreService] Error fetching public videos: \(error)")
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
            
            let trackerCounts: [String: Int] = await withTaskGroup(of: (String, Int).self) { group in
                for doc in snap.documents {
                    let docId = doc.documentID
                    group.addTask { (docId, await RealtimeViewTracker.shared.getViewCount(for: docId)) }
                }
                var result: [String: Int] = [:]
                for await (id, count) in group { result[id] = count }
                return result
            }
            
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
                
                let trackerCount = trackerCounts[doc.documentID] ?? 0
                
                // Use the higher of the two (Firestore or tracker cache)
                let finalViewCount = max(viewCount, trackerCount)
                
                let storedIsPublic = (d["isPublic"] as? Bool) ?? true
                let storedVisibilityRaw = (d["visibility"] as? String)?.lowercased()
                let visibilityStatus = Video.VisibilityStatus(rawValue: storedVisibilityRaw ?? "") ?? (storedIsPublic ? .public : .private)
                
                // 🔥 Parse scheduled date + monetization + restrictions (parity with fetchVideosByCreator)
                let scheduledAt = (d["scheduledAt"] as? Timestamp)?.dateValue()
                var monetization: Video.MonetizationSettings? = nil
                if let m = d["monetization"] as? [String: Any] {
                    var adBreaks: Video.AdBreaks? = nil
                    if let ab = m["adBreaks"] as? [String: Any] {
                        adBreaks = Video.AdBreaks(
                            preRoll: (ab["preRoll"] as? Bool) ?? false,
                            midRoll: (ab["midRoll"] as? Bool) ?? false,
                            postRoll: (ab["postRoll"] as? Bool) ?? false,
                            midRollInterval: ab["midRollInterval"] as? Int
                        )
                    }
                    monetization = Video.MonetizationSettings(
                        isMonetized: (m["isMonetized"] as? Bool) ?? false,
                        adBreaks: adBreaks,
                        donationEnabled: (m["donationEnabled"] as? Bool) ?? false,
                        totalRevenue: (m["totalRevenue"] as? Double) ?? 0
                    )
                }
                let hasCopyrightStrike = (d["hasCopyrightStrike"] as? Bool)
                    ?? (((d["copyrightClaims"] as? [String])?.isEmpty == false) ? true : nil)
                let categoryRaw = (d["category"] as? String)?.lowercased() ?? "entertainment"
                let category = VideoCategory(rawValue: categoryRaw) ?? .entertainment
                
                var video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: (d["thumbnailUrl"] as? String) ?? (d["thumbnailURL"] as? String) ?? "",
                    videoURL: (d["videoUrl"] as? String) ?? (d["videoURL"] as? String) ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: finalViewCount, // 🔥 FIX: Use the synced count
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    commentCount: (d["commentCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: category,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: storedIsPublic,
                    visibility: visibilityStatus,
                    scheduledAt: scheduledAt,
                    monetization: monetization,
                    ageRestricted: d["ageRestricted"] as? Bool,
                    madeForKids: d["madeForKids"] as? Bool,
                    allowComments: d["allowComments"] as? Bool,
                    filmingLocation: d["filmingLocation"] as? String,
                    isPremiere: d["isPremiere"] as? Bool
                )
                video.hasCopyrightStrike = hasCopyrightStrike
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


