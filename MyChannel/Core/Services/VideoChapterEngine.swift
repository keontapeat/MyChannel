import Foundation
import AVFoundation
import Vision

/// Phase 36: Intelligent Video Chapters
/// Analyzes a video file to detect major scene changes and generates chapters.
final class VideoChapterEngine {
    static let shared = VideoChapterEngine()
    
    private init() {}
    
    /// Generates chapters by detecting scene cuts using Vision.
    func generateChapters(for videoURL: URL) async throws -> [VideoChapter] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return [] }
        
        // We will sample 1 frame every 5 seconds to look for major shifts.
        // In a real FAANG-level implementation, you'd use a dedicated ML model
        // or a dense optical flow algorithm, but we use an approximation here.
        
        var chapters: [VideoChapter] = [VideoChapter(title: "Intro", startTime: 0)]
        var previousFrameFeaturePrint: VNFeaturePrintObservation?
        
        for time in stride(from: 5.0, to: duration, by: 5.0) {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                
                let request = VNGenerateImageFeaturePrintRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
                guard let currentFeaturePrint = request.results?.first as? VNFeaturePrintObservation else { continue }
                
                if let previous = previousFrameFeaturePrint {
                    var distance: Float = 0
                    try currentFeaturePrint.computeDistance(&distance, to: previous)
                    
                    // If distance is large enough, we classify it as a scene change / new chapter
                    if distance > 15.0 {
                        chapters.append(VideoChapter(title: "Chapter \(chapters.count + 1)", startTime: time))
                    }
                }
                
                previousFrameFeaturePrint = currentFeaturePrint
            } catch {
                print("⚠️ [VideoChapterEngine] Failed to process frame at \(time)s: \(error)")
            }
        }
        
        return chapters
    }
    struct VideoChapter: Identifiable, Codable {
        let id = UUID()
        let title: String
        let startTime: Double
    }
}
