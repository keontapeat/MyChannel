//
//  MatchProofUploadService.swift
//  MyChannel
//
//  Firebase Storage Upload Service for Match Proof Videos
//  Handles video/screenshot uploads with progress tracking
//

import Foundation
import SwiftUI
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class MatchProofUploadService: ObservableObject {
    static let shared = MatchProofUploadService()
    
    // Published state
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var currentUploadTask: StorageUploadTask?
    
    // Constants
    private let maxVideoSize: Int64 = 500_000_000 // 500MB
    private let maxVideoDuration: TimeInterval = 300 // 5 minutes
    private let allowedVideoFormats = ["mp4", "mov", "avi"]
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    private init() {
        print("✅ [MatchProofUpload] Service initialized")
    }
    
    // MARK: - Video Upload
    
    /// Upload match proof video to Firebase Storage
    /// - Parameters:
    ///   - videoURL: Local URL of video file
    ///   - matchId: Match identifier
    ///   - playerId: Player identifier
    /// - Returns: Download URL of uploaded video
    func uploadVideo(
        _ videoURL: URL,
        matchId: String,
        playerId: String
    ) async throws -> String {
        print("📹 [MatchProofUpload] Starting video upload for match: \(matchId)")
        
        // Validate video
        try validateVideo(url: videoURL)
        
        // Set uploading state
        isUploading = true
        uploadProgress = 0.0
        
        defer {
            isUploading = false
            currentUploadTask = nil
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let videoRef = storageRef
            .child("match-proofs")
            .child(matchId)
            .child(playerId)
            .child("video.\(videoURL.pathExtension)")
        
        // Read video data
        let videoData = try Data(contentsOf: videoURL)
        
        print("📤 [MatchProofUpload] Uploading \(videoData.count) bytes...")
        
        // Upload with progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            // Create metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/\(videoURL.pathExtension)"
            metadata.customMetadata = [
                "matchId": matchId,
                "playerId": playerId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Upload
            let uploadTask = videoRef.putData(videoData, metadata: metadata)
            currentUploadTask = uploadTask
            
            // Track progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let self = self else { return }
                if let progress = snapshot.progress {
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    Task { @MainActor in
                        self.uploadProgress = percentComplete
                    }
                    print("📊 [MatchProofUpload] Progress: \(Int(percentComplete * 100))%")
                }
            }
            
            // Handle completion
            uploadTask.observe(.success) { snapshot in
                print("✅ [MatchProofUpload] Upload successful!")
                
                // Get download URL
                videoRef.downloadURL { url, error in
                    if let error = error {
                        print("🚨 [MatchProofUpload] Failed to get download URL: \(error)")
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        print("🔗 [MatchProofUpload] Download URL: \(url.absoluteString)")
                        continuation.resume(returning: url.absoluteString)
                    }
                }
            }
            
            // Handle failure
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    print("🚨 [MatchProofUpload] Upload failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Screenshot Upload
    
    /// Upload screenshot to Firebase Storage
    /// - Parameters:
    ///   - image: Screenshot image
    ///   - matchId: Match identifier
    ///   - playerId: Player identifier
    /// - Returns: Download URL of uploaded screenshot
    func uploadScreenshot(
        _ image: UIImage,
        matchId: String,
        playerId: String
    ) async throws -> String {
        print("📸 [MatchProofUpload] Starting screenshot upload for match: \(matchId)")
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.imageCompressionFailed
        }
        
        // Validate size
        if imageData.count > 10_000_000 { // 10MB max
            throw UploadError.screenshotTooLarge
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let screenshotRef = storageRef
            .child("match-proofs")
            .child(matchId)
            .child(playerId)
            .child("screenshot.jpg")
        
        print("📤 [MatchProofUpload] Uploading screenshot (\(imageData.count) bytes)...")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "matchId": matchId,
            "playerId": playerId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Upload
        _ = try await screenshotRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let url = try await screenshotRef.downloadURL()
        
        print("✅ [MatchProofUpload] Screenshot uploaded: \(url.absoluteString)")
        
        return url.absoluteString
    }
    
    // MARK: - Metadata Upload
    
    /// Save match submission metadata to Firestore
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - playerId: Player identifier
    ///   - videoURL: Download URL of video
    ///   - screenshotURL: Download URL of screenshot (optional)
    ///   - selfReportedScore: Player's reported score
    ///   - opponentScore: Opponent's reported score
    func saveMetadata(
        matchId: String,
        playerId: String,
        videoURL: String,
        screenshotURL: String?,
        selfReportedScore: Int,
        opponentScore: Int
    ) async throws {
        print("💾 [MatchProofUpload] Saving metadata for match: \(matchId)")
        
        let metadata: [String: Any] = [
            "matchId": matchId,
            "playerId": playerId,
            "videoURL": videoURL,
            "screenshotURL": screenshotURL as Any,
            "selfReportedScore": selfReportedScore,
            "opponentScore": opponentScore,
            "submittedAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        try await db
            .collection("match_submissions")
            .document("\(matchId)_\(playerId)")
            .setData(metadata)
        
        print("✅ [MatchProofUpload] Metadata saved")
    }
    
    // MARK: - Validation
    
    /// Validate video file before upload
    /// - Parameter url: Local video URL
    private func validateVideo(url: URL) throws {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploadError.fileNotFound
        }
        
        // Check format
        let fileExtension = url.pathExtension.lowercased()
        guard allowedVideoFormats.contains(fileExtension) else {
            throw UploadError.invalidFormat
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            if fileSize > maxVideoSize {
                throw UploadError.fileTooLarge
            }
            print("📏 [MatchProofUpload] Video size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        }
        
        // Check duration
        let asset = AVAsset(url: url)
        let duration = asset.duration.seconds
        if duration > maxVideoDuration {
            throw UploadError.videoTooLong
        }
        
        print("⏱️ [MatchProofUpload] Video duration: \(Int(duration))s")
        print("✅ [MatchProofUpload] Video validation passed")
    }
    
    // MARK: - Cancel Upload
    
    /// Cancel current upload
    func cancelUpload() {
        print("🛑 [MatchProofUpload] Cancelling upload...")
        currentUploadTask?.cancel()
        isUploading = false
        uploadProgress = 0.0
        currentUploadTask = nil
    }
    
    // MARK: - Delete Proof
    
    /// Delete uploaded proof files
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - playerId: Player identifier
    func deleteProof(matchId: String, playerId: String) async throws {
        print("🗑️ [MatchProofUpload] Deleting proof for match: \(matchId)")
        
        let storageRef = storage.reference()
        let proofRef = storageRef
            .child("match-proofs")
            .child(matchId)
            .child(playerId)
        
        // Delete video
        let videoRef = proofRef.child("video.mp4")
        try? await videoRef.delete()
        
        // Delete screenshot
        let screenshotRef = proofRef.child("screenshot.jpg")
        try? await screenshotRef.delete()
        
        // Delete metadata
        try await db
            .collection("match_submissions")
            .document("\(matchId)_\(playerId)")
            .delete()
        
        print("✅ [MatchProofUpload] Proof deleted")
    }
}

// MARK: - Upload Error

enum UploadError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case fileTooLarge
    case videoTooLong
    case screenshotTooLarge
    case imageCompressionFailed
    case uploadCancelled
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file not found. Please select a valid video."
        case .invalidFormat:
            return "Invalid video format. Please use MP4, MOV, or AVI."
        case .fileTooLarge:
            return "Video file is too large. Maximum size is 500MB."
        case .videoTooLong:
            return "Video is too long. Maximum duration is 5 minutes."
        case .screenshotTooLarge:
            return "Screenshot is too large. Maximum size is 10MB."
        case .imageCompressionFailed:
            return "Failed to compress screenshot. Please try another image."
        case .uploadCancelled:
            return "Upload was cancelled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - AVAsset Extension

import AVFoundation

extension AVAsset {
    var duration: CMTime {
        return self.duration
    }
}

