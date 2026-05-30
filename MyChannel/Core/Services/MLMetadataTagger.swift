import Foundation
import CoreML
import Vision
import AVFoundation

/// Phase 48: Local Neural Engine Metadata Tagger
/// Uses CoreML object detection on video keyframes to auto-generate video tags and keywords prior to upload.
final class MLMetadataTagger {
    static let shared = MLMetadataTagger()
    
    private init() {}
    
    /// Analyzes a video file and generates a set of keywords using Vision and a generic Image Classification model.
    func generateTags(for videoURL: URL) async throws -> [String] {
        // We will sample 3 frames from the video (Start, Middle, End) to extract concepts
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return [] }
        
        let timesToSample = [
            duration * 0.1,
            duration * 0.5,
            duration * 0.9
        ]
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        var allTags: Set<String> = []
        
        // Use Apple's built-in VNClassifyImageRequest for generic object classification
        // In a real FAANG app, you'd use a custom MobileNetV2 or YOLOv8 CoreML model here.
        let request = VNClassifyImageRequest()
        
        for time in timesToSample {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
                guard let results = request.results else { continue }
                
                // Extract top 3 high-confidence tags from this frame
                let topResults = results.prefix(3).filter { $0.confidence > 0.7 }
                for observation in topResults {
                    allTags.insert(observation.identifier.lowercased())
                }
            } catch {
                print("⚠️ [MLMetadataTagger] Failed to analyze frame at \(time)s: \(error)")
            }
        }
        
        print("🧠 [MLMetadataTagger] Generated auto-tags: \(allTags)")
        return Array(allTags)
    }
}
