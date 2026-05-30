import Foundation
import AVFoundation

/// Phase 43: Spatial Audio 3D Positioning UI
/// Manages AVAudioEnvironmentNode for true 3D spatialization.
@MainActor
final class SpatialAudioEngine: ObservableObject {
    static let shared = SpatialAudioEngine()
    
    private let engine = AVAudioEngine()
    private let environmentNode = AVAudioEnvironmentNode()
    private let playerNode = AVAudioPlayerNode()
    
    @Published var sourcePosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(environmentNode)
        engine.attach(playerNode)
        
        let format = engine.outputNode.outputFormat(forBus: 0)
        
        engine.connect(playerNode, to: environmentNode, format: format)
        engine.connect(environmentNode, to: engine.outputNode, format: format)
        
        // Listener sits at the origin looking down the negative Z axis
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        do {
            try engine.start()
        } catch {
            print("⚠️ [SpatialAudio] Failed to start engine: \(error)")
        }
    }
    
    /// Update the 3D position of the audio source
    func updateSourcePosition(x: Float, y: Float, z: Float) {
        sourcePosition = SIMD3<Float>(x, y, z)
        playerNode.position = AVAudio3DPoint(x: x, y: y, z: z)
        print("🔊 [SpatialAudio] Updated position to \(x), \(y), \(z)")
    }
    
    func playFile(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            playerNode.scheduleFile(file, at: nil)
            playerNode.play()
        } catch {
            print("⚠️ [SpatialAudio] Failed to read audio file: \(error)")
        }
    }
    
    func stop() {
        playerNode.stop()
    }
}
