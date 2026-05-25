//
//  ImmersiveContentService.swift
//  MyChannel
//
//  Revolutionary immersive content features that transform video consumption
//  360° videos, interactive layers, holographic streaming, and spatial audio
//

import Foundation
import SwiftUI
import AVFoundation
import SceneKit
import ARKit
import CoreMotion
import Combine
import UIKit

@MainActor
class ImmersiveContentService: ObservableObject {
    static let shared = ImmersiveContentService()
    
    // MARK: - Published Properties
    @Published var is360VideoSupported = true
    @Published var isARSupported = ARWorldTrackingConfiguration.isSupported
    @Published var isVRModeEnabled = false
    @Published var currentViewingMode: ViewingMode = .standard
    @Published var interactiveElements: [InteractiveElement] = []
    @Published var spatialAudioEnabled = true
    @Published var holographicMode = false
    
    // 360° Video Properties
    @Published var sphericalVideoPlayer: AVPlayer?
    @Published var currentOrientation = simd_float4x4()
    @Published var fieldOfView: Float = 90.0
    @Published var gyroscopeEnabled = true
    
    // Interactive Elements
    @Published var activeHotspots: [VideoHotspot] = []
    @Published var branchingOptions: [BranchingOption] = []
    @Published var currentBranch: String?
    
    // AR/VR Properties
    @Published var arSession: ARSession?
    @Published var virtualEnvironments: [VirtualEnvironment] = []
    @Published var currentEnvironment: VirtualEnvironment?
    
    // Motion and Interaction
    private let motionManager = CMMotionManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMotionTracking()
        loadVirtualEnvironments()
    }
    
    // MARK: - 360° Video Support
    
    /// Initialize 360° video player with spherical projection
    func setup360Video(url: URL) async throws -> AVPlayer {
        
        let asset = AVAsset(url: url)
        
        // Verify video has 360° metadata
        let metadata = try await asset.load(.metadata)
        let is360 = metadata.contains { item in
            item.commonKey == AVMetadataKey.commonKeyIdentifier && 
            item.stringValue?.contains("spherical") == true
        }
        
        guard is360 else {
            throw ImmersiveContentError.not360Video
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        // Configure for spherical playback
        await configure360Playback(player: player)
        
        sphericalVideoPlayer = player
        return player
    }
    
    /// Create interactive 360° video experience
    func create360Experience(
        video: Video,
        hotspots: [VideoHotspot] = [],
        spatialAudio: Bool = true
    ) async throws -> Immersive360Experience {
        
        let player = try await setup360Video(url: URL(string: video.videoURL)!)
        
        // Setup spatial audio
        if spatialAudio {
            try await setupSpatialAudio(player: player)
        }
        
        // Add interactive hotspots
        activeHotspots = hotspots
        
        // Create experience
        let experience = Immersive360Experience(
            video: video,
            player: player,
            hotspots: hotspots,
            spatialAudioEnabled: spatialAudio,
            gyroscopeEnabled: gyroscopeEnabled
        )
        
        return experience
    }
    
    // MARK: - Interactive Video Layers
    
    /// Add clickable hotspots to video
    func addInteractiveHotspot(
        at time: CMTime,
        position: CGPoint,
        type: HotspotType,
        content: HotspotContent
    ) -> VideoHotspot {
        
        let hotspot = VideoHotspot(
            id: UUID().uuidString,
            time: time,
            position: position,
            type: type,
            content: content,
            isActive: false
        )
        
        activeHotspots.append(hotspot)
        return hotspot
    }
    
    /// Create branching narrative video
    func createBranchingVideo(
        mainVideo: Video,
        branches: [VideoBranch]
    ) -> BranchingVideoExperience {
        
        let experience = BranchingVideoExperience(
            mainVideo: mainVideo,
            branches: branches,
            currentBranch: nil
        )
        
        // Setup branch decision points
        for branch in branches {
            let options = branch.options.map { option in
                BranchingOption(
                    id: option.id,
                    title: option.title,
                    description: option.description,
                    targetBranch: option.targetBranch,
                    thumbnailURL: option.thumbnailURL
                )
            }
            branchingOptions.append(contentsOf: options)
        }
        
        return experience
    }
    
    // MARK: - Holographic Streaming
    
    /// Enable holographic representation of creator
    func enableHolographicMode(for creator: User) async throws {
        
        guard isARSupported else {
            throw ImmersiveContentError.arNotSupported
        }
        
        // Initialize AR session
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        session.run(configuration)
        arSession = session
        
        // Load creator's 3D avatar
        let avatar = try await load3DAvatar(for: creator)
        
        // Setup holographic projection
        try await setupHolographicProjection(avatar: avatar, session: session)
        
        holographicMode = true
    }
    
    /// Create virtual studio environment
    func createVirtualStudio(environment: VirtualEnvironment) async throws -> VirtualStudioSession {
        
        // Load 3D environment assets
        let scene = try await loadVirtualEnvironment(environment)
        
        // Setup lighting and physics
        await configureVirtualLighting(scene: scene)
        await configureVirtualPhysics(scene: scene)
        
        // Create studio session
        let session = VirtualStudioSession(
            environment: environment,
            scene: scene,
            isActive: true,
            participants: []
        )
        
        currentEnvironment = environment
        return session
    }
    
    // MARK: - Spatial Audio
    
    /// Setup 3D positional audio
    func setupSpatialAudio(player: AVPlayer) async throws {
        
        guard let playerItem = player.currentItem else {
            throw ImmersiveContentError.invalidPlayer
        }
        
        // Configure audio session for spatial audio
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
        try audioSession.setActive(true)
        
        // Setup 3D audio processing
        if let audioTracks = try? await playerItem.asset.load(.tracks).filter({ $0.mediaType == .audio }) {
            for track in audioTracks {
                try await configureSpatialAudioTrack(track)
            }
        }
        
        spatialAudioEnabled = true
    }
    
    /// Add 3D audio sources to scene
    func add3DAudioSource(
        at position: simd_float3,
        audioURL: URL,
        volume: Float = 1.0
    ) -> AudioSource3D {
        
        let audioSource = AudioSource3D(
            id: UUID().uuidString,
            position: position,
            audioURL: audioURL,
            volume: volume,
            isPlaying: false
        )
        
        // Configure 3D audio engine
        configure3DAudioEngine(source: audioSource)
        
        return audioSource
    }
    
    // MARK: - AI-Generated Backgrounds
    
    /// Generate real-time background replacement
    func enableAIBackgroundReplacement(
        style: BackgroundStyle,
        realTime: Bool = true
    ) async throws -> BackgroundReplacementSession {
        
        // Initialize background segmentation
        let segmentationModel = try await loadBackgroundSegmentationModel()
        
        // Setup real-time processing
        let session = BackgroundReplacementSession(
            style: style,
            model: segmentationModel,
            realTime: realTime,
            isActive: false
        )
        
        if realTime {
            try await startRealtimeBackgroundProcessing(session: session)
        }
        
        return session
    }
    
    /// Generate dynamic backgrounds based on content
    func generateDynamicBackground(
        for video: Video,
        mood: BackgroundMood = .neutral
    ) async throws -> [GeneratedBackground] {
        
        // Analyze video content
        let contentAnalysis = await analyzeVideoContent(video)
        
        // Generate appropriate backgrounds
        let backgrounds = await generateBackgrounds(
            analysis: contentAnalysis,
            mood: mood,
            count: 5
        )
        
        return backgrounds
    }
    
    // MARK: - Mixed Reality Features
    
    /// Blend real and virtual elements
    func createMixedRealityExperience(
        realVideo: Video,
        virtualElements: [VirtualElement]
    ) async throws -> MixedRealityExperience {
        
        guard isARSupported else {
            throw ImmersiveContentError.arNotSupported
        }
        
        // Setup AR session for mixed reality
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        
        session.run(configuration)
        
        // Create mixed reality scene
        let experience = MixedRealityExperience(
            realVideo: realVideo,
            virtualElements: virtualElements,
            arSession: session,
            isActive: true
        )
        
        return experience
    }
    
    // MARK: - Haptic Feedback Integration
    
    /// Add haptic feedback to video experiences
    func enableHapticFeedback(
        for video: Video,
        hapticEvents: [HapticEvent]
    ) -> HapticVideoExperience {
        
        let experience = HapticVideoExperience(
            video: video,
            hapticEvents: hapticEvents,
            isEnabled: true
        )
        
        // Setup haptic engine
        setupHapticEngine(events: hapticEvents)
        
        return experience
    }
    
    // MARK: - Private Methods
    
    private func setupMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            self?.updateOrientation(from: motion)
        }
    }
    
    private func updateOrientation(from motion: CMDeviceMotion) {
        let attitude = motion.attitude
        
        // Convert to 4x4 matrix for 3D rendering
        let rotationMatrix = simd_float4x4(
            simd_float4(Float(attitude.rotationMatrix.m11), Float(attitude.rotationMatrix.m12), Float(attitude.rotationMatrix.m13), 0),
            simd_float4(Float(attitude.rotationMatrix.m21), Float(attitude.rotationMatrix.m22), Float(attitude.rotationMatrix.m23), 0),
            simd_float4(Float(attitude.rotationMatrix.m31), Float(attitude.rotationMatrix.m32), Float(attitude.rotationMatrix.m33), 0),
            simd_float4(0, 0, 0, 1)
        )
        
        currentOrientation = rotationMatrix
    }
    
    private func configure360Playback(player: AVPlayer) async {
        // Configure player for 360° video playback
        // This would involve setting up the spherical projection
    }
    
    private func configureSpatialAudioTrack(_ track: AVAssetTrack) async throws {
        // Configure individual audio track for spatial audio
    }
    
    private func configure3DAudioEngine(source: AudioSource3D) {
        // Setup 3D audio engine for positional audio
    }
    
    private func load3DAvatar(for creator: User) async throws -> Avatar3D {
        // Load or generate 3D avatar for creator
        return Avatar3D(creatorId: creator.id, modelURL: URL(string: "https://example.com/avatar.usdz")!)
    }
    
    private func setupHolographicProjection(avatar: Avatar3D, session: ARSession) async throws {
        // Setup holographic projection in AR space
    }
    
    private func loadVirtualEnvironment(_ environment: VirtualEnvironment) async throws -> SCNScene {
        // Load 3D scene for virtual environment
        return SCNScene()
    }
    
    private func configureVirtualLighting(scene: SCNScene) async {
        // Setup realistic lighting for virtual environment
    }
    
    private func configureVirtualPhysics(scene: SCNScene) async {
        // Setup physics simulation for virtual environment
    }
    
    private func loadBackgroundSegmentationModel() async throws -> BackgroundSegmentationModel {
        // Load ML model for background segmentation
        return BackgroundSegmentationModel()
    }
    
    private func startRealtimeBackgroundProcessing(session: BackgroundReplacementSession) async throws {
        // Start real-time background replacement processing
    }
    
    private func analyzeVideoContent(_ video: Video) async -> ImmersiveVideoContentAnalysis {
        // Analyze video content for background generation
        return ImmersiveVideoContentAnalysis(
            videoId: video.id,
            is360Video: false,
            hasDepthData: false,
            spatialAudioEnabled: spatialAudioEnabled,
            hotspotsDetected: activeHotspots.count,
            interactiveBranches: branchingOptions.count,
            arCompatibilityScore: isARSupported ? 0.8 : 0.0,
            recommendedViewMode: currentViewingMode.rawValue
        )
    }
    
    private func generateBackgrounds(analysis: ImmersiveVideoContentAnalysis, mood: BackgroundMood, count: Int) async -> [GeneratedBackground] {
        // Generate AI backgrounds based on content analysis
        return []
    }
    
    private func setupHapticEngine(events: [HapticEvent]) {
        // Setup haptic feedback engine
    }
    
    private func loadVirtualEnvironments() {
        virtualEnvironments = [
            VirtualEnvironment(
                id: "studio_modern",
                name: "Modern Studio",
                description: "Clean, professional studio environment",
                thumbnailURL: "https://example.com/studio_modern.jpg",
                sceneURL: URL(string: "https://example.com/studio_modern.usdz")!
            ),
            VirtualEnvironment(
                id: "nature_forest",
                name: "Forest Retreat",
                description: "Peaceful forest environment",
                thumbnailURL: "https://example.com/forest.jpg",
                sceneURL: URL(string: "https://example.com/forest.usdz")!
            ),
            VirtualEnvironment(
                id: "space_station",
                name: "Space Station",
                description: "Futuristic space environment",
                thumbnailURL: "https://example.com/space.jpg",
                sceneURL: URL(string: "https://example.com/space.usdz")!
            )
        ]
    }
}

// MARK: - Supporting Models

enum ViewingMode: String, CaseIterable {
    case standard = "Standard"
    case vr360 = "360° VR"
    case ar = "Augmented Reality"
    case holographic = "Holographic"
    case mixedReality = "Mixed Reality"
}

enum HotspotType: String, Codable {
    case info, link, product, chapter, poll, quiz
}

enum BackgroundStyle: String, CaseIterable, Codable {
    case blur, replace, greenScreen, artistic, dynamic
}

enum BackgroundMood: String, CaseIterable, Codable {
    case neutral, energetic, calm, professional, creative
}

struct VideoHotspot: Identifiable, Codable {
    let id: String
    let time: CMTime
    let position: CGPoint
    let type: HotspotType
    let content: HotspotContent
    var isActive: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, time, position, type, content, isActive
    }
    
    init(id: String, time: CMTime, position: CGPoint, type: HotspotType, content: HotspotContent, isActive: Bool) {
        self.id = id
        self.time = time
        self.position = position
        self.type = type
        self.content = content
        self.isActive = isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let seconds = try container.decodeIfPresent(Double.self, forKey: .time) ?? 0
        time = CMTime(seconds: seconds, preferredTimescale: 600)
        position = try container.decode(CGPoint.self, forKey: .position)
        type = try container.decode(HotspotType.self, forKey: .type)
        content = try container.decode(HotspotContent.self, forKey: .content)
        isActive = try container.decode(Bool.self, forKey: .isActive)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(time.seconds, forKey: .time)
        try container.encode(position, forKey: .position)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(isActive, forKey: .isActive)
    }
}

struct HotspotContent: Codable {
    let title: String
    let description: String?
    let url: String?
    let imageURL: String?
    let action: HotspotAction?
}

enum HotspotAction: String, Codable {
    case openURL, showInfo, buyProduct, jumpToTime, showPoll
}

struct InteractiveElement: Identifiable, Codable {
    let id = UUID()
    let type: ElementType
    let position: CGPoint
    let size: CGSize
    let content: String
    let isVisible: Bool
    
    enum ElementType: String, Codable {
        case button, text, image, video, poll, quiz
    }
}

struct BranchingOption: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let targetBranch: String
    let thumbnailURL: String?
}

struct VideoBranch: Identifiable, Codable {
    let id: String
    let video: Video
    let decisionPoint: CMTime
    let options: [BranchOption]
    
    struct BranchOption: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let targetBranch: String
        let thumbnailURL: String?
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, video, decisionPoint, options
    }
    
    init(id: String, video: Video, decisionPoint: CMTime, options: [BranchOption]) {
        self.id = id
        self.video = video
        self.decisionPoint = decisionPoint
        self.options = options
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        video = try container.decode(Video.self, forKey: .video)
        let seconds = try container.decodeIfPresent(Double.self, forKey: .decisionPoint) ?? 0
        decisionPoint = CMTime(seconds: seconds, preferredTimescale: 600)
        options = try container.decode([BranchOption].self, forKey: .options)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(video, forKey: .video)
        try container.encode(decisionPoint.seconds, forKey: .decisionPoint)
        try container.encode(options, forKey: .options)
    }
}

struct VirtualEnvironment: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let thumbnailURL: String
    let sceneURL: URL
}

struct AudioSource3D: Identifiable {
    let id: String
    let position: simd_float3
    let audioURL: URL
    let volume: Float
    var isPlaying: Bool
}

struct Avatar3D: Identifiable {
    let id = UUID()
    let creatorId: String
    let modelURL: URL
}

struct HapticEvent: Identifiable, Codable {
    let id = UUID()
    let time: CMTime
    let intensity: Float
    let duration: TimeInterval
    let pattern: HapticPattern
    
    enum HapticPattern: String, Codable {
        case impact, notification, selection, custom
    }
    
    private enum CodingKeys: String, CodingKey {
        case time, intensity, duration, pattern
    }
    
    init(time: CMTime, intensity: Float, duration: TimeInterval, pattern: HapticPattern) {
        self.time = time
        self.intensity = intensity
        self.duration = duration
        self.pattern = pattern
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seconds = try container.decodeIfPresent(Double.self, forKey: .time) ?? 0
        time = CMTime(seconds: seconds, preferredTimescale: 600)
        intensity = try container.decode(Float.self, forKey: .intensity)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        pattern = try container.decode(HapticPattern.self, forKey: .pattern)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time.seconds, forKey: .time)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(duration, forKey: .duration)
        try container.encode(pattern, forKey: .pattern)
    }
}

struct VirtualElement: Identifiable, Codable {
    let id = UUID()
    let type: ElementType
    let position: simd_float3
    let scale: simd_float3
    let modelURL: URL?
    
    enum ElementType: String, Codable {
        case object, text, effect, particle
    }
}

struct GeneratedBackground: Identifiable, Codable {
    let id: String
    let style: BackgroundStyle
    let imageURL: String
    let videoURL: String?
    let mood: BackgroundMood
    
    init(style: BackgroundStyle, imageURL: String, videoURL: String? = nil, mood: BackgroundMood) {
        self.id = UUID().uuidString
        self.style = style
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.mood = mood
    }
    
    // Codable implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        style = try container.decode(BackgroundStyle.self, forKey: .style)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        mood = try container.decode(BackgroundMood.self, forKey: .mood)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(style, forKey: .style)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(videoURL, forKey: .videoURL)
        try container.encode(mood, forKey: .mood)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, style, imageURL, videoURL, mood
    }
}

// MARK: - Experience Classes

class Immersive360Experience: ObservableObject {
    let video: Video
    let player: AVPlayer
    let hotspots: [VideoHotspot]
    let spatialAudioEnabled: Bool
    let gyroscopeEnabled: Bool
    
    init(video: Video, player: AVPlayer, hotspots: [VideoHotspot], spatialAudioEnabled: Bool, gyroscopeEnabled: Bool) {
        self.video = video
        self.player = player
        self.hotspots = hotspots
        self.spatialAudioEnabled = spatialAudioEnabled
        self.gyroscopeEnabled = gyroscopeEnabled
    }
}

class BranchingVideoExperience: ObservableObject {
    let mainVideo: Video
    let branches: [VideoBranch]
    @Published var currentBranch: String?
    
    init(mainVideo: Video, branches: [VideoBranch], currentBranch: String?) {
        self.mainVideo = mainVideo
        self.branches = branches
        self.currentBranch = currentBranch
    }
}

class VirtualStudioSession: ObservableObject {
    let environment: VirtualEnvironment
    let scene: SCNScene
    @Published var isActive: Bool
    @Published var participants: [User]
    
    init(environment: VirtualEnvironment, scene: SCNScene, isActive: Bool, participants: [User]) {
        self.environment = environment
        self.scene = scene
        self.isActive = isActive
        self.participants = participants
    }
}

class BackgroundReplacementSession: ObservableObject {
    let style: BackgroundStyle
    let model: BackgroundSegmentationModel
    let realTime: Bool
    @Published var isActive: Bool
    
    init(style: BackgroundStyle, model: BackgroundSegmentationModel, realTime: Bool, isActive: Bool = false) {
        self.style = style
        self.model = model
        self.realTime = realTime
        self.isActive = isActive
    }
}

class MixedRealityExperience: ObservableObject {
    let realVideo: Video
    let virtualElements: [VirtualElement]
    let arSession: ARSession
    @Published var isActive: Bool
    
    init(realVideo: Video, virtualElements: [VirtualElement], arSession: ARSession, isActive: Bool) {
        self.realVideo = realVideo
        self.virtualElements = virtualElements
        self.arSession = arSession
        self.isActive = isActive
    }
}

class HapticVideoExperience: ObservableObject {
    let video: Video
    let hapticEvents: [HapticEvent]
    @Published var isEnabled: Bool
    
    init(video: Video, hapticEvents: [HapticEvent], isEnabled: Bool) {
        self.video = video
        self.hapticEvents = hapticEvents
        self.isEnabled = isEnabled
    }
}

// MARK: - AI Models

class BackgroundSegmentationModel {
    private var isModelLoaded = false
    
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        struct Req: Encodable { let task: String }
        struct Raw: Decodable { let modelLoaded: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict", body: Req(task: "load_background_segmentation_model"), timeout: 30)
        isModelLoaded = r.modelLoaded ?? true
    }
    
    func segmentBackground(from image: CGImage) async throws -> CGImage? {
        guard isModelLoaded else {
            try? await loadModel()
            guard isModelLoaded else { return nil }
            return try await segmentBackground(from: image)
        }
        struct Req: Encodable { let task: String; let imageData: String }
        struct Raw: Decodable { let maskData: String? }
        let uiImage = UIImage(cgImage: image)
        let base64 = uiImage.pngData()?.base64EncodedString() ?? ""
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "segment_background", imageData: base64), timeout: 30)
        guard let maskData = r.maskData, let data = Data(base64Encoded: maskData) else { return nil }
        return UIImage(data: data)?.cgImage
    }
}

struct ImmersiveVideoContentAnalysis {
    let videoId: String
    let is360Video: Bool
    let hasDepthData: Bool
    let spatialAudioEnabled: Bool
    let hotspotsDetected: Int
    let interactiveBranches: Int
    let arCompatibilityScore: Double
    let recommendedViewMode: String
}

// MARK: - Errors

enum ImmersiveContentError: LocalizedError {
    case not360Video
    case arNotSupported
    case invalidPlayer
    case modelLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .not360Video:
            return "Video is not in 360° format"
        case .arNotSupported:
            return "AR is not supported on this device"
        case .invalidPlayer:
            return "Invalid video player"
        case .modelLoadFailed:
            return "Failed to load 3D model"
        }
    }
}
