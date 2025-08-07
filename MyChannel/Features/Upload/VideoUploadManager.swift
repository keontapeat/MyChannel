//
//  VideoUploadManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

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
    @Published var monetizationEnabled: Bool = false
    
    private let maxVideoSize: Int64 = 2_000_000_000 // 2GB
    private let allowedFormats = ["mp4", "mov", "avi", "mkv"]
    
    // MARK: - Video Selection
    func loadSelectedVideo() async {
        guard let selectedVideo = selectedVideo else { return }
        
        do {
            // Load video data
            if let data = try await selectedVideo.loadTransferable(type: Data.self) {
                self.videoData = data
                
                // Create temporary URL for processing
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                try data.write(to: tempURL)
                self.videoURL = tempURL
                
                // Generate thumbnail
                await generateThumbnail(from: tempURL)
                
                // Validate video
                try await validateVideo(at: tempURL)
            }
        } catch {
            uploadError = "Failed to load video: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Video Processing
    private func generateThumbnail(from url: URL) async {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: CMTime(seconds: 1, preferredTimescale: 60)).image
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate thumbnail: \(error)")
        }
    }
    
    private func validateVideo(at url: URL) async throws {
        let asset = AVAsset(url: url)
        
        // Check file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        if fileSize > maxVideoSize {
            throw UploadError.fileTooLarge
        }
        
        // Check format
        let fileExtension = url.pathExtension.lowercased()
        if !allowedFormats.contains(fileExtension) {
            throw UploadError.unsupportedFormat
        }
        
        // Check duration (max 12 hours)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        if durationSeconds > 43200 { // 12 hours
            throw UploadError.videoTooLong
        }
        
        // Check if video has video track
        let videoTracks = try await asset.load(.tracks)
        if videoTracks.isEmpty {
            throw UploadError.noVideoTrack
        }
    }
    
    // MARK: - Upload Process
    func uploadVideo() async {
        guard let videoData = videoData,
              !title.isEmpty else {
            uploadError = "Please select a video and provide a title"
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil
        
        do {
            // Prepare metadata
            let metadata = VideoMetadata(
                title: title,
                description: description,
                tags: Array(selectedTags),
                category: selectedCategory,
                isPublic: isPublic,
                thumbnailData: thumbnail?.jpegData(compressionQuality: 0.8)
            )
            
            // Upload to server
            uploadedVideo = try await uploadVideoWithProgress(videoData, metadata: metadata)
            
            // Clean up
            cleanupTempFiles()
            
            // Reset form
            resetForm()
            
        } catch {
            uploadError = error.localizedDescription
        }
        
        isUploading = false
    }
    
    private func uploadVideoWithProgress(_ data: Data, metadata: VideoMetadata) async throws -> Video {
        // Simulate progress updates
        let totalSteps = 10
        for step in 1...totalSteps {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            uploadProgress = Double(step) / Double(totalSteps)
        }
        
        // For now, create a mock uploaded video since API doesn't exist yet
        let mockVideo = Video(
            title: metadata.title,
            description: metadata.description,
            thumbnailURL: "https://picsum.photos/400/225?random=\(Int.random(in: 1...100))",
            videoURL: "https://example.com/uploaded-video.mp4",
            duration: 300,
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            creator: User.sampleUsers[0],
            category: metadata.category,
            tags: metadata.tags,
            isPublic: metadata.isPublic
        )
        
        return mockVideo
    }
    
    // MARK: - Cleanup
    private func cleanupTempFiles() {
        if let videoURL = videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
    }
    
    private func resetForm() {
        selectedVideo = nil
        videoData = nil
        videoURL = nil
        thumbnail = nil
        title = ""
        description = ""
        selectedTags.removeAll()
        selectedCategory = .entertainment
        isPublic = true
        monetizationEnabled = false
        uploadProgress = 0.0
    }
    
    // MARK: - Video Editing (Basic)
    func trimVideo(startTime: CMTime, endTime: CMTime) async throws -> URL {
        guard let videoURL = videoURL else {
            throw UploadError.noVideoSelected
        }
        
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
        
        // Export trimmed video
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
            return outputURL
        } else {
            throw UploadError.exportFailed
        }
    }
}

// MARK: - Upload Errors
enum UploadError: Error, LocalizedError {
    case fileTooLarge
    case unsupportedFormat
    case videoTooLong
    case noVideoTrack
    case noVideoSelected
    case exportFailed
    case networkError(String)
    
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
        }
    }
}

#Preview {
    Text("Video Upload Manager")
        .font(.largeTitle)
        .padding()
}