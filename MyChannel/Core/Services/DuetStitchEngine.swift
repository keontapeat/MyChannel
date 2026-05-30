import Foundation
import AVFoundation
import UIKit

/// Phase 89: Video Stitching / Duet Engine
/// Uses AVMutableComposition to merge two videos side-by-side (TikTok Duet style).
@MainActor
final class DuetStitchEngine {
    static let shared = DuetStitchEngine()
    
    private init() {}
    
    /// Stitches two videos side-by-side.
    func stitchVideos(originalURL: URL, cameraURL: URL, outputURL: URL) async throws -> URL {
        let originalAsset = AVAsset(url: originalURL)
        let cameraAsset = AVAsset(url: cameraURL)
        
        let composition = AVMutableComposition()
        
        guard let originalTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let cameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DuetError.trackCreationFailed
        }
        
        let originalAssetTrack = try await originalAsset.loadTracks(withMediaType: .video).first!
        let cameraAssetTrack = try await cameraAsset.loadTracks(withMediaType: .video).first!
        
        let originalDuration = try await originalAsset.load(.duration)
        let cameraDuration = try await cameraAsset.load(.duration)
        
        // We use the shortest duration so they end at the same time
        let finalDuration = min(originalDuration, cameraDuration)
        let timeRange = CMTimeRange(start: .zero, duration: finalDuration)
        
        try originalTrack.insertTimeRange(timeRange, of: originalAssetTrack, at: .zero)
        try cameraTrack.insertTimeRange(timeRange, of: cameraAssetTrack, at: .zero)
        
        // Audio
        if let originalAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
           let assetAudioTrack = try await originalAsset.loadTracks(withMediaType: .audio).first {
            try originalAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        }
        
        if let cameraAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
           let assetAudioTrack = try await cameraAsset.loadTracks(withMediaType: .audio).first {
            try cameraAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        }
        
        // Instructions for layout
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = timeRange
        
        // Output will be a 16:9 1080p frame (1920x1080)
        let renderSize = CGSize(width: 1920, height: 1080)
        
        // Original Video (Left side) - 960x1080
        let originalLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: originalTrack)
        var originalTransform = try await originalAssetTrack.load(.preferredTransform)
        // Scale and move to left
        originalTransform = originalTransform.concatenating(CGAffineTransform(scaleX: 960.0 / 1920.0, y: 1080.0 / 1080.0))
        originalLayerInstruction.setTransform(originalTransform, at: .zero)
        
        // Camera Video (Right side) - 960x1080
        let cameraLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: cameraTrack)
        var cameraTransform = try await cameraAssetTrack.load(.preferredTransform)
        cameraTransform = cameraTransform.concatenating(CGAffineTransform(scaleX: 960.0 / 1920.0, y: 1080.0 / 1080.0))
        cameraTransform = cameraTransform.concatenating(CGAffineTransform(translationX: 960, y: 0))
        cameraLayerInstruction.setTransform(cameraTransform, at: .zero)
        
        mainInstruction.layerInstructions = [originalLayerInstruction, cameraLayerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize
        
        // Export
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw DuetError.exportSessionFailed
        }
        
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        
        await exporter.export()
        
        if exporter.status == .completed {
            return outputURL
        } else {
            throw exporter.error ?? DuetError.unknown
        }
    }
    
    enum DuetError: Error {
        case trackCreationFailed
        case exportSessionFailed
        case unknown
    }
}
