//
//  CreateStoryViewModel.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import Photos
import Combine

@MainActor
class CreateStoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var storyType: StoryType = .camera
    @Published var selectedMedia: MediaItem?
    @Published var textOverlay: TextOverlay?
    @Published var stickers: [StickerItem] = []
    @Published var backgroundMusic: MusicItem?
    @Published var backgroundGradient: [Color] = [.blue, .purple]
    
    // ⚡ PERFORMANCE: Combine camera properties into single state
    @Published var cameraState: CameraState = .empty
    
    struct CameraState {
        var isActive = false
        var isRecording = false
        var flashMode: FlashMode = .off
        var position: AVCaptureDevice.Position = .back
        var recordingDuration = "00:00"
        var focusPoint: CGPoint? = nil
        var focusPulseID: UUID = UUID()
        
        static let empty = CameraState()
    }
    
    // ⚡ PERFORMANCE: Combine processing states into single state
    @Published var processingState: ProcessingState = .empty
    
    struct ProcessingState {
        var isProcessing = false
        var showingError = false
        var errorMessage = ""
        var uploadProgress: Double = 0.0
        
        static let empty = ProcessingState()
    }
    
    // ⚡ PERFORMANCE: Combine transform properties into single state
    @Published var transformState: TransformState = .empty
    
    struct TransformState {
        var scale: CGFloat = 1.0
        var offset = CGSize.zero
        
        static let empty = TransformState()
    }
    
    // ⚡ PERFORMANCE: Combine text editing properties into single state
    @Published var textEditingState: TextEditingState = .empty
    
    struct TextEditingState {
        var fontSize: Double = 32
        var color: Color = .white
        var alignment: TextAlignment = .center
        
        static let empty = TextEditingState()
    }
    
    // Publish
    @Published var caption: String = ""
    @Published var audience: Audience = .public
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Computed Properties
    var canPost: Bool {
        switch storyType {
        case .camera:
            return selectedMedia != nil
        case .photo, .video:
            return selectedMedia != nil
        case .text:
            return textOverlay != nil
        }
    }
    
    var hasBackgroundMusic: Bool {
        backgroundMusic != nil
    }
    
    // MARK: - Story Type
    enum StoryType {
        case camera
        case photo
        case video
        case text
    }

    enum Audience: String, CaseIterable { case `public`, friends }
    
    // MARK: - Flash Mode
    enum FlashMode {
        case off
        case on
        case auto
        
        var iconName: String {
            switch self {
            case .off: return "bolt.slash.fill"
            case .on: return "bolt.fill"
            case .auto: return "bolt.badge.automatic.fill"
            }
        }
    }
    
    // MARK: - Media Item
    struct MediaItem {
        let id = UUID()
        let url: URL
        let type: MediaType
        let duration: TimeInterval?
        
        enum MediaType {
            case image
            case video
        }
    }
    
    // MARK: - Text Overlay
    struct TextOverlay: Identifiable {
        let id = UUID()
        var text: String
        var position = CGPoint(x: 0.5, y: 0.5)
        var scale: CGFloat = 1.0
        var rotation: Double = 0.0
        var color: Color = .white
        var backgroundColor: Color = .clear
        var fontStyle: FontStyle = .bold
        
        enum FontStyle: CaseIterable {
            case regular
            case bold
            case italic
            case cursive
            case mono
            
            var displayName: String {
                switch self {
                case .regular: return "Regular"
                case .bold: return "Bold"
                case .italic: return "Italic"
                case .cursive: return "Cursive"
                case .mono: return "Monospace"
                }
            }
            
            var font: Font {
                switch self {
                case .regular: return .system(.title2, design: .default)
                case .bold: return .system(.title2, design: .default, weight: .bold)
                case .italic: return .system(.title2, design: .default).italic()
                case .cursive: return .system(.title2, design: .serif)
                case .mono: return .system(.title2, design: .monospaced)
                }
            }
        }
    }
    
    // MARK: - Sticker Item
    struct StickerItem: Identifiable {
        let id = UUID()
        let type: StickerType
        var position = CGPoint(x: 0.5, y: 0.5)
        var scale: CGFloat = 1.0
        var rotation: Double = 0.0
        let data: Any
        
        enum StickerType {
            case emoji
            case location
            case mention
            case hashtag
            case poll
            case time
            case weather
        }
    }
    
    // MARK: - Music Item
    struct MusicItem {
        let id = UUID()
        let title: String
        let artist: String
        let previewURL: String
        let artworkURL: String?
        let startTime: TimeInterval = 0
        let duration: TimeInterval = 30
    }
    
    // MARK: - Methods
    
    func setMedia(_ media: MediaItem) {
        selectedMedia = media
        switch media.type {
        case .image:
            storyType = .photo
        case .video:
            storyType = .video
        }
        haptic.impactOccurred()
    }
    
    func addTextOverlay(_ textStyle: TextOverlay) {
        textOverlay = textStyle
        if storyType == .camera && !cameraState.isActive {
            storyType = .text
        }
        haptic.impactOccurred()
    }
    
    func updateTextOverlay(_ updatedOverlay: TextOverlay) {
        textOverlay = updatedOverlay
    }
    
    func removeTextOverlay() {
        textOverlay = nil
    }
    
    func addSticker(_ sticker: StickerItem) {
        stickers.append(sticker)
        haptic.impactOccurred()
    }
    
    func updateSticker(_ updatedSticker: StickerItem) {
        if let index = stickers.firstIndex(where: { $0.id == updatedSticker.id }) {
            stickers[index] = updatedSticker
        }
    }
    
    func removeSticker(_ sticker: StickerItem) {
        stickers.removeAll { $0.id == sticker.id }
    }
    
    func setBackgroundMusic(_ music: MusicItem) {
        backgroundMusic = music
        haptic.impactOccurred()
    }
    
    func toggleFlash() {
        switch cameraState.flashMode {
        case .off:
            cameraState.flashMode = .on
        case .on:
            cameraState.flashMode = .auto
        case .auto:
            cameraState.flashMode = .off
        }
        haptic.impactOccurred()
    }
    
    func switchCamera() {
        cameraState.position = cameraState.position == .back ? .front : .back
        haptic.impactOccurred()
    }
    
    func updateScale(_ newScale: CGFloat) {
        transformState.scale = max(0.5, min(3.0, newScale))
    }
    
    func updateOffset(_ translation: CGSize) {
        transformState.offset = CGSize(
            width: transformState.offset.width + translation.width,
            height: transformState.offset.height + translation.height
        )
    }
    
    func capturePhoto() {
        // Simulate photo capture
        Task {
            await simulateMediaCapture(type: .image)
        }
    }
    
    func startRecording() {
        guard !cameraState.isRecording else { return }
        
        cameraState.isRecording = true
        recordingStartTime = Date()
        
        // Start recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateRecordingDuration()
            }
        }
        
        haptic.impactOccurred()
        
        // Auto-stop after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.cameraState.isRecording {
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        guard cameraState.isRecording else { return }
        
        cameraState.isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        Task {
            await simulateMediaCapture(type: .video)
        }
        
        haptic.impactOccurred()
    }

    // MARK: - Focus / Tap-to-focus (visual only for now)
    func focus(at point: CGPoint) {
        // point is normalized (0...1)
        cameraState.focusPoint = point
        cameraState.focusPulseID = UUID()
        haptic.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.cameraState.focusPoint = nil
        }
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        cameraState.recordingDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func simulateMediaCapture(type: MediaItem.MediaType) async {
        // Simulate capture delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Create a mock media item
        let mockURL = URL(string: "https://picsum.photos/400/800?random=\(Int.random(in: 1...100))")!
        let mediaItem = MediaItem(
            url: mockURL,
            type: type,
            duration: type == .video ? Double.random(in: 5...15) : nil
        )
        
        await MainActor.run {
            self.selectedMedia = mediaItem
            self.storyType = type == .image ? .photo : .video
        }
    }
    
    func createStory() async -> Story {
        processingState.isProcessing = true
        processingState.uploadProgress = 0.0
        
        defer {
            processingState.isProcessing = false
            processingState.uploadProgress = 0.0
        }
        
        let storyContent = createStoryContent()
        let storyStickers = createStoryStickers()
        let storyMusic = createStoryMusic()
        let creatorId = AuthenticationManager.shared.currentUser?.id ?? User.sampleUsers.first?.id ?? "user1"
        var created: Story? = nil
        
        // Build fallback story (used on error or when no uploadable media)
        func makeFallbackStory(mediaURL: String = selectedMedia?.url.absoluteString ?? "") -> Story {
            Story(
                creatorId: creatorId,
                mediaURL: mediaURL,
                mediaType: getStoryMediaType(),
                duration: getStoryDuration(),
                caption: caption.isEmpty ? nil : caption,
                text: textOverlay?.text,
                content: [storyContent],
                backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
                textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
                music: storyMusic,
                stickers: storyStickers
            )
        }
        
        // Get media data: from file URL (photo library) or remote URL (camera mock)
        if let media = selectedMedia {
            let data: Data?
            let scheme = media.url.scheme?.lowercased()
            if scheme == "file" {
                // Photo picker: read from local file
                data = try? Data(contentsOf: media.url)
            } else if scheme == "http" || scheme == "https" {
                // Remote URL: fetch (e.g. camera mock URLs)
                data = try? await NetworkOptimizer.shared.optimizedRequest(
                    for: media.url,
                    priority: .high,
                    cachePolicy: .returnCacheDataElseLoad
                )
            } else {
                data = nil
            }
            
            if let data = data, !data.isEmpty {
                do {
                    let filename = "story_\(UUID().uuidString).\(media.type == .video ? "mp4" : "jpg")"
                    let contentType = media.type == .video ? "video/mp4" : "image/jpeg"
                    
                    let signed = try await StoryAPIService.shared.getSignedUploadUrl(filename: filename, contentType: contentType)
                    processingState.uploadProgress = 0.3
                    
                    try await StoryAPIService.shared.uploadMedia(data: data, to: signed.url, contentType: contentType)
                    processingState.uploadProgress = 0.7
                    
                    let finalized = try await StoryAPIService.shared.finalize(object: signed.object, bucket: signed.bucket, contentType: contentType)
                    processingState.uploadProgress = 0.85
                    
                    let s = try await StoryAPIService.shared.createStory(
                        mediaUrl: finalized.publicUrl,
                        mediaType: getStoryMediaType(),
                        duration: getStoryDuration(),
                        caption: caption.isEmpty ? nil : caption,
                        text: textOverlay?.text,
                        backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
                        textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
                        music: storyMusic,
                        stickers: storyStickers,
                        audience: audience.rawValue
                    )
                    created = s
                    processingState.uploadProgress = 1.0
                    try? await DatabaseService.shared.saveStory(s)
                } catch {
                    showError("Couldn't post story: \(error.localizedDescription). Saved locally.")
                    created = makeFallbackStory(mediaURL: media.url.absoluteString)
                    if let c = created { try? await DatabaseService.shared.saveStory(c) }
                }
            } else {
                // No data (e.g. file read failed): save local story so something appears
                created = makeFallbackStory()
                if let c = created { try? await DatabaseService.shared.saveStory(c) }
            }
        } else {
            // Text-only or no media
            created = makeFallbackStory()
            if let c = created { try? await DatabaseService.shared.saveStory(c) }
        }
        
        return created ?? makeFallbackStory()
    }
    
    private func createStoryContent() -> StoryContent {
        return StoryContent(
            url: selectedMedia?.url.absoluteString ?? "",
            type: getStoryMediaType(),
            duration: getStoryDuration(),
            text: textOverlay?.text,
            backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil
        )
    }
    
    private func createStoryStickers() -> [StorySticker] {
        return stickers.compactMap { stickerItem in
            let stickerType: StorySticker.StickerType
            let stickerData: StickerData
            
            switch stickerItem.type {
            case .emoji:
                stickerType = .emoji
                stickerData = .emoji(stickerItem.data as? String ?? "😊")
            case .location:
                stickerType = .location
                stickerData = .location("Location", 0.0, 0.0)
            case .mention:
                stickerType = .mention
                // Create a placeholder user for mentions since we need a User object
                let username = stickerItem.data as? String ?? "username"
                let placeholderUser = User(
                    username: username,
                    displayName: "@\(username)",
                    email: "\(username)@example.com"
                )
                stickerData = .mention(placeholderUser)
            case .hashtag:
                stickerType = .hashtag
                stickerData = .hashtag(stickerItem.data as? String ?? "hashtag")
            case .time:
                stickerType = .time
                stickerData = .time(Date())
            default:
                return nil
            }
            
            return StorySticker(
                type: stickerType,
                x: stickerItem.position.x,
                y: stickerItem.position.y,
                scale: stickerItem.scale,
                rotation: stickerItem.rotation,
                data: stickerData
            )
        }
    }
    
    private func createStoryMusic() -> StoryMusic? {
        guard let music = backgroundMusic else { return nil }
        
        return StoryMusic(
            title: music.title,
            artist: music.artist,
            previewURL: music.previewURL,
            duration: music.duration,
            startTime: music.startTime
        )
    }
    
    private func getStoryMediaType() -> Story.MediaType {
        switch storyType {
        case .camera, .photo:
            return .image
        case .video:
            return .video
        case .text:
            return .text
        }
    }
    
    private func getStoryDuration() -> TimeInterval {
        if let media = selectedMedia, let duration = media.duration {
            return duration
        }
        return 15.0 // Default duration
    }
    
    private func colorToHex(_ color: Color) -> String {
        // Simple color to hex conversion
        return "#FF6B6B" // Placeholder
    }
    
    func showError(_ message: String) {
        processingState.errorMessage = message
        processingState.showingError = true
    }
}