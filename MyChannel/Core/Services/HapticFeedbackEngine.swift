import Foundation
import CoreHaptics
import AVFoundation

/// Phase 66: Haptic Feedback Engine
/// Uses CoreHaptics to generate tactile bumps synced to audio volume peaks.
@MainActor
final class HapticFeedbackEngine: ObservableObject {
    static let shared = HapticFeedbackEngine()
    
    private var hapticEngine: CHHapticEngine?
    private var engineSupportsHaptics: Bool = false
    
    private init() {
        setupHaptics()
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("📳 [HapticEngine] Device does not support CoreHaptics.")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            engineSupportsHaptics = true
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                print("📳 [HapticEngine] Resetting haptic engine.")
                do { try self?.hapticEngine?.start() }
                catch { print("Failed to restart engine: \(error)") }
            }
            
            // Handle engine stop
            hapticEngine?.stoppedHandler = { reason in
                print("📳 [HapticEngine] Engine stopped. Reason: \(reason.rawValue)")
            }
            
            try hapticEngine?.start()
            
        } catch {
            print("⚠️ [HapticEngine] Failed to create haptic engine: \(error)")
        }
    }
    
    /// Called when the waveform generator detects a volume peak
    func playBump(intensity: Float, sharpness: Float) {
        guard engineSupportsHaptics, let engine = hapticEngine else { return }
        
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, min(1, intensity)))
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, min(1, sharpness)))
        
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("⚠️ [HapticEngine] Failed to play haptic bump: \(error)")
        }
    }
    
    func triggerLike() {
        playBump(intensity: 1.0, sharpness: 1.0)
    }
}
