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
    
    // Added metadata
    @Published var videoDuration: TimeInterval = 0
    @Published var videoDimensions: CGSize = .zero
    @Published var fileSizeMB: Double = 0
    @Published var thumbnailTime: TimeInterval = 1.0
    
    private let maxVideoSize: Int64 = 2_000_000_000 // 2GB
    private let allowedFormats = ["mp4", "mov", "avi", "mkv"]
    
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
        
        do {
            let metadata = VideoMetadata(
                title: title,
                description: description,
                tags: Array(selectedTags),
                category: selectedCategory,
                isPublic: isPublic,
                thumbnailData: thumbnail?.jpegData(compressionQuality: 0.8)
            )
            
            uploadedVideo = try await uploadVideoWithProgress(videoData, metadata: metadata)
            cleanupTempFiles()
            resetForm()
        } catch {
            uploadError = error.localizedDescription
        }
        
        isUploading = false
    }
    
    private func uploadVideoWithProgress(_ data: Data, metadata: VideoMetadata) async throws -> Video {
        let totalSteps = 10
        for step in 1...totalSteps {
            try await Task.sleep(nanoseconds: 300_000_000)
            uploadProgress = Double(step) / Double(totalSteps)
        }
        
        let mockVideo = Video(
            title: metadata.title,
            description: metadata.description,
            thumbnailURL: "https://picsum.photos/400/225?random=\(Int.random(in: 1...100))",
            videoURL: "https://example.com/uploaded-video.mp4",
            duration: max(1, videoDuration),
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
        monetizationEnabled = false
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
    VStack {
        Text("Video Upload Manager")
            .font(.largeTitle)
            .padding()
        
        Text("Handles video metadata, thumbnails, and uploads")
            .foregroundColor(.secondary)
    }
}