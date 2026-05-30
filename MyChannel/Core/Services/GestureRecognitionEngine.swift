import Foundation
import Vision
import AVFoundation

/// Phase 96: Vision Body Pose Estimation
/// Detects hand gestures (e.g. Thumbs Up) in the camera feed to trigger UI effects.
@MainActor
final class GestureRecognitionEngine: ObservableObject {
    static let shared = GestureRecognitionEngine()
    
    @Published var thumbsUpDetected: Bool = false
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var lastDetectionTime: Date = Date.distantPast
    
    private init() {}
    
    /// Processes a sample buffer from the camera to look for a thumbs up gesture.
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Limit processing to 5 FPS to save battery
        guard Date().timeIntervalSince(lastDetectionTime) > 0.2 else { return }
        lastDetectionTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            guard let results = request.results as? [VNHumanHandPoseObservation], !results.isEmpty else {
                Task { @MainActor in self.thumbsUpDetected = false }
                return
            }
            
            // Basic heuristic for Thumbs Up: Thumb tip is above all other finger tips
            // For production, you would train a custom MLModel in CreateML.
            if let observation = results.first {
                do {
                    let thumbTip = try observation.recognizedPoint(.thumbTip)
                    let indexTip = try observation.recognizedPoint(.indexTip)
                    let middleTip = try observation.recognizedPoint(.middleTip)
                    
                    if thumbTip.confidence > 0.6 && indexTip.confidence > 0.6 {
                        // In Vision, (0,0) is bottom-left. So higher Y means higher physically
                        if thumbTip.location.y > indexTip.location.y + 0.1 && thumbTip.location.y > middleTip.location.y + 0.1 {
                            print("👍 [GestureRecognition] Thumbs Up detected!")
                            Task { @MainActor in
                                self.thumbsUpDetected = true
                                // Trigger haptic and fire a like event in the UI
                                HapticFeedbackEngine.shared.triggerLike()
                            }
                        } else {
                            Task { @MainActor in self.thumbsUpDetected = false }
                        }
                    }
                } catch {
                    // Ignore missing points
                }
            }
        }
        
        request.maximumHandCount = 1
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            print("⚠️ [GestureRecognition] Vision request failed: \(error)")
        }
    }
}
