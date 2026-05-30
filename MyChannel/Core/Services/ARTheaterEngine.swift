import Foundation
import ARKit
import RealityKit
import AVFoundation

/// Phase 92: ARKit Immersive Theater Mode
/// Spawns a virtual TV screen using RealityKit and maps an AVPlayer onto it.
@MainActor
final class ARTheaterEngine: NSObject, ObservableObject {
    static let shared = ARTheaterEngine()
    
    @Published var isTheaterActive = false
    private var arView: ARView?
    private weak var player: AVPlayer?
    
    private override init() {
        super.init()
    }
    
    func attach(player: AVPlayer) {
        self.player = player
    }
    
    func startTheater(in view: ARView) {
        guard let player = player else { return }
        
        self.arView = view
        self.isTheaterActive = true
        
        // Configure ARKit for horizontal plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.delegate = self
        view.session.run(config)
        
        // Create the Video Material
        let videoMaterial = VideoMaterial(avPlayer: player)
        
        // Create a 16:9 Mesh (e.g. 2 meters wide x 1.125 meters high)
        let mesh = MeshResource.generatePlane(width: 2.0, depth: 1.125)
        
        // Create the Model Entity
        let tvEntity = ModelEntity(mesh: mesh, materials: [videoMaterial])
        
        // Create an Anchor at 2 meters in front of the camera
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.0))
        
        // Tilt the screen up slightly (RealityKit planes default to lying flat on the floor)
        tvEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        
        anchor.addChild(tvEntity)
        view.scene.addAnchor(anchor)
        
        print("🥽 [ARTheater] Spawning 200-inch virtual TV in RealityKit.")
    }
    
    func stopTheater() {
        self.isTheaterActive = false
        arView?.session.pause()
        arView?.scene.anchors.removeAll()
        arView = nil
        print("🥽 [ARTheater] Closed AR Theater.")
    }
}

extension ARTheaterEngine: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        print("⚠️ [ARTheater] ARSession failed: \(error)")
    }
}
