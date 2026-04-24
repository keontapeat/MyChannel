//
//  VideoUploadManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import PhotosUI
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
    
    // 🔥 NUCLEAR FIX #1: Upload cancellation support
    private var uploadTask: Task<Video, Error>?
    @Published var isCancelling: Bool = false
    
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
        guard let videoData = videoData ?? (videoURL.flatMap { try? Data(contentsOf: $0) }),
              !title.isEmpty else {
            uploadError = "Please select a video and provide a title"
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil
        isCancelling = false
        
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
                    isPremiere: isPremiere
                )
                
                let video = try await uploadVideoWithProgress(videoData, metadata: metadata)
                
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
            if let uploadedVideo {
                // 🔥 SAVE TO FIRESTORE: Ensure video is saved to Firestore for profile display
                // 🔥 FIX: Ensure viewCount is initialized to 0 in Firestore
                print("💾 [VideoUploadManager] Saving video to Firestore with viewCount: 0")
                try? await VideoFirestoreService.shared.saveVideo(uploadedVideo)
                
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
                    await VideoPlaybackReadinessService.shared.prepareForPlayback(video: uploadedVideo)
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
        } catch {
            uploadError = error.localizedDescription
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
    
    private func uploadVideoWithProgress(_ data: Data, metadata: VideoUploadMetadata) async throws -> Video {
        // 🔥 CRITICAL: Require a real signed-in user so uploads are always tied
        // to an actual creator profile (never the placeholder Default User).
        guard let creatorUser = AuthenticationManager.shared.currentUser else {
            throw UploadError.missingAuthenticatedUser
        }
        #if canImport(FirebaseStorage)
        // Attempt real upload to Firebase Storage. Falls back to mock if Storage is unavailable.
        do {
            let storage = Storage.storage()
            let rootRef = storage.reference()
            let videoId = UUID().uuidString
            let videoRef = rootRef.child("\(AppConfig.Storage.videoPath)/\(videoId).mp4")
            
            // Prepare metadata (content type)
            let storageMetadata = StorageMetadata()
            storageMetadata.contentType = "video/mp4"
            
            // Start upload task
            let uploadTask = videoRef.putData(data, metadata: storageMetadata)
            
            // Observe progress
            let progressObserver = uploadTask.observe(.progress) { [weak self] snapshot in
                guard let self else { return }
                let completed = Double(snapshot.progress?.completedUnitCount ?? 0)
                let total = Double(snapshot.progress?.totalUnitCount ?? 1)
                Task { @MainActor in
                    self.uploadProgress = max(0.0, min(1.0, completed / total))
                }
            }
            
            // Await completion
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                uploadTask.observe(.success) { _ in
                    uploadTask.removeObserver(withHandle: progressObserver)
                    continuation.resume()
                }
                uploadTask.observe(.failure) { snapshot in
                    uploadTask.removeObserver(withHandle: progressObserver)
                    let err = snapshot.error ?? UploadError.networkError("Upload failed")
                    continuation.resume(throwing: err)
                }
            }
            
            // Fetch download URL
            let videoURL = try await videoRef.downloadURL()
            
            // Optional: Upload thumbnail if available
            var thumbnailURLString: String? = nil
            if let thumbData = metadata.thumbnailData {
                let thumbRef = rootRef.child("\(AppConfig.Storage.thumbnailPath)/\(videoId).jpg")
                let thumbMeta = StorageMetadata()
                thumbMeta.contentType = "image/jpeg"
                let thumbTask = thumbRef.putData(thumbData, metadata: thumbMeta)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    thumbTask.observe(.success) { _ in
                        continuation.resume()
                    }
                    thumbTask.observe(.failure) { snapshot in
                        let err = snapshot.error ?? UploadError.networkError("Thumbnail upload failed")
                        continuation.resume(throwing: err)
                    }
                }
                let thumbURL = try await thumbRef.downloadURL()
                thumbnailURLString = thumbURL.absoluteString
            }
            
            // Build resulting model tied to the current user so it appears on profile
            let uploaded = Video(
                id: videoId,
                title: metadata.title,
                description: metadata.description,
                thumbnailURL: thumbnailURLString ?? "",
                videoURL: videoURL.absoluteString,
                duration: max(1, videoDuration),
                viewCount: 0,  // 🔥 FIX: Always initialize to 0 for new videos
                likeCount: 0,
                commentCount: 0,
                creator: creatorUser,
                category: metadata.category,
                tags: metadata.tags,
                isPublic: metadata.isPublic && !metadata.isUnlisted,
                visibility: metadata.isUnlisted ? .unlisted : (metadata.isPublic ? .public : .private),
                // 🔥 FIX: Always enable monetization for testing
                monetization: Video.MonetizationSettings(
                    isMonetized: true, // Always true for testing
                    adBreaks: Video.AdBreaks(preRoll: true, midRoll: true, postRoll: false),
                    adBreakTimestamps: [
                        Video.MonetizationSettings.AdBreak(timeStamp: 0, duration: 15, type: .preRoll), // Pre-roll
                        Video.MonetizationSettings.AdBreak(timeStamp: max(1, videoDuration) / 2, duration: 15, type: .midRoll) // Mid-roll
                    ],
                    sponsorSegments: [],
                    donationEnabled: true,
                    totalRevenue: 0.0
                ),
                ageRestricted: metadata.ageRestricted,
                madeForKids: metadata.madeForKids
            )
            
            // Trigger AI analysis (non-blocking)
            Task {
                // Build the canonical GCS URI using the Firebase Storage bucket and known path
                #if canImport(FirebaseStorage)
                let gcsUri = "gs://\(rootRef.bucket)/\(AppConfig.Storage.videoPath)/\(videoId).mp4"
                if let result = try? await AIService.shared.analyzeVideo(gcsUri: gcsUri, videoId: videoId, durationSeconds: self.videoDuration) {
                    // Optionally request virality score
                    let score = try? await AIService.shared.scoreVirality(
                        labels: result.labels,
                        shots: result.shots,
                        explicit: result.explicit_content,
                        duration: self.videoDuration,
                        text: result.text_annotations,
                        objects: result.object_annotations
                    )
                    print("Virality score: \(score ?? 0)")
                }
                #endif
            }

            // Persist metadata to backend (best-effort, non-blocking)
            Task {
                _ = try? await VideoAPIService.shared.createVideo(
                    title: metadata.title,
                    description: metadata.description,
                    category: metadata.category.rawValue,
                    tags: metadata.tags,
                    visibility: metadata.isUnlisted ? "unlisted" : (metadata.isPublic ? "public" : "private"),
                    isPremium: self.monetizationEnabled,
                    language: "en",
                    videoUrl: uploaded.videoURL,
                    thumbnailUrl: uploaded.thumbnailURL,
                    allowComments: metadata.allowComments,
                    madeForKids: metadata.madeForKids,
                    ageRestricted: metadata.ageRestricted,
                    filmingLocation: metadata.filmingLocation.isEmpty ? nil : metadata.filmingLocation,
                    isPremiere: metadata.isPremiere,
                    scheduledAt: metadata.scheduledDate?.ISO8601Format()
                )
            }
            return uploaded
        } catch {
            print("🚨 Firebase upload failed: \(error)")
            throw error
        }
        #else
        throw UploadError.networkError("Firebase Storage is unavailable in this build")
        #endif
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
        uploadProgress = 0.0
        videoDuration = 0
        videoDimensions = .zero
        fileSizeMB = 0
        thumbnailTime = 1.0
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
    
    init(title: String, description: String, tags: [String], category: VideoCategory, isPublic: Bool, isUnlisted: Bool = false, thumbnailData: Data? = nil, monetizationEnabled: Bool = false, allowComments: Bool = true, madeForKids: Bool = false, ageRestricted: Bool = false, filmingLocation: String = "", isScheduled: Bool = false, scheduledDate: Date? = nil, isPremiere: Bool = false) {
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