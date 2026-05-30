import SwiftUI
import SceneKit
import AVFoundation
import CoreMotion

/// Phase 34: 360° VR Video Rendering Engine
/// Projects an AVPlayer onto the inside of a sphere for VR content, with CoreMotion gyro tracking.
struct VRVideoRenderer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = SCNScene()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true // Allows touch panning if gyro is off
        
        // 1. Create a spherical geometry
        let sphere = SCNSphere(radius: 100)
        sphere.segmentCount = 96
        
        // 2. Project video onto sphere material
        let videoMaterial = SCNMaterial()
        videoMaterial.diffuse.contents = player
        videoMaterial.isDoubleSided = true // Important for viewing from inside
        sphere.materials = [videoMaterial]
        
        let sphereNode = SCNNode(geometry: sphere)
        // Flip the sphere inside out (x scale to -1) so the video renders correctly on the interior
        sphereNode.scale = SCNVector3(-1, 1, 1)
        scnView.scene?.rootNode.addChildNode(sphereNode)
        
        // 3. Setup Camera inside the sphere
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0)
        scnView.scene?.rootNode.addChildNode(cameraNode)
        
        // 4. Start CoreMotion tracking
        context.coordinator.startMotionUpdates(cameraNode: cameraNode)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Handle player updates if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        let motionManager = CMMotionManager()
        
        func startMotionUpdates(cameraNode: SCNNode) {
            guard motionManager.isDeviceMotionAvailable else { return }
            
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion = motion else { return }
                
                // Map device attitude to camera orientation
                let attitude = motion.attitude
                cameraNode.eulerAngles = SCNVector3(
                    Float(attitude.roll) - .pi/2,
                    Float(attitude.yaw),
                    Float(-attitude.pitch)
                )
            }
        }
        
        deinit {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}
