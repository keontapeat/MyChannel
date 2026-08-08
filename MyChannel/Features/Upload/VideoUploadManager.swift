//
//  VideoUploadManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import PhotosUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class VideoUploadManager: ObservableObject {
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var isCompressing: Bool = false // 🔥 Phase 10
    @Published var uploadError: String?
    @Published var uploadedVideo: Video?
    
    @Published var selectedVideo: PhotosPickerItem?
    @Published var videoData: Data?
    @Published var videoURL: URL?
    @Published var thumbnail: UIImage?
    
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var selectedCategory: VideoCategory = .entertainment
    @Published var isPublic: Bool = true
    @Published var isUnlisted: Bool = false
    @Published var monetizationEnabled: Bool = true // 🔥💰 DEFAULT: ON! Creators earn from day 1!
    @Published var allowComments: Bool = true
    @Published var allowEmbedding: Bool = true
    @Published var notifySubscribers: Bool = true
    @Published var license: VideoLicense = .standard
    @Published var language: String = "en"
    
    // 🔥 NEW: Scheduling & Advanced Features
    @Published var isScheduled: Bool = false
    @Published var scheduledDate: Date = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @Published var isPremiere: Bool = false
    @Published var selectedPlaylists: Set<String> = []
    @Published var customThumbnails: [UIImage] = []
    @Published var selectedThumbnailIndex: Int = 0
    @Published var filmingLocation: String = ""
    @Published var ageRestricted: Bool = false
    @Published var madeForKids: Bool = false
    
    // Added metadata
    @Published var videoDuration: TimeInterval = 0
    @Published var videoDimensions: CGSize = .zero
    @Published var fileSizeMB: Double = 0
    @Published var thumbnailTime: TimeInterval = 1.0
    
    private let maxVideoSize: Int64 = 2_000_000_000 // 2GB
    private let allowedFormats = ["mp4", "mov", "avi", "mkv"]

    // Pending auxiliary media (captions/dubs) to upload alongside video
    @Published var pendingCaptions: [(url: URL, lang: String)] = []
    @Published var pendingDubs: [(url: URL, lang: String)] = []
    
    // Auto-Dub features
    @Published var enableAutoDub: Bool = false
    @Published var autoDubLanguages: [String] = []
    
    // 🔥 NUCLEAR FIX #1: Upload cancellation support
    private var uploadTask: Task<Video, Error>?
    @Published var isCancelling: Bool = false
    // 🔥 FIX #2: Track the live Firebase Storage transfer(s) so cancelUpload()
    // actually stops the network upload instead of only abandoning the Swift Task.
    #if canImport(FirebaseStorage)
    private var activeStorageUploadTasks: [StorageUploadTask] = []
    #endif
    
    // 🔥 Flicks/Shorts mode - when true, saves to "shorts" collection
    @Published var isFlicksMode: Bool = false
    
    // MARK: - Prepare from URL (Grid picker or Camera)
    func prepareVideo(from url: URL) async {
        self.videoURL = url
        await refreshMetadataAndPreview(from: url)
    }
    
    // MARK: - Video Selection (PhotosPickerItem)
    func loadSelectedVideo() async {
        guard let selectedVideo = selectedVideo else { return }
        
        do {
            if let data = try await selectedVideo.loadTransferable(type: Data.self) {
                self.videoData = data
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                try data.write(to: tempURL)
                self.videoURL = tempURL
                await refreshMetadataAndPreview(from: tempURL)
                
                try await validateVideo(at: tempURL)
            }
        } catch {
            uploadError = "Failed to load video: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Metadata + Preview
    private func refreshMetadataAndPreview(from url: URL) async {
        do {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            videoDuration = CMTimeGetSeconds(duration)
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let nat = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let size = nat.applying(transform)
                videoDimensions = CGSize(width: abs(size.width), height: abs(size.height))
            } else {
                videoDimensions = .zero
            }
            fileSizeMB = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64)
                .map { Double($0) / 1_000_000.0 } ?? 0
            thumbnailTime = min(max(1.0, videoDuration * 0.1), max(1.0, videoDuration - 1.0))
            await updateThumbnail(at: thumbnailTime)
        } catch {
            await updateThumbnail(at: 1.0)
        }
    }
    
    func updateThumbnail(at time: TimeInterval) async {
        guard let videoURL else { return }
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cmTime = CMTime(seconds: min(max(0, time), max(0.1, videoDuration - 0.1)), preferredTimescale: 600)
        do {
            let cg = try await generator.image(at: cmTime).image
            await MainActor.run {
                self.thumbnail = UIImage(cgImage: cg)
                self.thumbnailTime = time
            }
        } catch { }
    }
    
    // MARK: - Video Processing
    private func validateVideo(at url: URL) async throws {
        let asset = AVAsset(url: url)
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        if fileSize > maxVideoSize {
            throw UploadError.fileTooLarge
        }
        
        let fileExtension = url.pathExtension.lowercased()
        if !allowedFormats.contains(fileExtension) {
            throw UploadError.unsupportedFormat
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        if durationSeconds > 43200 {
            throw UploadError.videoTooLong
        }
        
        let videoTracks = try await asset.load(.tracks)
        if videoTracks.isEmpty {
            throw UploadError.noVideoTrack
        }
    }
    
    // MARK: - Upload Process
    func uploadVideo() async {
        // Prevent double-start from publishing onAppear + nextStep.
        guard !isUploading else {
            print("⚠️ [VideoUploadManager] Upload already in progress — ignoring duplicate start")
            return
        }

        isUploading = true
        uploadProgress = 0.02
        uploadError = nil
        isCancelling = false
        isCompressing = false

        guard videoURL != nil || videoData != nil else {
            uploadError = "Please select a video and provide a title"
            isUploading = false
            return
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            uploadError = "Please select a video and provide a title"
            isUploading = false
            return
        }

        // 🔥 NUCLEAR FIX #1: Create cancellable upload task
        uploadTask = Task {
            do {
                let metadata = VideoUploadMetadata(
                    title: title,
                    description: description,
                    tags: Array(selectedTags),
                    category: selectedCategory,
                    isPublic: isPublic,
                    isUnlisted: isUnlisted,
                    thumbnailData: thumbnail?.jpegData(compressionQuality: 0.8),
                    monetizationEnabled: monetizationEnabled,
                    allowComments: allowComments,
                    madeForKids: madeForKids,
                    ageRestricted: ageRestricted,
                    filmingLocation: filmingLocation,
                    isScheduled: isScheduled,
                    scheduledDate: isScheduled ? scheduledDate : nil,
                    isPremiere: isPremiere,
                    language: language,
                    license: license,
                    allowEmbedding: allowEmbedding,
                    notifySubscribers: notifySubscribers
                )

                let video = try await uploadVideoWithProgress(metadata: metadata)

                // 🔥 Only set uploadedVideo if not cancelled
                if !Task.isCancelled {
                    return video
                } else {
                    throw CancellationError()
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw error
            }
        }

        do {
            uploadedVideo = try await uploadTask?.value
            #if canImport(FirebaseStorage)
            activeStorageUploadTasks.removeAll()
            #endif
            if let uploadedVideo {
                // Video + uploads marker already written by the ingest pipeline.
                // Do NOT call VideoFirestoreService.saveVideo — that overwrites
                // trusted processing fields and breaks playback authorization.
                print("💾 [VideoUploadManager] Ingest reservation complete for \(uploadedVideo.id)")

                // 🧠 SEED TOP-SHELF CATEGORY: a creator's own upload category is the
                // strongest, cheapest signal for which Top shelf they belong in
                // (Top Artists / Top Indie Filmmakers / Top MyChannels). Persist it
                // so TopRankMLService slots them correctly on the next ranking cycle.
                if let creatorId = AuthenticationManager.shared.currentUser?.id {
                    if let shelf = CreatorCategoryClassifier.shared.heuristicCategory(
                        bio: AuthenticationManager.shared.currentUser?.bio,
                        videoCategories: [uploadedVideo.category]
                    ) {
                        await CreatorCategoryClassifier.shared.assignCategory(shelf, toUserId: creatorId)
                    }
                }

                // 🔥 FIX: Verify viewCount was saved correctly
                let savedCount = await RealtimeViewTracker.shared.getViewCount(for: uploadedVideo.id)
                print("📊 [VideoUploadManager] Verified viewCount after save: \(savedCount)")
                
                // 🤖 AI CONTENT MODERATION: Run in background, non-blocking
                let moderationVideoId = uploadedVideo.id
                let moderationTitle = uploadedVideo.title
                let moderationDesc = uploadedVideo.description
                Task {
                    struct ModerationRequest: Encodable {
                        let video_id: String
                        let title: String
                        let description: String
                    }
                    struct ModerationResponse: Decodable {
                        let decision: String?
                        let confidence: Double?
                        let flags: [String]?
                    }
                    if let result = try? await CloudRunAgentRouter.post(
                        CloudRunService.contentModeration,
                        path: "/predict",
                        body: ModerationRequest(video_id: moderationVideoId, title: moderationTitle, description: moderationDesc)
                    ) as ModerationResponse {
                        print("🛡️ [ContentModeration] Decision: \(result.decision ?? "ok") (confidence: \(result.confidence ?? 0))")
                        if let flags = result.flags, !flags.isEmpty {
                            print("🚩 [ContentModeration] Flags: \(flags.joined(separator: ", "))")
                        }
                    }
                }
                
                // Persist to local profile and refresh AppState
                try? await DatabaseService.shared.saveVideo(uploadedVideo)
                
                // 🔥💰 NUCLEAR: AUTO-SETUP MONETIZATION - INSTANT EARNINGS FROM DAY 1!
                if self.monetizationEnabled, let user = AuthenticationManager.shared.currentUser {
                    Task {
                        do {
                            let config = try await NuclearAdMonetizationService.shared.setupMonetizationForVideo(
                                video: uploadedVideo,
                                creatorId: user.id
                            )
                            print("🔥💰 [VideoUploadManager] MONETIZATION ACTIVE!")
                            print("   ✅ Video will start earning from FIRST VIEW")
                            print("   ✅ 90% revenue share to creator")
                            print("   ✅ No waiting period!")
                            print("   ✅ \(config.adPlacements.count) ad placements configured")
                            
                            // Start tracking earnings in real-time
                            RealTimeRevenueTracker.shared.startTracking(creatorId: user.id)
                            
                            // Haptic feedback for monetization enabled
                            await MainActor.run {
                                HapticManager.shared.notification(type: .success)
                            }
                        } catch {
                            print("⚠️ [VideoUploadManager] Monetization setup error: \(error)")
                        }
                    }
                }
                
                // 🔥 INCREMENT VIDEO COUNT: Update user's videoCount after successful upload
                if var user = AuthenticationManager.shared.currentUser {
                    user = User(
                        id: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        email: user.email,
                        profileImageURL: user.profileImageURL,
                        bannerImageURL: user.bannerImageURL,
                        bio: user.bio,
                        subscriberCount: user.subscriberCount,
                        videoCount: user.videoCount + 1, // Increment video count
                        isVerified: user.isVerified,
                        isCreator: user.isCreator,
                        createdAt: user.createdAt,
                        location: user.location,
                        website: user.website,
                        socialLinks: user.socialLinks,
                        followerCount: user.followerCount,
                        followingCount: user.followingCount,
                        joinDate: user.joinDate,
                        totalViews: user.totalViews,
                        totalEarnings: user.totalEarnings,
                        membershipTiers: user.membershipTiers,
                        bannerVideoURL: user.bannerVideoURL,
                        bannerVideoMuted: user.bannerVideoMuted,
                        bannerVideoContentMode: user.bannerVideoContentMode
                    )
                    
                    // Save updated user to local storage
                    try? await DatabaseService.shared.saveUser(user)
                    
                    // Update in AuthManager and AppState
                    await MainActor.run {
                        AuthenticationManager.shared.currentUser = user
                        AppState.shared.currentUser = user
                    }
                    
                    // Save to Firestore
                    try? await UserFirestoreService.shared.updateUser(user)
                }
                
                NotificationCenter.default.post(name: .userProfileUpdated, object: AuthenticationManager.shared.currentUser)
                // 🔥 REFRESH PROFILE STATS: Update video count and views in real-time
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                
                // 🔥🔥🔥 YOUTUBE PARITY: Refresh home feed so new videos appear IMMEDIATELY!
                // This is critical for beta testers to see their uploads right away
                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeFeed"), object: uploadedVideo)
                
                // 🔥 CRITICAL: Refresh Creator Studio so uploaded video shows in dashboard immediately
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCreatorStudio"), object: uploadedVideo)
                
                // 🔥 FLICKS: If this is a Flick, save to shorts collection and refresh Flicks feed
                if self.isFlicksMode {
                    if let user = AuthenticationManager.shared.currentUser {
                        do {
                            _ = try await ShortsFirestoreService.shared.saveFlick(
                                id: uploadedVideo.id,
                                title: uploadedVideo.title,
                                description: uploadedVideo.description,
                                videoURL: uploadedVideo.videoURL,
                                thumbnailURL: uploadedVideo.thumbnailURL,
                                duration: uploadedVideo.duration,
                                tags: uploadedVideo.tags,
                                userId: user.id,
                                username: user.username,
                                userDisplayName: user.displayName,
                                userProfileImageURL: user.profileImageURL ?? "",
                                userIsVerified: user.isVerified
                            )
                            print("✅ [VideoUploadManager] Flick saved to shorts collection!")
                        } catch {
                            print("⚠️ [VideoUploadManager] Failed to save Flick: \(error)")
                        }
                    }
                    // Refresh Flicks feed
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFlicksFeed"), object: uploadedVideo)
                    print("📢 [VideoUploadManager] Posted RefreshFlicksFeed notification")
                }
                
                print("📢 [VideoUploadManager] Posted RefreshHomeFeed + RefreshCreatorStudio notifications - video should appear everywhere NOW!")
                
                // 🔥 AUTO-UPDATE CREATOR STUDIO ANALYTICS: Connect upload to analytics tracking
                Task {
                    if let user = AuthenticationManager.shared.currentUser {
                        await AdvancedAnalyticsService.shared.updateCreatorStats(
                            creatorId: user.id,
                            newVideoId: uploadedVideo.id,
                            category: uploadedVideo.category
                        )
                        
                        // Create initial analytics record
                        let initialAnalytics = VideoAnalytics(
                            videoId: uploadedVideo.id,
                            views: 0,
                            uniqueViews: 0,
                            likes: 0,
                            dislikes: 0,
                            comments: 0,
                            shares: 0,
                            watchTime: 0,
                            averageWatchTime: 0,
                            clickThroughRate: 0,
                            engagementRate: 0,
                            revenue: 0
                        )
                        await AdvancedAnalyticsService.shared.addVideoAnalytics(initialAnalytics)
                        
                        print("✅ Creator Studio analytics auto-updated for video: \(uploadedVideo.title)")
                    }
                }
                
                Task {
                    _ = try? await VideoPlaybackReadinessService.shared.checkReadiness(videoId: uploadedVideo.id, userBandwidth: nil)
                }
                
                // 🔥 PHASE 115: Auto-Dub Generation
                if self.enableAutoDub && !self.autoDubLanguages.isEmpty {
                    Task {
                        do {
                            print("🌍 [VideoUploadManager] Starting Auto-Dub for languages: \(self.autoDubLanguages)")
                            try await AutoLocalizationStudioService.shared.generateDubbing(
                                videoId: uploadedVideo.id,
                                sourceLocale: self.language,
                                targetLocales: self.autoDubLanguages
                            )
                            print("✅ [VideoUploadManager] Auto-Dub generation queued successfully.")
                        } catch {
                            print("⚠️ [VideoUploadManager] Auto-Dub failed: \(error)")
                        }
                    }
                }
            }
            // Upload captions/dubs if any were attached
            if let uploadedVideo {
                await uploadAuxiliaryMedia(videoId: uploadedVideo.id, rootTitle: uploadedVideo.title)
            }
            cleanupTempFiles()
            resetForm()
        } catch is CancellationError {
            // 🔥 NUCLEAR FIX #1: Handle cancellation gracefully
            uploadError = "Upload cancelled by user"
            print("🚫 [VideoUploadManager] Upload cancelled by user")
            #if canImport(FirebaseStorage)
            activeStorageUploadTasks.removeAll()
            #endif
        } catch {
            uploadError = error.localizedDescription
            #if canImport(FirebaseStorage)
            activeStorageUploadTasks.removeAll()
            #endif
        }
        
        isUploading = false
        isCancelling = false
    }
    
    // 🔥 NUCLEAR FIX #1: Cancel upload functionality
    func cancelUpload() {
        guard isUploading, !isCancelling else {
            print("⚠️ [VideoUploadManager] Cannot cancel - not uploading or already cancelling")
            return
        }
        
        print("🚫 [VideoUploadManager] Cancelling upload...")
        isCancelling = true
        uploadTask?.cancel()
        
        // 🔥 FIX #2: Actually stop the in-flight Firebase Storage network transfer(s),
        // not just the Swift Task wrapping them — otherwise the file keeps
        // uploading in the background after the user "cancels".
        #if canImport(FirebaseStorage)
        for task in activeStorageUploadTasks {
            task.cancel()
        }
        activeStorageUploadTasks.removeAll()
        #endif
        
        // Reset state
        isUploading = false
        uploadProgress = 0.0
        uploadError = "Upload cancelled by user"
        
        // Haptic feedback
        HapticManager.shared.notification(type: .warning)
        
        print("✅ [VideoUploadManager] Upload cancellation complete")
    }

    // MARK: - Attachments API
    func addCaption(url: URL, lang: String) {
        pendingCaptions.append((url, lang))
    }
    func addDub(url: URL, lang: String) {
        pendingDubs.append((url, lang))
    }

    private func uploadAuxiliaryMedia(videoId: String, rootTitle: String) async {
        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let rootRef = storage.reference()
        #endif
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let videoDoc = db.collection("videos").document(videoId)
        #endif
        // Captions
        for (url, lang) in pendingCaptions {
            #if canImport(FirebaseStorage)
            let fileName = url.lastPathComponent
            let path = "captions/\(videoId)/\(lang)/\(fileName)"
            let ref = rootRef.child(path)
            if let data = try? Data(contentsOf: url) {
                let meta = StorageMetadata(); meta.contentType = "text/vtt"
                _ = try? await ref.putDataAsync(data, metadata: meta)
                if let dl = try? await ref.downloadURL() {
                    #if canImport(FirebaseFirestore)
                    try? await videoDoc.setData(["captions": [lang: dl.absoluteString]], merge: true)
                    #endif
                }
            }
            #endif
        }
        // Dubs
        for (url, lang) in pendingDubs {
            #if canImport(FirebaseStorage)
            let fileName = url.lastPathComponent
            let path = "dubs/\(videoId)/\(lang)/\(fileName)"
            let ref = rootRef.child(path)
            if let data = try? Data(contentsOf: url) {
                let meta = StorageMetadata(); meta.contentType = "audio/m4a"
                _ = try? await ref.putDataAsync(data, metadata: meta)
                if let dl = try? await ref.downloadURL() {
                    #if canImport(FirebaseFirestore)
                    try? await videoDoc.setData(["dubs": [lang: dl.absoluteString]], merge: true)
                    #endif
                }
            }
            #endif
        }
    }
    
    private func uploadVideoWithProgress(metadata: VideoUploadMetadata) async throws -> Video {
        // Require a real Firebase Auth session — Storage + Firestore rules key off request.auth.uid.
        #if canImport(FirebaseAuth)
        guard let firebaseUser = Auth.auth().currentUser else {
            throw UploadError.missingAuthenticatedUser
        }
        // Ensure Storage sees a fresh auth token (stale tokens surface as permission-denied).
        _ = try await firebaseUser.getIDToken(forcingRefresh: true)
        let uid = firebaseUser.uid
        let authDisplayName = firebaseUser.displayName
        let authEmail = firebaseUser.email
        #else
        throw UploadError.missingAuthenticatedUser
        #endif

        let creatorUser = AuthenticationManager.shared.currentUser ?? User(
            id: uid,
            username: authDisplayName ?? "creator",
            displayName: authDisplayName ?? "Creator",
            email: authEmail ?? ""
        )

        // Prefer the Firebase Auth UID so Storage paths match security rules.
        let ownerId = uid

        #if canImport(FirebaseStorage) && canImport(FirebaseFirestore)
        let storage = Storage.storage()
        let rootRef = storage.reference()
        let bucket = rootRef.bucket
        // Lowercase UUID to match web/Android ingest IDs.
        let videoId = UUID().uuidString.lowercased()
        let sourceObjectPath = "temp_uploads/\(ownerId)/\(videoId)/source.mp4"
        let sourcePath = "gs://\(bucket)/temp_uploads/\(ownerId)/\(videoId)/source.mp4"
        let sourceRef = rootRef.child(sourceObjectPath)

        // Resolve a local file URL for putFile (never load the whole video into memory).
        let localFileURL: URL
        if let existing = videoURL, FileManager.default.fileExists(atPath: existing.path) {
            localFileURL = existing
        } else if let data = videoData {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("upload_\(videoId)")
                .appendingPathExtension("mp4")
            try data.write(to: temp, options: .atomic)
            localFileURL = temp
            videoURL = temp
        } else {
            throw UploadError.noVideoSelected
        }

        uploadProgress = 0.05

        let storageMetadata = StorageMetadata()
        storageMetadata.contentType = "video/mp4"
        storageMetadata.customMetadata = [
            "ownerUid": ownerId,
            "videoId": videoId,
            "originalFilename": localFileURL.lastPathComponent
        ]

        let fileUploadTask = sourceRef.putFile(from: localFileURL, metadata: storageMetadata)
        activeStorageUploadTasks.append(fileUploadTask)

        let progressObserver = fileUploadTask.observe(.progress) { [weak self] snapshot in
            guard let self else { return }
            let completed = Double(snapshot.progress?.completedUnitCount ?? 0)
            let total = Double(snapshot.progress?.totalUnitCount ?? 0)
            let fraction = total > 0 ? completed / total : 0
            // Reserve 0.05–0.90 for the Storage transfer.
            Task { @MainActor in
                self.uploadProgress = max(0.05, min(0.90, 0.05 + fraction * 0.85))
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            fileUploadTask.observe(.success) { _ in
                fileUploadTask.removeObserver(withHandle: progressObserver)
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }
            fileUploadTask.observe(.failure) { snapshot in
                fileUploadTask.removeObserver(withHandle: progressObserver)
                let err = snapshot.error ?? UploadError.networkError("Upload failed")
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: err)
            }
        }

        try Task.checkCancellation()
        uploadProgress = 0.92

        // Optional thumbnail (public path). Only attach to Firestore when the URL
        // passes image URL rules (Firebase download hosts / image extensions).
        var thumbnailURLString = ""
        if let thumbData = metadata.thumbnailData {
            let thumbRef = rootRef.child("thumbnails/\(ownerId)/\(videoId)/cover.jpg")
            let thumbMeta = StorageMetadata()
            thumbMeta.contentType = "image/jpeg"
            thumbMeta.customMetadata = ["ownerUid": ownerId, "videoId": videoId]
            let thumbTask = thumbRef.putData(thumbData, metadata: thumbMeta)
            activeStorageUploadTasks.append(thumbTask)
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var resumed = false
                    thumbTask.observe(.success) { _ in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume()
                    }
                    thumbTask.observe(.failure) { snapshot in
                        let err = snapshot.error ?? UploadError.networkError("Thumbnail upload failed")
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(throwing: err)
                    }
                }
                let thumbURL = try await thumbRef.downloadURL().absoluteString
                if Self.isApprovedThumbnailURL(thumbURL) {
                    thumbnailURLString = thumbURL
                }
            } catch {
                print("⚠️ [VideoUploadManager] Thumbnail upload skipped: \(error.localizedDescription)")
            }
        }

        uploadProgress = 0.95

        let privacy: String
        if metadata.isUnlisted {
            privacy = "unlisted"
        } else if metadata.isPublic {
            privacy = "public"
        } else {
            privacy = "private"
        }
        let isScheduled = metadata.isScheduled && metadata.scheduledDate != nil
        let publicationStatus = isScheduled ? "scheduled" : privacy
        let isShort = videoDuration > 0 && videoDuration <= 60

        var videoDoc: [String: Any] = [
            "title": metadata.title,
            "description": metadata.description,
            "sourcePath": sourcePath,
            "creatorId": ownerId,
            "userId": ownerId,
            "ownerUid": ownerId,
            "channelId": ownerId,
            "channelName": creatorUser.displayName,
            "channelAvatarUrl": creatorUser.profileImageURL ?? "",
            "viewCount": 0,
            "likeCount": 0,
            "dislikeCount": 0,
            "commentCount": 0,
            "shareCount": 0,
            "totalWatchTime": 0,
            "duration": max(0, Int(videoDuration.rounded())),
            "createdAt": FieldValue.serverTimestamp(),
            "uploadedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "tags": metadata.tags,
            "category": metadata.category.rawValue,
            "isLive": false,
            "isShort": isShort,
            "privacyStatus": privacy,
            "visibility": publicationStatus,
            "isPublic": privacy == "public" && !isScheduled,
            "ageRestricted": metadata.ageRestricted,
            "madeForKids": metadata.madeForKids,
            "commentsEnabled": metadata.allowComments,
            "allowComments": metadata.allowComments,
            "likesEnabled": true,
            "downloadsEnabled": false,
            "isPremiere": metadata.isPremiere,
            "status": publicationStatus,
            "processingStatus": "uploaded",
            "language": metadata.language,
            "license": metadata.license.rawValue,
            "allowEmbedding": metadata.allowEmbedding,
            "notifySubscribers": metadata.notifySubscribers
        ]
        if !thumbnailURLString.isEmpty {
            videoDoc["thumbnailURL"] = thumbnailURLString
            videoDoc["thumbnailUrl"] = thumbnailURLString
        }
        if isScheduled, let scheduled = metadata.scheduledDate {
            videoDoc["scheduledAt"] = Timestamp(date: scheduled)
        }
        if !metadata.filmingLocation.isEmpty {
            videoDoc["filmingLocation"] = metadata.filmingLocation
        }

        let db = Firestore.firestore()
        let videoRef = db.collection("videos").document(videoId)
        let uploadRef = db.collection("uploads").document(videoId)

        try await db.runTransaction { transaction, errorPointer -> Any? in
            let existingVideo: DocumentSnapshot
            let existingUpload: DocumentSnapshot
            do {
                existingVideo = try transaction.getDocument(videoRef)
                existingUpload = try transaction.getDocument(uploadRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            if existingVideo.exists {
                let data = existingVideo.data() ?? [:]
                guard (data["creatorId"] as? String) == ownerId,
                      (data["sourcePath"] as? String) == sourcePath else {
                    errorPointer?.pointee = NSError(
                        domain: "VideoUploadManager",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Video reservation belongs to another creator."]
                    )
                    return nil
                }
            } else {
                transaction.setData(videoDoc, forDocument: videoRef)
            }

            if existingUpload.exists {
                let data = existingUpload.data() ?? [:]
                guard (data["videoId"] as? String) == videoId,
                      (data["ownerUid"] as? String) == ownerId,
                      (data["sourcePath"] as? String) == sourcePath else {
                    errorPointer?.pointee = NSError(
                        domain: "VideoUploadManager",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Upload reservation does not match."]
                    )
                    return nil
                }
            } else {
                transaction.setData([
                    "videoId": videoId,
                    "ownerUid": ownerId,
                    "sourcePath": sourcePath,
                    "status": "uploaded",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: uploadRef)
            }
            return nil
        }

        uploadProgress = 1.0

        // Playback URL stays empty until the trusted transcoder publishes a manifest.
        return Video(
            id: videoId,
            title: metadata.title,
            description: metadata.description,
            thumbnailURL: thumbnailURLString,
            videoURL: "",
            duration: max(1, videoDuration),
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            creator: creatorUser.id == ownerId
                ? creatorUser
                : User(
                    id: ownerId,
                    username: creatorUser.username,
                    displayName: creatorUser.displayName,
                    email: creatorUser.email,
                    profileImageURL: creatorUser.profileImageURL,
                    bannerImageURL: creatorUser.bannerImageURL,
                    bio: creatorUser.bio,
                    subscriberCount: creatorUser.subscriberCount,
                    videoCount: creatorUser.videoCount,
                    isVerified: creatorUser.isVerified,
                    isCreator: creatorUser.isCreator,
                    createdAt: creatorUser.createdAt,
                    location: creatorUser.location,
                    website: creatorUser.website,
                    socialLinks: creatorUser.socialLinks,
                    followerCount: creatorUser.followerCount,
                    followingCount: creatorUser.followingCount,
                    joinDate: creatorUser.joinDate,
                    totalViews: creatorUser.totalViews,
                    totalEarnings: creatorUser.totalEarnings,
                    membershipTiers: creatorUser.membershipTiers,
                    bannerVideoURL: creatorUser.bannerVideoURL,
                    bannerVideoMuted: creatorUser.bannerVideoMuted,
                    bannerVideoContentMode: creatorUser.bannerVideoContentMode
                ),
            category: metadata.category,
            tags: metadata.tags,
            isPublic: privacy == "public" && !isScheduled,
            visibility: metadata.isUnlisted ? .unlisted : (metadata.isPublic ? .public : .private),
            scheduledAt: metadata.scheduledDate,
            language: metadata.language,
            monetization: Video.MonetizationSettings(
                isMonetized: metadata.monetizationEnabled,
                adBreaks: Video.AdBreaks(preRoll: true, midRoll: true, postRoll: false),
                adBreakTimestamps: [],
                sponsorSegments: [],
                donationEnabled: true,
                totalRevenue: 0.0
            ),
            ageRestricted: metadata.ageRestricted,
            madeForKids: metadata.madeForKids,
            allowComments: metadata.allowComments,
            processingStatus: "uploaded",
            filmingLocation: metadata.filmingLocation.isEmpty ? nil : metadata.filmingLocation,
            isPremiere: metadata.isPremiere
        )
        #else
        throw UploadError.networkError("Firebase Storage is unavailable in this build")
        #endif
    }

    private static func isApprovedThumbnailURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        if lower.contains("firebasestorage.googleapis.com") { return true }
        if lower.contains("firebasestorage.app") { return true }
        if lower.contains(".jpg") || lower.contains(".jpeg") || lower.contains(".png") || lower.contains(".webp") {
            return true
        }
        return false
    }
    
    // MARK: - Cleanup
    private func cleanupTempFiles() {
        if let videoURL = videoURL, videoURL.path.contains(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: videoURL)
        }
    }
    
    func resetForm() {
        selectedVideo = nil
        videoData = nil
        videoURL = nil
        thumbnail = nil
        title = ""
        description = ""
        selectedTags.removeAll()
        selectedCategory = .entertainment
        isPublic = true
        isUnlisted = false
        monetizationEnabled = false
        allowComments = true
        isScheduled = false
        scheduledDate = Date().addingTimeInterval(3600)
        isPremiere = false
        filmingLocation = ""
        ageRestricted = false
        madeForKids = false
        allowEmbedding = true
        notifySubscribers = true
        license = .standard
        language = "en"
        uploadProgress = 0.0
        isCompressing = false
        videoDuration = 0
        videoDimensions = .zero
        fileSizeMB = 0
        thumbnailTime = 1.0
        enableAutoDub = false
        autoDubLanguages.removeAll()
    }
    
    // MARK: - Video Editing (Basic)
    func trimVideo(startTime: CMTime, endTime: CMTime) async throws -> URL {
        guard let videoURL = videoURL else { throw UploadError.noVideoSelected }
        
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw UploadError.noVideoTrack
        }
        
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        try compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw UploadError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        await exportSession.export()
        
        if exportSession.status == .completed {
            self.videoURL = outputURL
            await refreshMetadataAndPreview(from: outputURL)
            return outputURL
        } else {
            throw UploadError.exportFailed
        }
    }
    
    func autoTrimToFlicksIfNeeded(max seconds: TimeInterval = 60) async throws {
        guard videoDuration > seconds else { return }
        let end = CMTime(seconds: seconds, preferredTimescale: 600)
        _ = try await trimVideo(startTime: .zero, endTime: end)
    }
}

// MARK: - Video Upload Metadata Structure
struct VideoUploadMetadata {
    let title: String
    let description: String
    let tags: [String]
    let category: VideoCategory
    let isPublic: Bool
    let isUnlisted: Bool
    let thumbnailData: Data?
    let monetizationEnabled: Bool
    let allowComments: Bool
    let madeForKids: Bool
    let ageRestricted: Bool
    let filmingLocation: String
    let isScheduled: Bool
    let scheduledDate: Date?
    let isPremiere: Bool
    let language: String
    let license: VideoLicense
    let allowEmbedding: Bool
    let notifySubscribers: Bool
    
    init(title: String, description: String, tags: [String], category: VideoCategory, isPublic: Bool, isUnlisted: Bool = false, thumbnailData: Data? = nil, monetizationEnabled: Bool = false, allowComments: Bool = true, madeForKids: Bool = false, ageRestricted: Bool = false, filmingLocation: String = "", isScheduled: Bool = false, scheduledDate: Date? = nil, isPremiere: Bool = false, language: String = "en", license: VideoLicense = .standard, allowEmbedding: Bool = true, notifySubscribers: Bool = true) {
        self.title = title
        self.description = description
        self.tags = tags
        self.category = category
        self.isPublic = isPublic
        self.isUnlisted = isUnlisted
        self.thumbnailData = thumbnailData
        self.monetizationEnabled = monetizationEnabled
        self.allowComments = allowComments
        self.madeForKids = madeForKids
        self.ageRestricted = ageRestricted
        self.filmingLocation = filmingLocation
        self.isScheduled = isScheduled
        self.scheduledDate = scheduledDate
        self.isPremiere = isPremiere
        self.language = language
        self.license = license
        self.allowEmbedding = allowEmbedding
        self.notifySubscribers = notifySubscribers
    }
}

enum VideoLicense: String, Codable, CaseIterable {
    case standard = "standard"
    case creativeCommons = "creative_commons"

    var displayName: String {
        switch self {
        case .standard: return "Standard License"
        case .creativeCommons: return "Creative Commons - Attribution"
        }
    }
}

enum UploadError: Error, LocalizedError {
    case fileTooLarge
    case unsupportedFormat
    case videoTooLong
    case noVideoTrack
    case noVideoSelected
    case exportFailed
    case networkError(String)
    case missingAuthenticatedUser
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "Video file is too large (max 2GB)"
        case .unsupportedFormat:
            return "Unsupported video format"
        case .videoTooLong:
            return "Video is too long (max 12 hours)"
        case .noVideoTrack:
            return "Video file has no video track"
        case .noVideoSelected:
            return "No video selected"
        case .exportFailed:
            return "Failed to export video"
        case .networkError(let message):
            return "Network error: \(message)"
        case .missingAuthenticatedUser:
            return "You must be signed in to upload a video."
        }
    }
}

#Preview {
    VStack {
        Text("Video Upload Manager")
            .font(.largeTitle)
            .padding()
        
        Text("Handles video metadata, thumbnails, and uploads")
            .foregroundColor(.secondary)
    }
}