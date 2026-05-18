import Foundation
import AVFoundation

/// On-Device Video Processor (Edge Compute)
/// Uses the A-series/M-series GPU/Media Engine to multi-pass compress
/// and transcode video to HEVC (H.265) before uploading.
@MainActor
final class EdgeVideoProcessor {
    static let shared = EdgeVideoProcessor()
    
    private init() {}
    
    /// Compresses a local video to H.265 (HEVC) using Apple's Hardware Media Engine
    func compressVideoForUpload(inputURL: URL, outputURL: URL) async throws -> Bool {
        let asset = AVAsset(url: inputURL)
        
        // Use HEVC (H.265) to cut file size in half while maintaining 4K/1080p quality.
        // This utilizes the dedicated hardware encoder on the iPhone GPU.
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            print("⚠️ [NVIDIA Edge] Failed to create AVAssetExportSession.")
            return false
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true // Optimizes the mp4 container for streaming
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            print("🎥 [NVIDIA Edge] Hardware-accelerated HEVC compression complete!")
            return true
        case .failed:
            if let error = exportSession.error {
                print("⚠️ [NVIDIA Edge] Compression failed: \(error.localizedDescription)")
            }
            return false
        case .cancelled:
            print("⚠️ [NVIDIA Edge] Compression cancelled.")
            return false
        default:
            return false
        }
    }
}
