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
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadWasCancelled: Bool = false

    #if canImport(FirebaseStorage)
    private var activeUploadTask: StorageUploadTask?
    #endif
    
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

    // Interactive stickers (poll/quiz/question/slider/countdown/link/mention/location/hashtag)
    // These are NOT baked into the media — they stay live so viewers can interact.
    @Published var interactiveStickers: [PlacedInteractiveSticker] = []
    
    // Templates
    @Published var appliedTemplate: StoryTemplate?
    
    // AI Tools
    @Published var aiEnhanceEnabled: Bool = false
    @Published var beautyFilterIntensity: Double = 0.0
    @Published var autoColorCorrect: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let storyService = StoryService.shared
    private let parityEngine = FacebookParityStoryEngine.shared
    
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

    func processCapturedVideo(at url: URL, focusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5), mode: RecordingMode) async throws -> URL {
        switch mode {
        case .boomerang:
            return try await parityEngine.applyBoomerang(to: url)
        case .superzoom:
            return try await parityEngine.applySuperzoom(to: url, focusPoint: focusPoint)
        case .slowMotion:
            return try await parityEngine.applySlowMotion(to: url, rate: 0.5)
        case .timeWarp:
            return try await parityEngine.applyTimeWarp(to: url)
        default:
            return url
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

    /// Adds a fully-configured text element (used by the text composer).
    @discardableResult
    func addTextElement(text: String, color: Color, font: StoryFont, background: TextBackgroundStyle) -> EditableElement {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let element = EditableElement(
            type: .text(trimmed.isEmpty ? " " : trimmed),
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1.0,
            rotation: 0,
            color: color,
            font: font,
            backgroundStyle: background
        )
        editableElements.append(element)
        HapticManager.shared.impact(style: .medium)
        return element
    }

    /// Updates the content/style of an existing text element in place.
    func updateTextElement(id: UUID, text: String, color: Color, font: StoryFont, background: TextBackgroundStyle) {
        guard let index = editableElements.firstIndex(where: { $0.id == id }) else { return }
        let old = editableElements[index]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        editableElements[index] = EditableElement(
            id: old.id,
            type: .text(trimmed.isEmpty ? " " : trimmed),
            position: old.position,
            scale: old.scale,
            rotation: old.rotation,
            color: color,
            font: font,
            backgroundStyle: background
        )
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
    
    var canvasSize: CGSize = CGSize(width: 390, height: 844)

    func updateElement(_ id: UUID, offset: CGSize) {
        if let index = editableElements.firstIndex(where: { $0.id == id }) {
            let element = editableElements[index]
            let newX = element.position.x + (offset.width / canvasSize.width)
            let newY = element.position.y + (offset.height / canvasSize.height)
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

    // MARK: - Interactive Stickers
    func addInteractiveSticker(_ kind: PlacedInteractiveSticker.Kind) {
        interactiveStickers.append(PlacedInteractiveSticker(kind: kind))
        HapticManager.shared.impact(style: .medium)
    }

    func updateInteractiveSticker(id: String, offset: CGSize) {
        guard let index = interactiveStickers.firstIndex(where: { $0.id == id }) else { return }
        let sticker = interactiveStickers[index]
        let newX = sticker.position.x + (offset.width / canvasSize.width)
        let newY = sticker.position.y + (offset.height / canvasSize.height)
        interactiveStickers[index].position = CGPoint(x: min(1, max(0, newX)), y: min(1, max(0, newY)))
    }

    func updateInteractiveSticker(id: String, scale: CGFloat) {
        guard let index = interactiveStickers.firstIndex(where: { $0.id == id }) else { return }
        interactiveStickers[index].scale = max(0.5, min(2.5, scale))
    }

    func removeInteractiveSticker(id: String) {
        interactiveStickers.removeAll { $0.id == id }
        HapticManager.shared.impact(style: .light)
    }

    /// Converts placed interactive stickers into the Story model's polls/links/stickers.
    private func buildInteractiveStoryData() -> (polls: [StoryPoll], links: [StoryLink], stickers: [StorySticker]) {
        var polls: [StoryPoll] = []
        var links: [StoryLink] = []
        var stickers: [StorySticker] = []

        for item in interactiveStickers {
            switch item.kind {
            case .poll(let question, let options):
                let pollOptions = options.map { StoryPoll.PollOption(text: $0) }
                polls.append(StoryPoll(
                    id: item.id,
                    question: question,
                    options: pollOptions,
                    x: Double(item.position.x),
                    y: Double(item.position.y)
                ))
            case .quiz(let question, let options, let correctIndex):
                // Store quiz as a poll plus a sticker carrying correct-answer metadata.
                let pollOptions = options.map { StoryPoll.PollOption(text: $0) }
                polls.append(StoryPoll(
                    id: item.id,
                    question: "[QUIZ:\(correctIndex)] \(question)",
                    options: pollOptions,
                    x: Double(item.position.x),
                    y: Double(item.position.y)
                ))
            case .question(let prompt):
                stickers.append(StorySticker(
                    id: item.id, type: .hashtag,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .hashtag("Q:\(prompt)")
                ))
            case .slider(let prompt, let emoji):
                stickers.append(StorySticker(
                    id: item.id, type: .emoji,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .emoji("SLIDER:\(emoji):\(prompt)")
                ))
            case .countdown(let title, let endTime):
                stickers.append(StorySticker(
                    id: item.id, type: .countdown,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .countdown(title: title, endTime: endTime)
                ))
            case .link(let url, let title):
                links.append(StoryLink(
                    id: item.id, url: url, title: title,
                    x: Double(item.position.x), y: Double(item.position.y)
                ))
            case .mention(let username):
                stickers.append(StorySticker(
                    id: item.id, type: .mention,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .hashtag("@\(username)")
                ))
            case .location(let name):
                stickers.append(StorySticker(
                    id: item.id, type: .location,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .location(name, 0, 0)
                ))
            case .hashtag(let tag):
                stickers.append(StorySticker(
                    id: item.id, type: .hashtag,
                    x: Double(item.position.x), y: Double(item.position.y),
                    scale: Double(item.scale), rotation: item.rotation,
                    data: .hashtag(tag)
                ))
            }
        }
        return (polls, links, stickers)
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
        processingMessage = "AI is enhancing your story..."
        // Apply Core Image filters for auto-enhancement
        if let currentMedia = currentMedia, let image = currentMedia.image {
            let ciImage = CIImage(image: image)
            let filter = CIFilter(name: "CIPhotoEffectChrome") ?? CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            if let output = filter?.outputImage,
               let cgImage = CIContext().createCGImage(output, from: output.extent) {
                let enhanced = UIImage(cgImage: cgImage)
                // Post notification so the story creator view updates its preview
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("StoryMediaEnhanced"),
                        object: enhanced
                    )
                }
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s visual feedback
        isProcessing = false
        HapticManager.shared.notification(type: .success)
    }
    
    func detectScene() async -> String? {
        guard hasMedia else { return nil }
        // Use Vision framework to classify the scene
        guard let image = currentMedia?.image,
              let ciImage = CIImage(image: image) else { return nil }
        return await withCheckedContinuation { cont in
            let request = VNClassifyImageRequest { req, _ in
                let top = (req.results as? [VNClassificationObservation])?
                    .filter { $0.confidence > 0.5 }
                    .first?.identifier
                cont.resume(returning: top)
            }
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try? handler.perform([request])
        }
    }
    
    // MARK: - Story Creation
    func createStory() async throws -> Story {
        guard let media = currentMedia else {
            throw StoryError.noMedia
        }
        
        isProcessing = true
        processingMessage = "Creating your story..."
        processingProgress = 0.0
        
        // 1. Upload media (20%) — bake overlays in first (WYSIWYG, Instagram parity)
        print("📸 [CreateStory] Step 1: Compositing overlays + uploading media...")
        let composedMedia = await composeMediaWithOverlays(media)
        let mediaURL: String
        do {
            mediaURL = try await uploadMedia(composedMedia)
            print("✅ [CreateStory] Step 1 DONE: Media uploaded to \(mediaURL)")
        } catch {
            print("🚨 [CreateStory] Step 1 FAILED (upload): \(error)")
            print("🚨 [CreateStory] Error type: \(type(of: error))")
            throw error
        }
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
        
        // Convert processed elements to stickers (preserve actual emoji/content)
        let emojiStickers: [StorySticker] = processedElements.compactMap { element in
            switch element.type {
            case .sticker(let sticker):
                let stickerData: StickerData = sticker.category == .emoji && !sticker.imageName.isEmpty
                    ? .emoji(sticker.imageName)
                    : .emoji("⭐️")
                return StorySticker(
                    type: .emoji,
                    x: Double(element.position.x),
                    y: Double(element.position.y),
                    scale: Double(element.scale),
                    rotation: element.rotation,
                    data: stickerData
                )
            default:
                return nil
            }
        }

        // Merge interactive stickers (polls/links/quizzes/etc.) into the story.
        let interactive = buildInteractiveStoryData()
        let stickers = emojiStickers + interactive.stickers
        
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
            stickers: stickers,
            polls: interactive.polls,
            links: interactive.links
        )
        processingProgress = 0.8
        
        // 4. Save to Firestore (100%)
        print("📸 [CreateStory] Step 4: Saving to Firestore...")
        do {
            try await storyService.saveStory(story)
            print("✅ [CreateStory] Step 4 DONE: Saved to Firestore")
        } catch {
            print("🚨 [CreateStory] Step 4 FAILED (Firestore): \(error)")
            print("🚨 [CreateStory] Error type: \(type(of: error))")
            throw error
        }
        processingProgress = 1.0
        
        isProcessing = false
        HapticManager.shared.notification(type: .success)
        
        return story
    }
    
    /// Bakes the on-canvas overlays (text, stickers, drawings) onto the media so
    /// the uploaded story matches what the user composed (Instagram WYSIWYG).
    private func composeMediaWithOverlays(_ media: CapturedMedia) async -> CapturedMedia {
        let plan = StoryOverlayPlan(
            elements: editableElements,
            drawingPaths: drawingPaths,
            canvasSize: canvasSize
        )
        guard !plan.isEmpty else { return media }

        switch media {
        case .image(let image):
            let composed = StoryCompositor.composeImage(baseImage: image, plan: plan)
            return .image(composed)
        case .video(let url):
            do {
                let composed = try await StoryCompositor.composeVideo(url: url, plan: plan)
                return .video(composed)
            } catch {
                print("⚠️ [CreateStory] Video overlay compositing failed, using original: \(error)")
                return media
            }
        }
    }

    private func uploadMedia(_ media: CapturedMedia) async throws -> String {
        #if canImport(FirebaseStorage) && canImport(FirebaseAuth)
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StoryError.processingFailed("Not signed in. Please log in and try again.")
        }
        let storage = Storage.storage()
        let storageRef = storage.reference()

        switch media {
        case .image(let image):
            guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                throw StoryError.processingFailed("Failed to compress image")
            }
            let imageRef = storageRef.child("stories/\(userId)/\(UUID().uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            return try await uploadWithProgress(ref: imageRef, data: imageData, fileURL: nil, metadata: metadata)

        case .video(let url):
            let videoRef = storageRef.child("stories/\(userId)/\(UUID().uuidString).mp4")
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            return try await uploadWithProgress(ref: videoRef, data: nil, fileURL: url, metadata: metadata)
        }
        #else
        throw StoryError.processingFailed("Firebase Storage not available")
        #endif
    }

    #if canImport(FirebaseStorage)
    /// Uploads with live progress and supports cancellation via `cancelUpload()`.
    private func uploadWithProgress(ref: StorageReference, data: Data?, fileURL: URL?, metadata: StorageMetadata) async throws -> String {
        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0.0
            self.uploadWasCancelled = false
        }

        let downloadURL: String = try await withCheckedThrowingContinuation { continuation in
            let task: StorageUploadTask
            if let data {
                task = ref.putData(data, metadata: metadata)
            } else if let fileURL {
                task = ref.putFile(from: fileURL, metadata: metadata)
            } else {
                continuation.resume(throwing: StoryError.processingFailed("Nothing to upload"))
                return
            }

            self.activeUploadTask = task

            task.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let fraction = progress.totalUnitCount > 0
                    ? Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    : 0
                Task { @MainActor in
                    self.uploadProgress = fraction
                    // Upload occupies the 0%→20% slice of overall processing.
                    self.processingProgress = fraction * 0.2
                }
            }

            task.observe(.success) { _ in
                Task {
                    do {
                        let url = try await ref.downloadURL()
                        continuation.resume(returning: url.absoluteString)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            task.observe(.failure) { snapshot in
                let error = snapshot.error ?? StoryError.processingFailed("Upload failed")
                let nsError = error as NSError
                if nsError.domain == StorageErrorDomain && nsError.code == StorageErrorCode.cancelled.rawValue {
                    continuation.resume(throwing: StoryError.uploadCancelled)
                } else {
                    continuation.resume(throwing: error)
                }
            }
        }

        await MainActor.run {
            self.isUploading = false
            self.activeUploadTask = nil
        }
        print("✅ [UltimateStory] Media uploaded: \(downloadURL)")
        return downloadURL
    }
    #endif

    /// Cancels an in-flight story upload (Instagram "X" on the upload ring).
    func cancelUpload() {
        #if canImport(FirebaseStorage)
        activeUploadTask?.cancel()
        activeUploadTask = nil
        #endif
        uploadWasCancelled = true
        isUploading = false
        isProcessing = false
        processingMessage = ""
        processingProgress = 0
        uploadProgress = 0
        HapticManager.shared.impact(style: .rigid)
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
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        #endif
        if let userId = AppState.shared.currentUser?.id {
            return userId
        }
        return UUID().uuidString
    }
    
    // MARK: - Set Music
    func setMusic(_ music: MusicTrack) {
        selectedMusic = music
        HapticManager.shared.impact(style: .medium)
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

    /// Underlying still image when this media is a captured photo.
    var image: UIImage? {
        switch self {
        case .image(let uiImage): return uiImage
        case .video: return nil
        }
    }

    /// Underlying file URL when this media is a captured video.
    var videoURL: URL? {
        switch self {
        case .video(let url): return url
        case .image: return nil
        }
    }
}

enum MediaType: String, Codable {
    case image
    case video
}

// MARK: - Editable Element
struct EditableElement: Identifiable {
    let id: UUID
    let type: ElementType
    var position: CGPoint // Normalized 0...1
    var scale: CGFloat
    var rotation: Double
    var color: Color?
    var font: StoryFont?
    var backgroundStyle: TextBackgroundStyle?

    init(
        id: UUID = UUID(),
        type: ElementType,
        position: CGPoint,
        scale: CGFloat,
        rotation: Double,
        color: Color? = nil,
        font: StoryFont? = nil,
        backgroundStyle: TextBackgroundStyle? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = color
        self.font = font
        self.backgroundStyle = backgroundStyle
    }

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

// MARK: - Placed Interactive Sticker
// A poll / quiz / question / slider / countdown / link / mention / location / hashtag
// placed on the canvas. Carries its own normalized position + payload and stays live
// (NOT baked into media) so viewers can interact with it.
struct PlacedInteractiveSticker: Identifiable, Equatable {
    let id: String
    var kind: Kind
    var position: CGPoint   // normalized 0...1
    var scale: CGFloat
    var rotation: Double

    enum Kind: Equatable {
        case poll(question: String, options: [String])
        case quiz(question: String, options: [String], correctIndex: Int)
        case question(prompt: String)
        case slider(prompt: String, emoji: String)
        case countdown(title: String, endTime: Date)
        case link(url: String, title: String)
        case mention(username: String)
        case location(name: String)
        case hashtag(tag: String)
    }

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1.0,
        rotation: Double = 0
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.scale = scale
        self.rotation = rotation
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
    
    var processingMessage: String? {
        switch self {
        case .boomerang:
            return "Creating Boomerang..."
        case .superzoom:
            return "Applying Superzoom..."
        case .slowMotion:
            return "Building slow motion..."
        case .timeWarp:
            return "Applying time warp..."
        default:
            return nil
        }
    }
    
    var autoRecordDuration: TimeInterval? {
        switch self {
        case .boomerang:
            return 1.2
        case .superzoom:
            return 3.0
        default:
            return nil
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
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil else {
            throw StoryError.processingFailed("Firebase is not configured")
        }
        
        // Ensure the creatorId is always the real Firebase Auth UID
        guard let authUID = Auth.auth().currentUser?.uid else {
            throw StoryError.processingFailed("Not signed in. Please log in and try again.")
        }
        
        // Build story with correct UID — never trust passed-in creatorId
        let verifiedCreatorId = authUID
        
        let db = Firestore.firestore()
        let storiesRef = db.collection("stories").document(story.id)
        
        var data: [String: Any] = [
            "id": story.id,
            "creatorId": verifiedCreatorId,
            "mediaURL": story.mediaURL,
            "mediaType": story.mediaType.rawValue,
            "duration": story.duration,
            "viewCount": story.viewCount,
            "isViewed": story.isViewed,
            "isLive": story.isLive,
            "isActive": true,
            "isPublic": (story.audience ?? "public") == "public",
            "audience": story.audience ?? "public",
            "createdAt": Timestamp(date: story.createdAt),
            "expiresAt": Timestamp(date: story.expiresAt)
        ]
        
        if let caption = story.caption { data["caption"] = caption }
        if let text = story.text { data["text"] = text }
        if let backgroundColor = story.backgroundColor { data["backgroundColor"] = backgroundColor }
        if let textColor = story.textColor { data["textColor"] = textColor }
        if let thumbnail = story.thumbnail { data["thumbnail"] = thumbnail }
        if let music = story.music {
            data["music"] = [
                "id": music.id,
                "title": music.title,
                "artist": music.artist,
                "previewURL": music.previewURL,
                "duration": music.duration,
                "startTime": music.startTime
            ]
        }
        
        data["content"] = story.content.map { content in
            var contentData: [String: Any] = [
                "id": content.id,
                "url": content.url,
                "type": content.type.rawValue,
                "duration": content.duration
            ]
            if let text = content.text { contentData["text"] = text }
            if let backgroundColor = content.backgroundColor { contentData["backgroundColor"] = backgroundColor }
            return contentData
        }
        
        data["stickers"] = story.stickers.map { sticker in
            var stickerData: [String: Any] = [
                "id": sticker.id,
                "type": sticker.type.rawValue,
                "x": sticker.x,
                "y": sticker.y,
                "scale": sticker.scale,
                "rotation": sticker.rotation
            ]
            
            stickerData["data"] = serializeStickerData(sticker.data)
            return stickerData
        }
        
        data["polls"] = story.polls.map { poll in
            [
                "id": poll.id,
                "question": poll.question,
                "options": poll.options.map { option in
                    [
                        "id": option.id,
                        "text": option.text,
                        "voteCount": option.voteCount,
                        "color": option.color
                    ]
                },
                "x": poll.x,
                "y": poll.y,
                "expiresAt": Timestamp(date: poll.expiresAt)
            ]
        }
        
        data["links"] = story.links.map { link in
            var linkData: [String: Any] = [
                "id": link.id,
                "url": link.url,
                "title": link.title,
                "x": link.x,
                "y": link.y
            ]
            if let description = link.description { linkData["description"] = description }
            if let imageURL = link.imageURL { linkData["imageURL"] = imageURL }
            return linkData
        }
        
        print("📝 [StoryService] Writing to /stories/\(story.id) with creatorId=\(story.creatorId)")
        print("📝 [StoryService] Firebase Auth uid=\(Auth.auth().currentUser?.uid ?? "nil")")
        try await storiesRef.setData(data)
        print("✅ [StoryService] /stories/\(story.id) written successfully")
        
        let collectionRef = db.collection("story-collections").document(verifiedCreatorId)
        print("📝 [StoryService] Writing to /story-collections/\(verifiedCreatorId)")
        try await collectionRef.setData([
            "creatorId": verifiedCreatorId,
            "latestStoryId": story.id,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        print("✅ [StoryService] /story-collections/\(story.creatorId) written successfully")
        #else
        print("⚠️ Firestore not available - skipping save for story \(story.id)")
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func serializeStickerData(_ data: StickerData) -> [String: Any] {
        switch data {
        case .emoji(let value):
            return ["kind": "emoji", "value": value]
        case .gif(let value):
            return ["kind": "gif", "value": value]
        case .location(let name, let lat, let lng):
            return ["kind": "location", "name": name, "lat": lat, "lng": lng]
        case .mention(let user):
            return ["kind": "mention", "userId": user.id, "username": user.username]
        case .hashtag(let hashtag):
            return ["kind": "hashtag", "value": hashtag]
        case .time(let date):
            return ["kind": "time", "value": Timestamp(date: date)]
        case .weather(let condition, let temperature):
            return ["kind": "weather", "condition": condition, "temperature": temperature]
        case .poll(let question, let options, let votes):
            return [
                "kind": "poll",
                "question": question,
                "options": options,
                "votes": votes
            ]
        case .countdown(let title, let endTime):
            return ["kind": "countdown", "title": title, "endTime": Timestamp(date: endTime)]
        }
    }
    #endif
}

