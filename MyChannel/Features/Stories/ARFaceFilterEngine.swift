//
//  ARFaceFilterEngine.swift
//  MyChannel
//
//  🎭 AR FACE FILTER ENGINE
//  Real-time face tracking with AR effects (like Snapchat/Instagram)
//
//  ⚠️ DISABLED by default to exclude TrueDepth APIs from the binary
//  (App Store Guideline 2.5.1). To enable, add ENABLE_AR_FACE_FILTERS
//  to your Swift Active Compilation Conditions in Build Settings.
//

import SwiftUI
#if canImport(ARKit) && ENABLE_AR_FACE_FILTERS
import ARKit
import SceneKit
#endif

// MARK: - Face Filter Model (always available)
struct FaceFilter: Identifiable, Codable {
    let id: String
    let name: String
    let category: FilterCategory
    let iconName: String
    
    enum FilterCategory: String, Codable {
        case accessory
        case animal
        case beauty
        case effect
    }
}

#if canImport(ARKit) && ENABLE_AR_FACE_FILTERS

@MainActor
class ARFaceFilterEngine: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var isFaceDetected = false
    @Published var selectedFilter: FaceFilter?
    @Published var faceBounds: CGRect = .zero
    @Published var landmarks: [String: CGPoint] = [:]
    
    // AR Session
    nonisolated(unsafe) private var arSession: ARSession?
    private var sceneView: ARSCNView?
    
    // Face tracking
    private var faceNode: SCNNode?
    nonisolated(unsafe) private var isTracking = false
    
    // Available filters
    let availableFilters: [FaceFilter] = [
        FaceFilter(id: "glasses", name: "Cool Glasses", category: .accessory, iconName: "eyeglasses"),
        FaceFilter(id: "crown", name: "Crown", category: .accessory, iconName: "crown"),
        FaceFilter(id: "cat", name: "Cat Ears", category: .animal, iconName: "cat"),
        FaceFilter(id: "dog", name: "Dog Ears", category: .animal, iconName: "dog"),
        FaceFilter(id: "bunny", name: "Bunny", category: .animal, iconName: "hare"),
        FaceFilter(id: "makeup", name: "Makeup", category: .beauty, iconName: "paintbrush"),
        FaceFilter(id: "rainbow", name: "Rainbow", category: .effect, iconName: "rainbow"),
        FaceFilter(id: "fire", name: "Fire", category: .effect, iconName: "flame"),
        FaceFilter(id: "stars", name: "Stars", category: .effect, iconName: "star"),
        FaceFilter(id: "mask", name: "Mask", category: .effect, iconName: "theatermasks")
    ]
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupARSession()
    }
    
    // MARK: - AR Session Setup
    private func setupARSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ Face tracking not supported on this device")
            return
        }
        
        arSession = ARSession()
        arSession?.delegate = self
    }
    
    func startTracking(in view: ARSCNView) {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        sceneView = view
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true
        
        print("✅ Face tracking started")
    }
    
    nonisolated func stopTracking() {
        arSession?.pause()
        isTracking = false
        
        // Update @Published property on MainActor
        Task { @MainActor in
            self.isFaceDetected = false
        }
        
        print("🛑 Face tracking stopped")
    }
    
    // MARK: - Filter Management
    func applyFilter(_ filter: FaceFilter) {
        selectedFilter = filter
        
        // Remove existing filter
        faceNode?.childNodes.forEach { $0.removeFromParentNode() }
        
        // Apply new filter based on type
        switch filter.category {
        case .accessory:
            applyAccessoryFilter(filter)
        case .animal:
            applyAnimalFilter(filter)
        case .beauty:
            applyBeautyFilter(filter)
        case .effect:
            applyEffectFilter(filter)
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func removeFilter() {
        selectedFilter = nil
        faceNode?.childNodes.forEach { $0.removeFromParentNode() }
        HapticManager.shared.impact(style: .light)
    }
    
    // MARK: - Filter Applications
    private func applyAccessoryFilter(_ filter: FaceFilter) {
        guard let faceNode = faceNode else { return }
        
        switch filter.id {
        case "glasses":
            // Add glasses geometry at eye position
            let glassesNode = createGlassesNode()
            faceNode.addChildNode(glassesNode)
            
        case "crown":
            // Add crown at top of head
            let crownNode = createCrownNode()
            faceNode.addChildNode(crownNode)
            
        default:
            break
        }
    }
    
    private func applyAnimalFilter(_ filter: FaceFilter) {
        guard let faceNode = faceNode else { return }
        
        switch filter.id {
        case "cat":
            let earsNode = createCatEarsNode()
            faceNode.addChildNode(earsNode)
            
        case "dog":
            let earsNode = createDogEarsNode()
            faceNode.addChildNode(earsNode)
            
        case "bunny":
            let earsNode = createBunnyEarsNode()
            faceNode.addChildNode(earsNode)
            
        default:
            break
        }
    }
    
    private func applyBeautyFilter(_ filter: FaceFilter) {
        // Apply beauty enhancements (smooth skin, brighten eyes, etc.)
        // This would use Core Image filters on the face texture
    }
    
    private func applyEffectFilter(_ filter: FaceFilter) {
        guard let faceNode = faceNode else { return }
        
        switch filter.id {
        case "rainbow":
            let rainbowNode = createRainbowNode()
            faceNode.addChildNode(rainbowNode)
            
        case "fire":
            let fireNode = createFireParticlesNode()
            faceNode.addChildNode(fireNode)
            
        case "stars":
            let starsNode = createStarsParticlesNode()
            faceNode.addChildNode(starsNode)
            
        default:
            break
        }
    }
    
    // MARK: - Node Creation (3D Objects)
    private func createGlassesNode() -> SCNNode {
        let glassesNode = SCNNode()
        
        // Left lens
        let leftLens = SCNBox(width: 0.04, height: 0.025, length: 0.002, chamferRadius: 0.002)
        leftLens.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
        let leftLensNode = SCNNode(geometry: leftLens)
        leftLensNode.position = SCNVector3(-0.03, 0, 0.05)
        glassesNode.addChildNode(leftLensNode)
        
        // Right lens
        let rightLens = SCNBox(width: 0.04, height: 0.025, length: 0.002, chamferRadius: 0.002)
        rightLens.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
        let rightLensNode = SCNNode(geometry: rightLens)
        rightLensNode.position = SCNVector3(0.03, 0, 0.05)
        glassesNode.addChildNode(rightLensNode)
        
        // Bridge
        let bridge = SCNBox(width: 0.02, height: 0.005, length: 0.002, chamferRadius: 0.001)
        bridge.firstMaterial?.diffuse.contents = UIColor.black
        let bridgeNode = SCNNode(geometry: bridge)
        bridgeNode.position = SCNVector3(0, 0, 0.05)
        glassesNode.addChildNode(bridgeNode)
        
        return glassesNode
    }
    
    private func createCrownNode() -> SCNNode {
        let crownNode = SCNNode()
        
        // Crown geometry
        let crown = SCNCone(topRadius: 0.05, bottomRadius: 0.06, height: 0.04)
        crown.firstMaterial?.diffuse.contents = UIColor.systemYellow
        crown.firstMaterial?.metalness.contents = 0.8
        crown.firstMaterial?.roughness.contents = 0.2
        
        let crownGeometryNode = SCNNode(geometry: crown)
        crownGeometryNode.position = SCNVector3(0, 0.12, 0)
        crownNode.addChildNode(crownGeometryNode)
        
        return crownNode
    }
    
    private func createCatEarsNode() -> SCNNode {
        let earsNode = SCNNode()
        
        // Left ear
        let leftEar = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.04)
        leftEar.firstMaterial?.diffuse.contents = UIColor.systemPink
        let leftEarNode = SCNNode(geometry: leftEar)
        leftEarNode.position = SCNVector3(-0.05, 0.1, -0.02)
        leftEarNode.eulerAngles.z = 0.3
        earsNode.addChildNode(leftEarNode)
        
        // Right ear
        let rightEar = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.04)
        rightEar.firstMaterial?.diffuse.contents = UIColor.systemPink
        let rightEarNode = SCNNode(geometry: rightEar)
        rightEarNode.position = SCNVector3(0.05, 0.1, -0.02)
        rightEarNode.eulerAngles.z = -0.3
        earsNode.addChildNode(rightEarNode)
        
        return earsNode
    }
    
    private func createDogEarsNode() -> SCNNode {
        let earsNode = SCNNode()
        
        // Left ear (floppy)
        let leftEar = SCNBox(width: 0.03, height: 0.06, length: 0.01, chamferRadius: 0.005)
        leftEar.firstMaterial?.diffuse.contents = UIColor.brown
        let leftEarNode = SCNNode(geometry: leftEar)
        leftEarNode.position = SCNVector3(-0.05, 0.08, -0.02)
        leftEarNode.eulerAngles.z = 0.5
        earsNode.addChildNode(leftEarNode)
        
        // Right ear (floppy)
        let rightEar = SCNBox(width: 0.03, height: 0.06, length: 0.01, chamferRadius: 0.005)
        rightEar.firstMaterial?.diffuse.contents = UIColor.brown
        let rightEarNode = SCNNode(geometry: rightEar)
        rightEarNode.position = SCNVector3(0.05, 0.08, -0.02)
        rightEarNode.eulerAngles.z = -0.5
        earsNode.addChildNode(rightEarNode)
        
        return earsNode
    }
    
    private func createBunnyEarsNode() -> SCNNode {
        let earsNode = SCNNode()
        
        // Left ear (long)
        let leftEar = SCNCapsule(capRadius: 0.01, height: 0.08)
        leftEar.firstMaterial?.diffuse.contents = UIColor.white
        let leftEarNode = SCNNode(geometry: leftEar)
        leftEarNode.position = SCNVector3(-0.04, 0.12, -0.02)
        leftEarNode.eulerAngles.z = 0.2
        earsNode.addChildNode(leftEarNode)
        
        // Right ear (long)
        let rightEar = SCNCapsule(capRadius: 0.01, height: 0.08)
        rightEar.firstMaterial?.diffuse.contents = UIColor.white
        let rightEarNode = SCNNode(geometry: rightEar)
        rightEarNode.position = SCNVector3(0.04, 0.12, -0.02)
        rightEarNode.eulerAngles.z = -0.2
        earsNode.addChildNode(rightEarNode)
        
        return earsNode
    }
    
    private func createRainbowNode() -> SCNNode {
        let rainbowNode = SCNNode()
        
        let colors: [UIColor] = [.red, .orange, .yellow, .green, .blue, .purple]
        
        for (index, color) in colors.enumerated() {
            let arc = SCNTorus(ringRadius: 0.08 + CGFloat(index) * 0.005, pipeRadius: 0.003)
            arc.firstMaterial?.diffuse.contents = color
            
            let arcNode = SCNNode(geometry: arc)
            arcNode.position = SCNVector3(0, 0.1, 0)
            arcNode.eulerAngles.x = Float.pi / 2
            
            rainbowNode.addChildNode(arcNode)
        }
        
        return rainbowNode
    }
    
    private func createFireParticlesNode() -> SCNNode {
        let particleNode = SCNNode()
        
        let particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 50
        particleSystem.particleLifeSpan = 1.0
        particleSystem.particleSize = 0.01
        particleSystem.particleColor = .orange
        particleSystem.blendMode = .additive
        particleSystem.emissionDuration = 0
        particleSystem.emitterShape = SCNSphere(radius: 0.02)
        particleSystem.particleVelocity = 0.1
        particleSystem.particleVelocityVariation = 0.05
        
        particleNode.addParticleSystem(particleSystem)
        particleNode.position = SCNVector3(0, 0.1, 0)
        
        return particleNode
    }
    
    private func createStarsParticlesNode() -> SCNNode {
        let particleNode = SCNNode()
        
        let particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 20
        particleSystem.particleLifeSpan = 2.0
        particleSystem.particleSize = 0.008
        particleSystem.particleColor = .yellow
        particleSystem.blendMode = .additive
        particleSystem.emissionDuration = 0
        particleSystem.emitterShape = SCNSphere(radius: 0.08)
        particleSystem.particleVelocity = 0
        
        particleNode.addParticleSystem(particleSystem)
        particleNode.position = SCNVector3(0, 0, 0)
        
        return particleNode
    }
    
    deinit {
        // stopTracking is now nonisolated, so it can be called directly
        stopTracking()
    }
}

// MARK: - ARSessionDelegate
extension ARFaceFilterEngine: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first as? ARFaceAnchor else { return }
        
        Task { @MainActor in
            isFaceDetected = true
            
            // Update face node
            if faceNode == nil {
                faceNode = SCNNode()
                sceneView?.scene.rootNode.addChildNode(faceNode!)
                
                // Reapply current filter if any
                if let filter = selectedFilter {
                    applyFilter(filter)
                }
            }
            
            // Update face node transform
            faceNode?.simdTransform = faceAnchor.transform
            
            // Extract facial landmarks
            updateLandmarks(from: faceAnchor)
        }
    }
    
    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            if anchors.contains(where: { $0 is ARFaceAnchor }) {
                isFaceDetected = false
                faceNode?.removeFromParentNode()
                faceNode = nil
            }
        }
    }
}

// MARK: - Facial Landmarks
extension ARFaceFilterEngine {
    private func updateLandmarks(from faceAnchor: ARFaceAnchor) {
        // Extract key facial landmarks
        landmarks = [:]
        
        // Use face transform and geometry for landmarks
        let transform = faceAnchor.transform
        let geometry = faceAnchor.geometry
        
        // Eyes (using blend shapes for eye tracking)
        if let leftEyeBlink = faceAnchor.blendShapes[.eyeBlinkLeft] as? Float {
            let leftEyePos = simd_make_float3(transform.columns.3) + simd_float3(-0.03, 0.02, 0)
            landmarks["leftEye"] = convertToScreenPoint(simd_make_float4(leftEyePos, 1.0))
        }
        
        if let rightEyeBlink = faceAnchor.blendShapes[.eyeBlinkRight] as? Float {
            let rightEyePos = simd_make_float3(transform.columns.3) + simd_float3(0.03, 0.02, 0)
            landmarks["rightEye"] = convertToScreenPoint(simd_make_float4(rightEyePos, 1.0))
        }
        
        // Nose
        // Mouth
        // Eyebrows
        // etc.
    }
    
    private func convertToScreenPoint(_ worldPoint: simd_float4) -> CGPoint {
        // Convert 3D world point to 2D screen coordinates
        // This would use the camera's projection matrix
        return CGPoint(x: 0, y: 0) // Placeholder
    }
}

#else

// MARK: - Stub when AR Face Filters are disabled (TrueDepth excluded)
@MainActor
class ARFaceFilterEngine: ObservableObject {
    @Published var isFaceDetected = false
    @Published var selectedFilter: FaceFilter?
    @Published var faceBounds: CGRect = .zero
    @Published var landmarks: [String: CGPoint] = [:]
    let availableFilters: [FaceFilter] = []
    
    func applyFilter(_ filter: FaceFilter) {}
    func removeFilter() {}
}

#endif
