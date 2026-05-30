import Foundation
import Vision
import CoreImage
import AVFoundation

/// Phase 67: On-Device Content Moderation
/// Uses Vision OCR to scan frames for inappropriate text and potentially blur them.
@MainActor
final class OnDeviceModerator {
    static let shared = OnDeviceModerator()
    
    private let bannedWords: Set<String> = ["curseword", "badword", "illegal"] // In a real app, this is fetched dynamically
    
    private init() {}
    
    /// Scans a single frame using VNRecognizeTextRequest.
    /// In a real FAANG pipeline, you'd chain this into an AVVideoCompositing filter (like MLUpscaleEngine).
    func scanFrameForInappropriateText(_ cgImage: CGImage) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var flaggedRects: [CGRect] = []
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string.lowercased()
                    
                    // Simple substring check against banned words
                    if self.bannedWords.contains(where: { text.contains($0) }) {
                        flaggedRects.append(observation.boundingBox)
                    }
                }
                
                continuation.resume(returning: flaggedRects)
            }
            
            // Optimize for speed since we're doing this in real-time
            request.recognitionLevel = .fast
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ [OnDeviceModerator] Failed to perform OCR: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}
