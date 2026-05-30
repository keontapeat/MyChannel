import Foundation
import CoreMotion
import Combine
import CoreGraphics

/// Phase 84: CoreMotion Viewpoint Parallax
/// Uses CMMotionManager to track device rotation and provides offset values for UI tilting effects (e.g., Apple TV style posters).
@MainActor
final class MotionParallaxEngine: ObservableObject {
    static let shared = MotionParallaxEngine()
    
    private let motionManager = CMMotionManager()
    
    @Published var pitchOffset: CGFloat = 0.0 // X-axis tilt
    @Published var rollOffset: CGFloat = 0.0 // Y-axis tilt
    
    private let maxOffset: CGFloat = 20.0
    private let smoothingFactor: CGFloat = 0.1
    
    private init() {
        startTracking()
    }
    
    private func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("📱 [MotionParallax] Device motion not available.")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Extract attitude (pitch and roll)
            let pitch = CGFloat(motion.attitude.pitch)
            let roll = CGFloat(motion.attitude.roll)
            
            // Map to offset bounds [-maxOffset, maxOffset]
            // We use simple multipliers to make the effect noticeable but clamped.
            let targetPitch = max(-self.maxOffset, min(self.maxOffset, pitch * 30))
            let targetRoll = max(-self.maxOffset, min(self.maxOffset, roll * 30))
            
            // Apply smoothing (low-pass filter)
            self.pitchOffset += (targetPitch - self.pitchOffset) * self.smoothingFactor
            self.rollOffset += (targetRoll - self.rollOffset) * self.smoothingFactor
        }
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        pitchOffset = 0
        rollOffset = 0
    }
}
