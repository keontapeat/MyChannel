//
//  UltimateStoryViewModel.swift
//  MyChannel
//
//  🔥 VIEW MODEL FOR ULTIMATE STORY CREATOR
//

import SwiftUI
import AVFoundation
import Photos
import Combine

// MARK: - Ultimate Story ViewModel
@MainActor
class UltimateStoryViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var currentMedia: CapturedMedia?
    @Published var editableElements: [EditableElement] = []
    @Published var selectedEffect: AREffect?
    @Published var selectedTool: EditingTool = .none
    @Published var recordingMode: RecordingMode = .normal
    @Published var recordingSpeed: Double = 1.0
    @Published var showGrid: Bool = false
    
    // Processing state
    @Published var isProcessing: Bool = false
    @Published var processingMessage: String = ""
    @Published var processingProgress: Double = 0.0
    
    // Text editing
    @Published var currentText: String = ""
    @Published var textColor: Color = .white
    @Published var textFont: StoryFont = .bold
    @Published var textAlignment: TextAlignment = .center
    @Published var textBackgroundStyle: TextBackgroundStyle = .none
    
    // Drawing
    @Published var drawingColor: Color = .white
    @Published var drawingLineWidth: CGFloat = 5.0
    @Published var drawingPaths: [DrawingPath] = []
    
    // Music
    @Published var selectedMusic: MusicTrack?
    @Published var musicVolume: Double = 1.0
    
    // Templates
    @Published var appliedTemplate: StoryTemplate?
    
    // AI Tools
    @Published var aiEnhanceEnabled: Bool = false
    @Published var beautyFilterIntensity: Double = 0.0
    @Published var autoColorCorrect: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let storyService = StoryService.shared
    
    // MARK: - Computed Properties
    var hasMedia: Bool {
        currentMedia != nil
    }
    
    // MARK: - Media Management
    func setMedia(_ media: CapturedMedia) async {
        currentMedia = media
        
        // Apply AI enhancements if enabled
        if aiEnhanceEnabled {
            await applyAIEnhancements()
        }
    }
    
    func clearMedia() {
        currentMedia = nil
        editableElements.removeAll()
        drawingPaths.removeAll()
        selectedMusic = nil
        appliedTemplate = nil
    }
    
    func openPhotoPicker() {
        // Trigger photo picker
    }
    
    // MARK: - Editable Elements
    func addTextElement() {
        let element = EditableElement(
            type: .text(currentText.isEmpty ? "Tap to edit" : currentText),
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1.0,
            rotation: 0,
            color: textColor,
            font: textFont,
            backgroundStyle: textBackgroundStyle
        )
        editableElements.append(element)
        HapticManager.shared.impact(style: .medium)
    }
    
    func addStickerElement(_ sticker: Sticker) {
        let element = EditableElement(
            type: .sticker(sticker),
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1.0,
            rotation: 0
        )
        editableElements.append(element)
        HapticManager.shared.impact(style: .medium)
    }
    
    func updateElement(_ id: UUID, offset: CGSize) {
        if let index = editableElements.firstIndex(where: { $0.id == id }) {
            let element = editableElements[index]
            let newX = element.position.x + (offset.width / UIScreen.main.bounds.width)
            let newY = element.position.y + (offset.height / UIScreen.main.bounds.height)
            editableElements[index].position = CGPoint(x: newX, y: newY)
        }
    }
    
    func updateElement(_ id: UUID, scale: CGFloat) {
        if let index = editableElements.firstIndex(where: { $0.id == id }) {
            editableElements[index].scale = scale
        }
    }
    
    func updateElement(_ id: UUID, rotation: Angle) {
        if let index = editableElements.firstIndex(where: { $0.id == id }) {
            editableElements[index].rotation = rotation.degrees
        }
    }
    
    func removeElement(_ id: UUID) {
        editableElements.removeAll { $0.id == id }
    }
    
    // MARK: - Drawing
    func startDrawing() {
        selectedTool = .drawing
    }
    
    func addDrawingPath(_ path: DrawingPath) {
        drawingPaths.append(path)
    }
    
    func clearDrawing() {
        drawingPaths.removeAll()
    }
    
    func undoLastPath() {
        if !drawingPaths.isEmpty {
            drawingPaths.removeLast()
        }
    }
    
    // MARK: - Templates
    func applyTemplate(_ template: StoryTemplate) {
        appliedTemplate = template
        
        // Apply template text style
        if let textStyle = template.textStyle {
            textFont = textStyle.font
            textColor = textStyle.color
            textBackgroundStyle = textStyle.backgroundStyle
        }
        
        // Apply template effect
        if let effect = template.effect {
            selectedEffect = effect
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    // MARK: - AI Tools
    func applyAIEnhancements() async {
        isProcessing = true
        processingMessage = "Enhancing with AI..."
        processingProgress = 0.0
        
        // Simulate AI processing
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            processingProgress = Double(i) / 10.0
        }
        
        isProcessing = false
    }
    
    func enhanceWithAI() async {
        guard hasMedia else { return }
        
        isProcessing = true
        processingMessage = "AI is working its magic..."
        
        // TODO: Implement AI enhancement
        // - Auto color correction
        // - Brightness/contrast optimization
        // - Noise reduction
        // - Sharpness enhancement
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        
        isProcessing = false
        HapticManager.shared.notification(type: .success)
    }
    
    func detectScene() async -> String? {
        guard hasMedia else { return nil }
        
        // TODO: Implement AI scene detection
        // - Detect scene type (outdoor, indoor, sunset, etc.)
        // - Suggest appropriate filters
        // - Recommend text styles
        
        return nil
    }
    
    // MARK: - Story Creation
    func createStory() async throws -> Story {
        guard let media = currentMedia else {
            throw StoryError.noMedia
        }
        
        isProcessing = true
        processingMessage = "Creating your story..."
        processingProgress = 0.0
        
        // 1. Upload media (20%)
        let mediaURL = try await uploadMedia(media)
        processingProgress = 0.2
        
        // 2. Process elements (40%)
        let processedElements = try await processElements()
        processingProgress = 0.6
        
        // 3. Create story object (80%)
        // Convert MediaType to Story.MediaType
        let storyMediaType: Story.MediaType = {
            switch media.type {
            case .image: return .image
            case .video: return .video
            }
        }()
        
        // Convert MusicTrack to StoryMusic
        let storyMusic: StoryMusic? = {
            guard let music = selectedMusic else { return nil }
            return StoryMusic(
                title: music.title,
                artist: music.artist,
                previewURL: music.url.absoluteString,
                duration: music.duration,
                startTime: 0.0
            )
        }()
        
        // Convert processed elements to stickers
        let stickers: [StorySticker] = processedElements.compactMap { element in
            switch element.type {
            case .sticker(let sticker):
                return StorySticker(
                    type: .emoji, // Default, adjust based on sticker type
                    x: Double(element.position.x),
                    y: Double(element.position.y),
                    scale: Double(element.scale),
                    rotation: element.rotation,
                    data: .emoji("😀") // Default, adjust based on sticker
                )
            default:
                return nil
            }
        }
        
        let story = Story(
            id: UUID().uuidString,
            creatorId: getCurrentUserId(),
            mediaURL: mediaURL,
            mediaType: storyMediaType,
            duration: media.type == .video ? 15.0 : 5.0,
            text: processedElements.first { 
                if case .text(let text) = $0.type {
                    return true
                }
                return false
            }.flatMap {
                if case .text(let text) = $0.type {
                    return text
                }
                return nil
            },
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400), // 24 hours
            music: storyMusic,
            stickers: stickers
        )
        processingProgress = 0.8
        
        // 4. Save to Firestore (100%)
        try await storyService.saveStory(story)
        processingProgress = 1.0
        
        isProcessing = false
        HapticManager.shared.notification(type: .success)
        
        return story
    }
    
    private func uploadMedia(_ media: CapturedMedia) async throws -> String {
        // TODO: Upload to Firebase Storage
        return "https://example.com/story-media.jpg"
    }
    
    private func processElements() async throws -> [ProcessedElement] {
        // Convert editable elements to processed elements for storage
        return editableElements.map { element in
            ProcessedElement(
                id: element.id,
                type: element.type,
                position: element.position,
                scale: element.scale,
                rotation: element.rotation,
                color: element.color,
                font: element.font,
                backgroundStyle: element.backgroundStyle
            )
        }
    }
    
    private func getCurrentUserId() -> String {
        // TODO: Get from AppState
        return "user-123"
    }
}

// MARK: - Captured Media
enum CapturedMedia: Identifiable {
    case image(UIImage)
    case video(URL)
    
    var id: String {
        switch self {
        case .image: return "image-\(UUID().uuidString)"
        case .video(let url): return "video-\(url.lastPathComponent)"
        }
    }
    
    var type: MediaType {
        switch self {
        case .image: return .image
        case .video: return .video
        }
    }
}

enum MediaType: String, Codable {
    case image
    case video
}

// MARK: - Editable Element
struct EditableElement: Identifiable {
    let id = UUID()
    let type: ElementType
    var position: CGPoint // Normalized 0...1
    var scale: CGFloat
    var rotation: Double
    var color: Color?
    var font: StoryFont?
    var backgroundStyle: TextBackgroundStyle?
    
    enum ElementType {
        case text(String)
        case sticker(Sticker)
        case drawing
    }
}

// MARK: - Processed Element (for storage)
struct ProcessedElement: Identifiable {
    let id: UUID
    let type: EditableElement.ElementType
    var position: CGPoint
    var scale: CGFloat
    var rotation: Double
    var color: Color?
    var font: StoryFont?
    var backgroundStyle: TextBackgroundStyle?
}

// MARK: - Drawing Path
struct DrawingPath: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

// MARK: - Story Font
enum StoryFont: String, Codable, CaseIterable {
    case bold = "Bold"
    case classic = "Classic"
    case typewriter = "Typewriter"
    case modern = "Modern"
    case neon = "Neon"
    
    var systemFont: Font {
        switch self {
        case .bold:
            return .system(size: 32, weight: .black, design: .rounded)
        case .classic:
            return .system(size: 32, weight: .semibold, design: .serif)
        case .typewriter:
            return .system(size: 32, weight: .regular, design: .monospaced)
        case .modern:
            return .system(size: 32, weight: .medium, design: .default)
        case .neon:
            return .system(size: 32, weight: .heavy, design: .rounded)
        }
    }
}

// MARK: - Text Background Style
enum TextBackgroundStyle: String, Codable, CaseIterable {
    case none = "None"
    case solid = "Solid"
    case gradient = "Gradient"
    case outline = "Outline"
}

// MARK: - Sticker
struct Sticker: Identifiable, Codable {
    let id = UUID()
    let imageName: String
    let category: StickerCategory
    
    enum StickerCategory: String, Codable {
        case emoji
        case animated
        case custom
    }
}

// MARK: - Music Track
struct MusicTrack: Identifiable, Codable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: TimeInterval
    let url: URL
    let thumbnailURL: URL?
}

// MARK: - AR Effect
struct AREffect: Identifiable, Codable {
    let id: String
    let name: String
    let category: EffectCategory
    let thumbnailURL: String
    
    init(id: String = UUID().uuidString, name: String, category: EffectCategory, thumbnailURL: String) {
        self.id = id
        self.name = name
        self.category = category
        self.thumbnailURL = thumbnailURL
    }
    
    enum EffectCategory: String, Codable {
        case filter
        case beauty
        case face
        case background
        case animated
    }
}

// MARK: - Story Template
struct StoryTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let category: TemplateCategory
    let thumbnailURL: String
    let textStyle: TemplateTextStyle?
    let effect: AREffect?
    let layout: TemplateLayout?
    
    init(id: String = UUID().uuidString, name: String, category: TemplateCategory, thumbnailURL: String, textStyle: TemplateTextStyle? = nil, effect: AREffect? = nil, layout: TemplateLayout? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.thumbnailURL = thumbnailURL
        self.textStyle = textStyle
        self.effect = effect
        self.layout = layout
    }
    
    enum TemplateCategory: String, Codable {
        case trending
        case minimal
        case bold
        case creative
        case business
    }
    
    struct TemplateTextStyle: Codable {
        let font: StoryFont
        let color: Color
        let backgroundStyle: TextBackgroundStyle
    }
    
    struct TemplateLayout {
        let textPosition: CGPoint
        let textAlignment: TextAlignment
        
        // Manual Codable conformance
        enum CodingKeys: String, CodingKey {
            case textPositionX, textPositionY, textAlignment
        }
    }
}

// MARK: - Manual Codable for TemplateLayout
extension StoryTemplate.TemplateLayout: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .textPositionX)
        let y = try container.decode(CGFloat.self, forKey: .textPositionY)
        textPosition = CGPoint(x: x, y: y)
        // Decode TextAlignment as String and convert
        let alignmentString = try container.decode(String.self, forKey: .textAlignment)
        textAlignment = {
            switch alignmentString {
            case "leading": return .leading
            case "center": return .center
            case "trailing": return .trailing
            default: return .center
            }
        }()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(textPosition.x, forKey: .textPositionX)
        try container.encode(textPosition.y, forKey: .textPositionY)
        // Encode TextAlignment as String
        let alignmentString: String = {
            switch textAlignment {
            case .leading: return "leading"
            case .center: return "center"
            case .trailing: return "trailing"
            @unknown default: return "center"
            }
        }()
        try container.encode(alignmentString, forKey: .textAlignment)
    }
}

// MARK: - Recording Mode
enum RecordingMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case boomerang = "Boomerang"
    case handsFree = "Hands-free"
    case superzoom = "Superzoom"
    case slowMotion = "Slow-Mo"
    case timeWarp = "Time Warp"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var color: Color {
        switch self {
        case .normal: return .white
        case .boomerang: return .yellow
        case .handsFree: return .green
        case .superzoom: return .blue
        case .slowMotion: return .purple
        case .timeWarp: return .orange
        }
    }
}

// MARK: - Editing Tool
enum EditingTool: String, CaseIterable {
    case none = "None"
    case text = "Text"
    case sticker = "Sticker"
    case drawing = "Drawing"
    case music = "Music"
    case filter = "Filter"
    case template = "Template"
    case ai = "AI"
}

// MARK: - Flash Mode Extension
extension AVCaptureDevice.FlashMode {
    var icon: String {
        switch self {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        @unknown default: return "bolt"
        }
    }
}

// MARK: - Story Error

// MARK: - Story Service
class StoryService {
    static let shared = StoryService()
    
    func saveStory(_ story: Story) async throws {
        // TODO: Save to Firestore
        print("✅ Story saved: \(story.id)")
    }
}

