//
//  ProfileMediaUploader.swift
//  MyChannel
//
//  Created by AI Assistant on 8/12/25.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Profile Media Uploader (HEVC compression + upload)
@MainActor
enum ProfileMediaUploader {
    static let maxBannerDuration: TimeInterval = 15 // seconds
    static let maxBannerSizeBytes: Int64 = 50 * 1024 * 1024 // 50MB
    
    // Compress to HEVC and trim to max duration. Returns a local file URL ready for upload.
    static func prepareBannerVideo(from inputURL: URL) async throws -> URL {
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        
        // Build composition with optional trim
        let composition = AVMutableComposition()
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw UploadError.noVideoTrack
        }
        let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let endTime = CMTime(seconds: min(totalSeconds, maxBannerDuration), preferredTimescale: 600)
        let timeRange = CMTimeRange(start: .zero, end: endTime)
        try compVideo?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        // Preserve audio if exists
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compAudio?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        // Try export with HEVC 1080p first, then fallback to 720p (H.264 preset)
        let presets = [AVAssetExportPresetHEVC1920x1080, AVAssetExportPreset1280x720]
        for preset in presets {
            if let url = try await export(composition: composition, presetName: preset) {
                // Validate file size
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                if size > 0 && size <= maxBannerSizeBytes {
                    return url
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        
        // As a last resort, try HEVC Highest (may be large)
        if let url = try await export(composition: composition, presetName: AVAssetExportPresetHEVCHighestQuality) {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? .max
            if size <= maxBannerSizeBytes { return url }
            try? FileManager.default.removeItem(at: url)
        }
        
        throw UploadError.fileTooLarge
    }
    
    // Upload to API and return remote URL string
    static func uploadBannerVideo(_ url: URL, fileName: String) async throws -> String {
        let data = try Data(contentsOf: url)
        let response = try await NetworkService.shared.uploadFile(
            endpoint: .custom("/users/me/banner"),
            fileData: data,
            fileName: fileName,
            mimeType: "video/mp4"
        )
        return response.fileUrl
    }
    
    // MARK: - Private helpers
    private static func export(composition: AVMutableComposition, presetName: String) async throws -> URL? {
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else { return nil }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("banner_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        await exportSession.export()
        if exportSession.status == .completed {
            return outputURL
        } else {
            return nil
        }
    }
}


