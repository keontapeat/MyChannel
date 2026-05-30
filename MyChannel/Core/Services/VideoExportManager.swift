import Foundation
import AVFoundation

/// Phase 35 & 70: Hardware Accelerated Video Export
/// Compresses 4K to HEVC (H.265) and trims video before upload.
final class VideoExportManager {
    static let shared = VideoExportManager()
    
    private init() {}
    
    /// Trims and compresses a video from the given source URL to the destination URL.
    /// - Parameters:
    ///   - sourceURL: The local URL of the original video.
    ///   - destinationURL: The local URL where the exported video should be saved.
    ///   - startTime: The start time for trimming (in seconds).
    ///   - endTime: The end time for trimming (in seconds).
    /// - Returns: The URL of the successfully exported video.
    func exportAndTrimVideo(
        sourceURL: URL,
        destinationURL: URL,
        startTime: Double,
        endTime: Double
    ) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        
        // Ensure the asset is exportable
        let isExportable = try await asset.load(.isExportable)
        guard isExportable else {
            throw ExportError.notExportable
        }
        
        // Phase 70: Use HEVC Highest Quality for hardware acceleration
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw ExportError.sessionCreationFailed
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Define the time range for trimming
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)
        
        exportSession.timeRange = timeRange
        
        // Perform the export
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return destinationURL
        case .failed:
            throw exportSession.error ?? ExportError.unknown
        case .cancelled:
            throw ExportError.cancelled
        default:
            throw ExportError.unknown
        }
    }
    
    enum ExportError: Error {
        case notExportable
        case sessionCreationFailed
        case cancelled
        case unknown
    }
}
