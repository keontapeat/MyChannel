//
//  VideoService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI

// MARK: - Video Service
@MainActor
class VideoService: ObservableObject {
    static let shared = VideoService()
    
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var processingStatus: VideoProcessingStatus = .idle
    
    private let networkService = NetworkService.shared
    private let storageService = StorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Video Processing Status
    enum VideoProcessingStatus {
        case idle
        case validating
        case compressing
        case uploading
        case processing
        case completed
        case failed(String)
        
        var displayText: String {
            switch self {
            case .idle: return "Ready"
            case .validating: return "Validating video..."
            case .compressing: return "Compressing video..."
            case .uploading: return "Uploading..."
            case .processing: return "Processing video..."
            case .completed: return "Upload complete!"
            case .failed(let error): return "Failed: \(error)"
            }
        }
    }
    
    private init() {
        setupVideoProcessing()
    }
    
    // MARK: - Setup
    private func setupVideoProcessing() {
        // Monitor upload progress
        NotificationCenter.default.publisher(for: .videoUploadProgress)
            .compactMap { $0.userInfo?["progress"] as? Double }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.uploadProgress = progress
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Fetch Videos
    func fetchVideos(page: Int = 1, limit: Int = 20) async throws -> [Video] {
        if AppConfig.Features.enableMockData {
            // Return mock data for development
            return Video.sampleVideos
        }
        
        do {
            let response: APIResponse<[Video]> = try await networkService.get(
                endpoint: .videos,
                responseType: APIResponse<[Video]>.self,
                headers: ["page": "\(page)", "limit": "\(limit)"]
            )
            return response.data
        } catch {
            throw VideoServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    func fetchVideo(id: String) async throws -> Video {
        if AppConfig.Features.enableMockData {
            return Video.sampleVideos.first { $0.id == id } ?? Video.sampleVideos[0]
        }
        
        do {
            let response: APIResponse<Video> = try await networkService.get(
                endpoint: .video(id),
                responseType: APIResponse<Video>.self
            )
            return response.data
        } catch {
            throw VideoServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    func fetchTrendingVideos() async throws -> [Video] {
        if AppConfig.Features.enableMockData {
            return Video.sampleVideos.filter { $0.viewCount > 100000 }
        }
        
        do {
            let response: APIResponse<[Video]> = try await networkService.get(
                endpoint: .trending,
                responseType: APIResponse<[Video]>.self
            )
            return response.data
        } catch {
            throw VideoServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Video Upload
    func uploadVideo(
        videoURL: URL,
        metadata: UploadVideoMetadata,
        thumbnailImage: UIImage? = nil
    ) async throws -> Video {
        
        processingStatus = .validating
        isUploading = true
        uploadProgress = 0.0
        
        do {
            // Step 1: Validate video
            try await validateVideo(url: videoURL)
            uploadProgress = 0.1
            
            // Step 2: Generate thumbnail if not provided
            var thumbnail: UIImage
            if let thumbnailImage = thumbnailImage {
                thumbnail = thumbnailImage
            } else {
                thumbnail = try await generateThumbnail(from: videoURL)
            }
            uploadProgress = 0.2
            
            // Step 3: Compress video if needed
            processingStatus = .compressing
            let compressedVideoURL = try await compressVideo(url: videoURL)
            uploadProgress = 0.4
            
            // Step 4: Upload thumbnail
            let thumbnailURL = try await uploadThumbnail(thumbnail)
            uploadProgress = 0.5
            
            // Step 5: Upload video file
            processingStatus = .uploading
            let videoFileURL = try await uploadVideoFile(compressedVideoURL)
            uploadProgress = 0.8
            
            // Step 6: Create video record
            processingStatus = .processing
            let video = try await createVideoRecord(
                metadata: metadata,
                videoURL: videoFileURL,
                thumbnailURL: thumbnailURL
            )
            uploadProgress = 1.0
            
            processingStatus = .completed
            isUploading = false
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: compressedVideoURL)
            
            // Show success notification
            NotificationManager.shared.showSuccess("Video uploaded successfully!")
            
            return video
            
        } catch {
            processingStatus = .failed(error.localizedDescription)
            isUploading = false
            uploadProgress = 0.0
            
            NotificationManager.shared.showError("Upload failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Video Validation
    private func validateVideo(url: URL) async throws {
        let asset = AVAsset(url: url)
        
        // Check if asset is readable
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            throw VideoServiceError.invalidFormat
        }
        
        // Check duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds > 0 else {
            throw VideoServiceError.invalidFormat
        }
        
        guard durationSeconds <= AppConfig.Video.maxDurationSeconds else {
            throw VideoServiceError.durationTooLong
        }
        
        // Check file size
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let maxSizeBytes = AppConfig.Video.maxUploadSizeMB * 1024 * 1024
        
        guard fileSize <= maxSizeBytes else {
            throw VideoServiceError.fileTooLarge
        }
        
        // Check format - use the async tracks loading
        let tracks = try await asset.load(.tracks)
        var hasVideoTrack = false
        
        for track in tracks {
            // Use the synchronous mediaType property
            if track.mediaType == .video {
                hasVideoTrack = true
                break
            }
        }
        
        guard hasVideoTrack else {
            throw VideoServiceError.noVideoTrack
        }
    }
    
    // MARK: - Thumbnail Generation
    func generateThumbnail(from videoURL: URL, at time: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) async throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = AppConfig.Video.thumbnailSize
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                if let error = error {
                    continuation.resume(throwing: VideoServiceError.thumbnailGenerationFailed(error.localizedDescription))
                } else if let cgImage = cgImage {
                    let uiImage = UIImage(cgImage: cgImage)
                    continuation.resume(returning: uiImage)
                } else {
                    continuation.resume(throwing: VideoServiceError.thumbnailGenerationFailed("Unknown error"))
                }
            }
        }
    }
    
    // MARK: - Video Compression
    private func compressVideo(url: URL) async throws -> URL {
        let outputURL = url.appendingPathExtension("compressed.mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: AVAsset(url: url),
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw VideoServiceError.compressionFailed("Unable to create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: VideoServiceError.compressionFailed(exportSession.error?.localizedDescription ?? "Unknown error"))
                case .cancelled:
                    continuation.resume(throwing: VideoServiceError.compressionCancelled)
                default:
                    continuation.resume(throwing: VideoServiceError.compressionFailed("Unexpected status"))
                }
            }
        }
    }
    
    // MARK: - File Upload
    private func uploadThumbnail(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VideoServiceError.thumbnailProcessingFailed
        }
        
        let fileName = "thumbnail_\(UUID().uuidString).jpg"
        
        let response = try await networkService.uploadFile(
            endpoint: .uploadVideo,
            fileData: imageData,
            fileName: fileName,
            mimeType: "image/jpeg",
            additionalFields: ["type": "thumbnail"]
        )
        
        return response.fileUrl
    }
    
    private func uploadVideoFile(_ videoURL: URL) async throws -> String {
        let videoData = try Data(contentsOf: videoURL)
        let fileName = "video_\(UUID().uuidString).mp4"
        
        let response = try await networkService.uploadFile(
            endpoint: .uploadVideo,
            fileData: videoData,
            fileName: fileName,
            mimeType: "video/mp4",
            additionalFields: ["type": "video"],
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.uploadProgress = 0.5 + (progress * 0.3) // 50% to 80% of total progress
                }
            }
        )
        
        return response.fileUrl
    }
    
    // MARK: - Video Record Creation
    private func createVideoRecord(
        metadata: UploadVideoMetadata,
        videoURL: String,
        thumbnailURL: String
    ) async throws -> Video {
        
        let request = VideoUploadRequest(
            title: metadata.title,
            description: metadata.description,
            category: metadata.category.rawValue,
            tags: metadata.tags,
            isPublic: metadata.isPublic,
            thumbnailUrl: thumbnailURL,
            scheduledAt: metadata.scheduledDate
        )
        
        let response: APIResponse<Video> = try await networkService.post(
            endpoint: .uploadVideo,
            body: request,
            responseType: APIResponse<Video>.self
        )
        
        return response.data
    }
    
    // MARK: - Video Interactions
    func likeVideo(_ videoId: String) async throws {
        if AppConfig.Features.enableMockData {
            // Mock implementation
            return
        }
        
        let _: APIResponse<EmptyResponse> = try await networkService.post(
            endpoint: .likeVideo(videoId),
            body: EmptyRequest(),
            responseType: APIResponse<EmptyResponse>.self
        )
    }
    
    func unlikeVideo(_ videoId: String) async throws {
        if AppConfig.Features.enableMockData {
            return
        }
        
        let _: APIResponse<EmptyResponse> = try await networkService.delete(
            endpoint: .unlikeVideo(videoId),
            responseType: APIResponse<EmptyResponse>.self
        )
    }
    
    func deleteVideo(_ videoId: String) async throws {
        if AppConfig.Features.enableMockData {
            return
        }
        
        let _: APIResponse<EmptyResponse> = try await networkService.delete(
            endpoint: .deleteVideo(videoId),
            responseType: APIResponse<EmptyResponse>.self
        )
    }
    
    // MARK: - Video Analytics
    func recordView(videoId: String) async {
        // Record video view for analytics
        Task {
            do {
                let analytics = AnalyticsService.shared
                await analytics.trackEvent(AppConfig.Analytics.videoWatchEvent, parameters: [
                    "video_id": videoId,
                    "timestamp": String(Int(Date().timeIntervalSince1970))
                ])
            } catch {
                print("Failed to record video view: \(error)")
            }
        }
    }
    
    // MARK: - Video Quality Management
    func getAvailableQualities(for videoURL: String) async -> [AppConfig.Video.Quality] {
        // In a real implementation, this would check what qualities are available
        // For now, return default qualities
        return AppConfig.Video.Quality.allCases
    }
    
    func getVideoURL(for videoId: String, quality: AppConfig.Video.Quality) async throws -> String {
        if AppConfig.Features.enableMockData {
            return "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        }
        
        // In a real implementation, this would return the URL for the specific quality
        let response: APIResponse<VideoStreamResponse> = try await networkService.get(
            endpoint: .video(videoId),
            responseType: APIResponse<VideoStreamResponse>.self,
            headers: ["quality": quality.rawValue]
        )
        
        return response.data.streamUrl
    }
}

// MARK: - Video Service Errors
enum VideoServiceError: LocalizedError {
    case invalidFormat
    case durationTooLong
    case fileTooLarge
    case noVideoTrack
    case thumbnailGenerationFailed(String)
    case thumbnailProcessingFailed
    case compressionFailed(String)
    case compressionCancelled
    case uploadFailed(String)
    case fetchFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid video format. Please use MP4, MOV, or AVI."
        case .durationTooLong:
            return "Video is too long. Maximum duration is \(Int(AppConfig.Video.maxDurationSeconds/60)) minutes."
        case .fileTooLarge:
            return "Video file is too large. Maximum size is \(AppConfig.Video.maxUploadSizeMB)MB."
        case .noVideoTrack:
            return "No video track found in the file."
        case .thumbnailGenerationFailed(let error):
            return "Failed to generate thumbnail: \(error)"
        case .thumbnailProcessingFailed:
            return "Failed to process thumbnail image."
        case .compressionFailed(let error):
            return "Failed to compress video: \(error)"
        case .compressionCancelled:
            return "Video compression was cancelled."
        case .uploadFailed(let error):
            return "Upload failed: \(error)"
        case .fetchFailed(let error):
            return "Failed to fetch videos: \(error)"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        }
    }
}

// MARK: - Supporting Models
struct UploadVideoMetadata {
    let title: String
    let description: String
    let category: VideoCategory
    let tags: [String]
    let isPublic: Bool
    let scheduledDate: Date?
}

struct VideoStreamResponse: Codable {
    let streamUrl: String
    let quality: String
    let duration: TimeInterval
    let fileSize: Int
}

// MARK: - Storage Service (Placeholder)
class StorageService {
    static let shared = StorageService()
    private init() {}
    
    func uploadFile(_ data: Data, to path: String) async throws -> String {
        // This would integrate with your cloud storage provider
        // For now, return a mock URL
        return "https://storage.example.com/\(path)"
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let videoUploadProgress = Notification.Name("videoUploadProgress")
    static let videoUploadCompleted = Notification.Name("videoUploadCompleted")
    static let videoUploadFailed = Notification.Name("videoUploadFailed")
}

// MARK: - Preview
#Preview("Video Service Status") {
    VStack(spacing: 20) {
        Text("Video Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                Spacer()
                Text(VideoService.shared.processingStatus.displayText)
                    .foregroundColor(.secondary)
            }
            
            if VideoService.shared.isUploading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Upload Progress:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(VideoService.shared.uploadProgress * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: VideoService.shared.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.Colors.primary))
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration:")
                    .fontWeight(.medium)
                
                Text("Max Upload Size: \(AppConfig.Video.maxUploadSizeMB)MB")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Max Duration: \(Int(AppConfig.Video.maxDurationSeconds/60)) minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Supported Formats: \(AppConfig.Video.supportedFormats.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Spacer()
    }
    .padding()
}