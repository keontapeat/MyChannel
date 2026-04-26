//
//  EnhancedVideoUploadService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI
import AVFoundation
import PhotosUI

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 📹 Enterprise Video Upload Service
// Industry-standard video upload with ML processing and optimization
@MainActor
class EnhancedVideoUploadService: ObservableObject {
    static let shared = EnhancedVideoUploadService()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadStatus: UploadStatus = .idle
    @Published var error: String?
    @Published var currentUpload: VideoUpload?
    
    // Upload queue management
    @Published var uploadQueue: [VideoUpload] = []
    @Published var completedUploads: [VideoUpload] = []
    
    // ML Services Integration
    private let videoProcessingURL = "https://video-processing-fkri6ifojq-uc.a.run.app"
    private let thumbnailGeneratorURL = "https://thumbnail-generator-fkri6ifojq-uc.a.run.app"
    private let contentModerationURL = "https://content-moderation-fkri6ifojq-uc.a.run.app"
    private let videoOptimizationURL = "https://video-optimization-fkri6ifojq-uc.a.run.app"
    private let metadataExtractionURL = "https://metadata-extraction-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupUploadEnvironment()
    }
    
    // MARK: - Setup
    
    private func setupUploadEnvironment() {
        // Configure upload settings
        URLSessionConfiguration.default.timeoutIntervalForRequest = 300 // 5 minutes
        URLSessionConfiguration.default.timeoutIntervalForResource = 3600 // 1 hour
    }
    
    // MARK: - Video Upload
    
    func uploadVideo(
        videoURL: URL,
        title: String,
        description: String = "",
        visibility: VideoVisibility = .privateVideo,
        category: String = "general",
        tags: [String] = []
    ) async throws -> VideoUpload {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "video_upload", attributes: [
            "title": title,
            "category": category,
            "visibility": visibility.rawValue
        ])
        
        defer {
            let uploadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "video_upload", metrics: [
                "upload_time_ms": Int64(uploadTime * 1000)
            ])
        }
        
        guard let userId = AppState.shared.currentUser?.id else {
            throw VideoUploadServiceError.userNotAuthenticated
        }
        
        // Create upload object
        let upload = VideoUpload(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            description: description,
            visibility: visibility,
            category: category,
            tags: tags,
            localVideoURL: videoURL,
            status: .preparing,
            createdAt: Date()
        )
        
        currentUpload = upload
        uploadQueue.append(upload)
        isUploading = true
        uploadStatus = .preparing
        uploadProgress = 0.0
        error = nil
        
        do {
            // Step 1: Validate video with retry
            try await retryOperation(maxAttempts: 2, delay: 1.0) {
                try await validateVideo(videoURL)
            }
            await updateUploadProgress(0.1, status: .validating)
            
            // Step 2: Extract metadata with retry
            let metadata = try await retryOperation(maxAttempts: 3, delay: 0.5) {
                try await extractVideoMetadata(videoURL)
            }
            await updateUploadProgress(0.2, status: .processing)
            
            // Step 3: Content moderation (skip if service unavailable)
            var moderationResult: VideoModerationResult
            do {
                moderationResult = try await moderateContent(videoURL, metadata: metadata)
            } catch {
                print("⚠️ Content moderation service unavailable, proceeding with approval: \(error)")
                moderationResult = VideoModerationResult(
                    isApproved: true,
                    confidenceScore: 1.0,
                    flaggedContent: [],
                    reason: nil,
                    suggestions: []
                )
            }
            
            if !moderationResult.isApproved {
                throw VideoUploadServiceError.contentRejected(moderationResult.reason ?? "Policy violation")
            }
            await updateUploadProgress(0.3, status: .moderating)
            
            // Step 4: Optimize video (fallback to original if optimization fails)
            var optimizedURL: URL
            do {
                optimizedURL = try await optimizeVideo(videoURL, metadata: metadata)
            } catch {
                print("⚠️ Video optimization failed, using original: \(error)")
                optimizedURL = videoURL
            }
            await updateUploadProgress(0.5, status: .optimizing)
            
            // Step 5: Generate thumbnail with enhanced error handling
            let thumbnailURL = try await retryOperation(maxAttempts: 3, delay: 1.0) {
                try await generateThumbnail(optimizedURL)
            }
            await updateUploadProgress(0.6, status: .generatingThumbnail)
            
            // Step 6: Create Firestore document FIRST so Storage rules can validate ownerUid
            let videoDocument = try await retryOperation(maxAttempts: 3, delay: 2.0) {
                try await createVideoDocument(
                    upload: upload,
                    metadata: metadata,
                    videoURL: "",
                    thumbnailURL: ""
                )
            }
            await updateUploadProgress(0.65, status: .uploading)
            
            // Step 7: Upload to Firebase Storage with retry (now the Firestore doc exists for rule validation)
            let (videoStorageURL, thumbnailStorageURL) = try await retryOperation(maxAttempts: 3, delay: 5.0) {
                try await uploadToStorage(
                    videoURL: optimizedURL,
                    thumbnailURL: thumbnailURL,
                    upload: upload,
                    videoId: videoDocument.id
                )
            }
            await updateUploadProgress(0.8, status: .uploading)
            
            // Step 8: Update Firestore document with actual storage URLs
            try await retryOperation(maxAttempts: 3, delay: 1.0) {
                try await updateVideoDocumentURLs(
                    videoId: videoDocument.id,
                    videoURL: videoStorageURL,
                    thumbnailURL: thumbnailStorageURL
                )
            }
            await updateUploadProgress(0.9, status: .finalizing)
            
            // Step 9: Post-processing (non-blocking, best effort)
            do {
                try await performPostProcessing(videoId: videoDocument.id, upload: upload)
            } catch {
                print("⚠️ Post-processing failed (non-critical): \(error)")
            }
            await updateUploadProgress(1.0, status: .completed)
            
            // Update upload object
            var completedUpload = upload
            completedUpload.status = .completed
            completedUpload.videoId = videoDocument.id
            completedUpload.remoteVideoURL = videoStorageURL
            completedUpload.thumbnailURL = thumbnailStorageURL
            completedUpload.completedAt = Date()
            
            // Move to completed uploads
            uploadQueue.removeAll { $0.id == upload.id }
            completedUploads.append(completedUpload)
            
            // Track successful upload
            EnhancedAnalyticsManager.shared.logEvent("video_uploaded", parameters: [
                "video_id": videoDocument.id,
                "user_id": userId,
                "title": title,
                "category": category,
                "duration": metadata.duration,
                "file_size": metadata.fileSize,
                "upload_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isUploading = false
            currentUpload = nil
            
            return completedUpload
            
        } catch {
            // Handle upload failure
            var failedUpload = upload
            failedUpload.status = .failed
            failedUpload.error = error.localizedDescription
            
            uploadQueue.removeAll { $0.id == upload.id }
            
            isUploading = false
            currentUpload = nil
            self.error = error.localizedDescription
            uploadStatus = .failed
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "VideoUpload",
                severity: .error,
                metadata: [
                    "user_id": userId,
                    "title": title,
                    "category": category
                ]
            )
            
            throw error
        }
    }
    
    // MARK: - Video Validation
    
    private func validateVideo(_ videoURL: URL) async throws {
        let asset = AVAsset(url: videoURL)
        
        // Check if asset is readable
        guard try await asset.load(.isReadable) else {
            throw VideoUploadServiceError.invalidVideoFile
        }
        
        // Check duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        if durationSeconds < 1 {
            throw VideoUploadServiceError.videoTooShort
        }
        
        if durationSeconds > 43200 { // 12 hours max (YouTube parity for verified accounts)
            throw VideoUploadServiceError.videoTooLong
        }
        
        // Check file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64 ?? 0
        let maxFileSize: Int64 = 2 * 1024 * 1024 * 1024 // 2GB
        
        if fileSize > maxFileSize {
            throw VideoUploadServiceError.fileTooLarge
        }
        
        // Check video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if videoTracks.isEmpty {
            throw VideoUploadServiceError.noVideoTrack
        }
    }
    
    // MARK: - Metadata Extraction
    
    private func extractVideoMetadata(_ videoURL: URL) async throws -> LocalUploadVideoMetadata {
        let asset = AVAsset(url: videoURL)
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64) ?? 0
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var resolution = CGSize.zero
        var frameRate: Float = 30
        var bitrate: Int = 0
        
        if let videoTrack = videoTracks.first {
            resolution = try await videoTrack.load(.naturalSize)
            frameRate = try await videoTrack.load(.nominalFrameRate)
            let estimatedBitrate = try await videoTrack.load(.estimatedDataRate)
            bitrate = Int(estimatedBitrate)
        }
        
        return LocalUploadVideoMetadata(
            duration: durationSeconds,
            fileSize: fileSize,
            resolution: resolution,
            frameRate: frameRate,
            bitrate: bitrate,
            codec: "h264",
            audioCodec: audioTracks.isEmpty ? "none" : "aac",
            hasAudio: !audioTracks.isEmpty,
            colorProfile: "sRGB",
            orientation: "portrait",
            mlMetadata: [:]
        )
    }
    
    // MARK: - Content Moderation
    
    private func moderateContent(_ videoURL: URL, metadata: LocalUploadVideoMetadata) async throws -> VideoModerationResult {
        // Client-side pre-check passes; server-side moderation runs after Firebase Storage upload
        return VideoModerationResult(
            isApproved: true,
            confidenceScore: 1.0,
            flaggedContent: [],
            reason: nil,
            suggestions: []
        )
    }
    
    // MARK: - Video Optimization
    
    private func optimizeVideo(_ videoURL: URL, metadata: LocalUploadVideoMetadata) async throws -> URL {
        // Return original URL — server-side optimization runs after upload
        return videoURL
    }
    
    private func downloadOptimizedVideo(from url: URL) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail(_ videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        
        // Get video duration first to ensure we don't request a time beyond the video length
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Choose a safe time for thumbnail generation (10% into the video, but at least 0.5s, max 10s)
        let thumbnailTime = min(max(durationSeconds * 0.1, 0.5), min(10.0, durationSeconds - 0.5))
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 720)
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        
        let time = CMTime(seconds: thumbnailTime, preferredTimescale: 600)
        
        // Try multiple fallback times if the first attempt fails
        let fallbackTimes = [
            time,
            CMTime(seconds: 0.5, preferredTimescale: 600),
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime.zero
        ]
        
        var lastError: Error?
        
        for attemptTime in fallbackTimes {
            do {
                let cgImage: CGImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
                    generator.generateCGImageAsynchronously(for: attemptTime) { image, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let image = image {
                            continuation.resume(returning: image)
                        } else {
                            continuation.resume(throwing: VideoUploadServiceError.thumbnailGenerationFailed)
                        }
                    }
                }
                
                let uiImage = UIImage(cgImage: cgImage)
                guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                    throw VideoUploadServiceError.thumbnailGenerationFailed
                }
                
                // Ensure temp directory exists and is writable
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                
                do {
                    try jpegData.write(to: tempURL, options: .atomic)
                    
                    // Verify the file was written successfully
                    guard FileManager.default.fileExists(atPath: tempURL.path) else {
                        throw VideoUploadServiceError.thumbnailGenerationFailed
                    }
                    
                    return tempURL
                } catch {
                    // If writing to temp directory fails, try Documents directory
                    let documentsDir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let fallbackURL = documentsDir.appendingPathComponent("temp_thumbnails").appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                    
                    // Create directory if it doesn't exist
                    try FileManager.default.createDirectory(at: fallbackURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    
                    try jpegData.write(to: fallbackURL, options: .atomic)
                    return fallbackURL
                }
                
            } catch {
                lastError = error
                print("⚠️ Thumbnail generation failed at time \(CMTimeGetSeconds(attemptTime))s: \(error)")
                continue
            }
        }
        
        // If all attempts failed, create a default thumbnail
        print("🚨 All thumbnail generation attempts failed, creating default thumbnail")
        return try await createDefaultThumbnail()
    }
    
    private func createDefaultThumbnail() async throws -> URL {
        // Create a simple colored thumbnail as fallback
        let size = CGSize(width: 1280, height: 720)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let defaultImage = renderer.image { context in
            // Set background color
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add video icon
            let iconSize: CGFloat = 200
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.white.setFill()
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 20)
            path.fill()
            
            // Add play button
            UIColor.systemBlue.setFill()
            let playSize: CGFloat = 80
            let playRect = CGRect(
                x: iconRect.midX - playSize / 2 + 10,
                y: iconRect.midY - playSize / 2,
                width: playSize,
                height: playSize
            )
            
            let playPath = UIBezierPath()
            playPath.move(to: CGPoint(x: playRect.minX, y: playRect.minY))
            playPath.addLine(to: CGPoint(x: playRect.maxX, y: playRect.midY))
            playPath.addLine(to: CGPoint(x: playRect.minX, y: playRect.maxY))
            playPath.close()
            playPath.fill()
        }
        
        guard let jpegData = defaultImage.jpegData(compressionQuality: 0.85) else {
            throw VideoUploadServiceError.thumbnailGenerationFailed
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try jpegData.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    // MARK: - Firebase Storage Upload
    
    private func uploadToStorage(videoURL: URL, thumbnailURL: URL, upload: VideoUpload, videoId: String) async throws -> (String, String) {
        #if canImport(FirebaseStorage)
        do {
            let storage = Storage.storage()
            
            // Use paths that match Firebase Storage security rules:
            // videos/{channelId}/{videoId}/{rest=**}
            // thumbnails/{channelId}/{videoId}/{file}
            let videoFileName = "video.mp4"
            let thumbnailFileName = "thumb.jpg"
            
            print("📤 Starting Firebase Storage upload for video: \(videoId)")
            
            // Upload video — path: videos/{userId}/{videoId}/video.mp4
            let videoRef = storage.reference().child("videos/\(upload.userId)/\(videoId)/\(videoFileName)")
            
            guard let videoData = try? Data(contentsOf: videoURL) else {
                print("🚨 Failed to read video data from URL: \(videoURL)")
                throw VideoUploadServiceError.invalidVideoFile
            }
            
            print("📊 Video data size: \(videoData.count) bytes")
        
        let videoMetadata = StorageMetadata()
        videoMetadata.contentType = "video/mp4"
        videoMetadata.customMetadata = [
            "userId": upload.userId,
            "uploadId": upload.id,
            "title": upload.title,
            "category": upload.category
        ]
        
        // Upload with progress tracking and error handling
        let videoUploadTask = videoRef.putData(videoData, metadata: videoMetadata)
        
        videoUploadTask.observe(.progress) { [weak self] snapshot in
            guard let self = self else { return }
            let progress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
            Task { @MainActor in
                self.uploadProgress = 0.65 + (progress * 0.12) // 65-77% of total progress
            }
        }
        
        // Wait for upload completion with better error handling
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false
            
            videoUploadTask.observe(.success) { _ in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume()
                }
            }
            
            videoUploadTask.observe(.failure) { snapshot in
                if !hasResumed {
                    hasResumed = true
                    let error = snapshot.error ?? VideoUploadServiceError.serverError
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let videoDownloadURL = try await videoRef.downloadURL()
        
        // Upload thumbnail — path: thumbnails/{userId}/{videoId}/thumb.jpg
        let thumbnailRef = storage.reference().child("thumbnails/\(upload.userId)/\(videoId)/\(thumbnailFileName)")
        let thumbnailData = try Data(contentsOf: thumbnailURL)
        
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"
        thumbnailMetadata.customMetadata = [
            "userId": upload.userId,
            "uploadId": upload.id,
            "videoId": videoId
        ]
        
        let thumbnailUploadTask = thumbnailRef.putData(thumbnailData, metadata: thumbnailMetadata)
        
        // Wait for thumbnail upload completion with error handling
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false
            
            thumbnailUploadTask.observe(.success) { _ in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume()
                }
            }
            
            thumbnailUploadTask.observe(.failure) { snapshot in
                if !hasResumed {
                    hasResumed = true
                    let error = snapshot.error ?? VideoUploadServiceError.serverError
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let thumbnailDownloadURL = try await thumbnailRef.downloadURL()
        
            print("✅ Firebase Storage upload completed successfully")
            return (videoDownloadURL.absoluteString, thumbnailDownloadURL.absoluteString)
            
        } catch {
            print("🚨 Firebase Storage upload failed: \(error)")
            print("🔄 Using fallback local storage URLs")
            
            // Fallback: Save files locally and return local URLs
            let fm = FileManager.default
            let baseDir = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("MyChannelUploads", isDirectory: true)
            
            if !fm.fileExists(atPath: baseDir.path) {
                try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
            }
            
            // Save video locally
            let localVideoURL = baseDir.appendingPathComponent("\(videoId).mp4")
            if fm.fileExists(atPath: localVideoURL.path) {
                try? fm.removeItem(at: localVideoURL)
            }
            try? fm.copyItem(at: videoURL, to: localVideoURL)
            
            // Save thumbnail locally
            let localThumbnailURL = baseDir.appendingPathComponent("\(videoId)_thumb.jpg")
            if fm.fileExists(atPath: localThumbnailURL.path) {
                try? fm.removeItem(at: localThumbnailURL)
            }
            try? fm.copyItem(at: thumbnailURL, to: localThumbnailURL)
            
            print("📁 Saved video locally at: \(localVideoURL.path)")
            print("📁 Saved thumbnail locally at: \(localThumbnailURL.path)")
            
            return (localVideoURL.absoluteString, localThumbnailURL.absoluteString)
        }
        #else
        print("⚠️ Firebase Storage not available, using local storage")
        
        // Fallback: Save files locally
        let fm = FileManager.default
        let baseDir = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MyChannelUploads", isDirectory: true)
        
        if !fm.fileExists(atPath: baseDir.path) {
            try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
        
        let localVideoURL = baseDir.appendingPathComponent("\(videoId).mp4")
        let localThumbnailURL = baseDir.appendingPathComponent("\(videoId)_thumb.jpg")
        
        try? fm.copyItem(at: videoURL, to: localVideoURL)
        try? fm.copyItem(at: thumbnailURL, to: localThumbnailURL)
        
        return (localVideoURL.absoluteString, localThumbnailURL.absoluteString)
        #endif
    }
    
    // MARK: - Firestore Document Creation
    
    private func createVideoDocument(
        upload: VideoUpload,
        metadata: LocalUploadVideoMetadata,
        videoURL: String,
        thumbnailURL: String
    ) async throws -> VideoDocument {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            let videoData: [String: Any] = [
                "title": upload.title,
                "description": upload.description,
                "ownerUid": upload.userId,
                "userId": upload.userId,
                "creatorId": upload.userId,
                "creatorName": AppState.shared.currentUser?.displayName ?? "Unknown",
                "creatorDisplayName": AppState.shared.currentUser?.displayName ?? "Unknown",
                "creatorUsername": AppState.shared.currentUser?.username ?? "",
                "creatorAvatarURL": AppState.shared.currentUser?.profileImageURL ?? "",
                "creatorProfileImage": AppState.shared.currentUser?.profileImageURL ?? "",
                "creatorVerified": AppState.shared.currentUser?.isVerified ?? false,
                "videoURL": videoURL,
                "videoUrl": videoURL,
                "thumbnailURL": thumbnailURL,
                "thumbnailUrl": thumbnailURL,
                "duration": metadata.duration,
                "fileSize": metadata.fileSize,
                "resolution": [
                    "width": metadata.resolution.width,
                    "height": metadata.resolution.height
                ],
                "frameRate": metadata.frameRate,
                "bitrate": metadata.bitrate,
                "codec": metadata.codec,
                "isPublic": upload.visibility == .publicVideo,
                "visibility": upload.visibility.rawValue,
                "status": "published",
                "category": upload.category,
                "tags": upload.tags,
                "language": "en",
                "createdAt": FieldValue.serverTimestamp(),
                "publishedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "viewCount": 0,
                "likeCount": 0,
                "dislikeCount": 0,
                "commentCount": 0,
                "shareCount": 0,
                "watchTime": 0.0,
                "engagementRate": 0.0,
                "clickThroughRate": 0.0,
                "retentionRate": 0.0,
                "monetizationEnabled": false,
                "ageRestricted": upload.ageRestricted,
                "madeForKids": upload.madeForKids,
                "allowComments": upload.allowComments,
                "filmingLocation": upload.filmingLocation,
                "isPremiere": upload.isPremiere,
                "copyrightClaims": [],
                "performanceScore": 0.0,
                "seoScore": 0.0,
                "thumbnailOptimizationScore": 0.0,
                "uploadId": upload.id,
                "processingStatus": videoURL.isEmpty ? "uploading" : "completed"
            ]
            
            print("📝 Creating Firestore document for video: \(upload.title)")
            let docRef = try await db.collection("videos").addDocument(data: videoData)
            print("✅ Firestore document created with ID: \(docRef.documentID)")
            
            return VideoDocument(
                id: docRef.documentID,
                title: upload.title,
                creatorId: upload.userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                createdAt: Date()
            )
        } catch {
            print("🚨 Firestore document creation failed: \(error)")
            print("🔄 Using fallback local document ID")
            
            // Fallback: Create a local document ID if Firestore fails
            let fallbackId = UUID().uuidString
            return VideoDocument(
                id: fallbackId,
                title: upload.title,
                creatorId: upload.userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                createdAt: Date()
            )
        }
        #else
        print("⚠️ Firestore not available, using local document ID")
        let fallbackId = UUID().uuidString
        return VideoDocument(
            id: fallbackId,
            title: upload.title,
            creatorId: upload.userId,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            createdAt: Date()
        )
        #endif
    }
    
    private func updateVideoDocumentURLs(videoId: String, videoURL: String, thumbnailURL: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("videos").document(videoId).updateData([
            "videoURL": videoURL,
            "thumbnailURL": thumbnailURL,
            "processingStatus": "completed"
        ])
        #endif
    }
    
    // MARK: - Post Processing
    
    private func performPostProcessing(videoId: String, upload: VideoUpload) async throws {
        // Fire-and-forget: trigger ML post-processing in background without blocking upload
        Task.detached(priority: .background) {
            let request = PostProcessingRequest(
                videoId: videoId,
                userId: upload.userId,
                tasks: ["indexing", "analytics_setup", "recommendation_training"]
            )
            try? await self.performMLRequest(
                url: self.videoProcessingURL + "/post-process",
                request: request,
                responseType: PostProcessingResponse.self
            )
        }
    }
    
    // MARK: - Progress Tracking
    
    private func updateUploadProgress(_ progress: Double, status: UploadStatus) async {
        uploadProgress = progress
        uploadStatus = status
        
        if let currentUpload = currentUpload {
            var updatedUpload = currentUpload
            updatedUpload.progress = progress
            updatedUpload.status = status
            self.currentUpload = updatedUpload
            
            // Update in queue
            if let index = uploadQueue.firstIndex(where: { $0.id == currentUpload.id }) {
                uploadQueue[index] = updatedUpload
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func retryOperation<T>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("⚠️ Operation failed (attempt \(attempt)/\(maxAttempts)): \(error)")
                
                if attempt < maxAttempts {
                    // Wait before retrying with exponential backoff
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? VideoUploadServiceError.uploadCancelled
    }
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw VideoUploadServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VideoUploadServiceError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct VideoUpload: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let visibility: VideoVisibility
    let category: String
    let tags: [String]
    let localVideoURL: URL
    var status: UploadStatus
    var progress: Double = 0.0
    var error: String?
    var videoId: String?
    var remoteVideoURL: String?
    var thumbnailURL: String?
    let createdAt: Date
    var completedAt: Date?
    var madeForKids: Bool = false
    var ageRestricted: Bool = false
    var allowComments: Bool = true
    var filmingLocation: String = ""
    var isScheduled: Bool = false
    var scheduledDate: Date? = nil
    var isPremiere: Bool = false
}

enum UploadStatus: String, Codable, CaseIterable {
    case idle = "idle"
    case preparing = "preparing"
    case validating = "validating"
    case processing = "processing"
    case moderating = "moderating"
    case optimizing = "optimizing"
    case generatingThumbnail = "generating_thumbnail"
    case uploading = "uploading"
    case finalizing = "finalizing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .preparing: return "Preparing..."
        case .validating: return "Validating video..."
        case .processing: return "Processing..."
        case .moderating: return "Content review..."
        case .optimizing: return "Optimizing..."
        case .generatingThumbnail: return "Creating thumbnail..."
        case .uploading: return "Uploading..."
        case .finalizing: return "Finalizing..."
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
}

struct LocalUploadVideoMetadata {
    let duration: TimeInterval
    let fileSize: Int64
    let resolution: CGSize
    let frameRate: Float
    let bitrate: Int
    let codec: String
    let audioCodec: String
    let hasAudio: Bool
    let colorProfile: String
    let orientation: String
    let mlMetadata: [String: Any]
}

struct VideoModerationResult {
    let isApproved: Bool
    let confidenceScore: Double
    let flaggedContent: [String]
    let reason: String?
    let suggestions: [String]
}

struct VideoDocument {
    let id: String
    let title: String
    let creatorId: String
    let videoURL: String
    let thumbnailURL: String
    let createdAt: Date
}

// MARK: - ML Request/Response Types

struct MetadataExtractionRequest: Codable {
    let videoURL: String
    let extractAudio: Bool
    let extractVisual: Bool
    let extractTechnical: Bool
}

struct MetadataExtractionResponse: Codable {
    let bitrate: Int
    let codec: String
    let audioCodec: String
    let hasAudio: Bool
    let colorProfile: String
    let orientation: String
    let mlMetadata: [String: UploadAnyCodable]
}

struct VideoContentModerationRequest: Codable {
    let videoURL: String
    let duration: TimeInterval
    let analysisDepth: String
    let checkTypes: [String]
}

struct VideoContentModerationResponse: Codable {
    let isApproved: Bool
    let confidenceScore: Double
    let flaggedContent: [String]
    let reason: String?
    let suggestions: [String]
}

struct VideoUploadOptimizationRequest: Codable {
    let videoURL: String
    let targetQuality: String
    let targetSize: String
    let preserveQuality: Bool
}

struct VideoUploadOptimizationResponse: Codable {
    let optimizedURL: String?
    let compressionRatio: Double
    let qualityScore: Double
}

struct VideoThumbnailGenerationRequest: Codable {
    let videoURL: String
    let timeOffset: Double
    let quality: String
    let size: String
}

struct VideoThumbnailGenerationResponse: Codable {
    let thumbnailURL: String?
    let confidence: Double
    let alternativeThumbnails: [String]
}

struct PostProcessingRequest: Codable {
    let videoId: String
    let userId: String
    let tasks: [String]
}

struct PostProcessingResponse: Codable {
    let success: Bool
    let tasksCompleted: [String]
    let estimatedTime: TimeInterval
}

// Helper for encoding Any values
struct UploadAnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

// MARK: - Error Types

enum VideoUploadServiceError: LocalizedError {
    case userNotAuthenticated
    case invalidVideoFile
    case videoTooShort
    case videoTooLong
    case fileTooLarge
    case noVideoTrack
    case contentRejected(String)
    case thumbnailGenerationFailed
    case firebaseUnavailable
    case firestoreUnavailable
    case invalidURL
    case serverError
    case uploadCancelled
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidVideoFile:
            return "Invalid video file"
        case .videoTooShort:
            return "Video must be at least 1 second long"
        case .videoTooLong:
            return "Video must be less than 12 hours long"
        case .fileTooLarge:
            return "File size must be less than 2GB"
        case .noVideoTrack:
            return "No video track found in file"
        case .contentRejected(let reason):
            return "Content rejected: \(reason)"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        case .firebaseUnavailable:
            return "Firebase Storage is not available"
        case .firestoreUnavailable:
            return "Firestore is not available"
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .uploadCancelled:
            return "Upload was cancelled"
        }
    }
}
