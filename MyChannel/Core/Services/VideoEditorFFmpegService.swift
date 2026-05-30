import Foundation
import AVFoundation

/// A Beast Mode service that powers on-device video compression, 
/// trimming, and advanced editing for "Shorts" using native AVFoundation.
final class VideoEditorFFmpegService {
    static let shared = VideoEditorFFmpegService()
    
    private init() {}
    
    /// Compresses a video file to 720p and optimizes it for ultra-fast web streaming
    /// - Parameters:
    ///   - inputURL: The local URL of the raw video file
    ///   - outputURL: The destination URL for the compressed file
    /// - Returns: A boolean indicating success
    func compressVideoForWeb(inputURL: URL, outputURL: URL) async throws -> Bool {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return false
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("🎬 Beast Mode: Starting Native Compression...")
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            print("✅ Native Compression Successful!")
            return true
        case .failed, .cancelled:
            print("❌ Native Compression Failed or Cancelled: \(String(describing: exportSession.error))")
            return false
        default:
            return false
        }
    }
}
