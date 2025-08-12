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
    
    // Camera properties
    @Published var isCameraActive = false
    @Published var isRecording = false
    @Published var flashMode: FlashMode = .off
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    // Processing states
    @Published var isProcessing = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // Transform properties
    @Published var scale: CGFloat = 1.0
    @Published var offset = CGSize.zero
    
    // Recording duration
    @Published var recordingDuration = "00:00"
    // Focus point (0...1 normalized in preview coordinates)
    @Published var focusPoint: CGPoint? = nil
    @Published var focusPulseID: UUID = UUID()
    
    // Publish
    @Published var caption: String = ""
    @Published var audience: Audience = .public
    
    // Text editing properties
    @Published var textFontSize: Double = 32
    @Published var textColor: Color = .white
    @Published var textAlignment: TextAlignment = .center
    
    // Upload progress
    @Published var uploadProgress: Double = 0.0
    
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
        if storyType == .camera && !isCameraActive {
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
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
        haptic.impactOccurred()
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        haptic.impactOccurred()
    }
    
    func updateScale(_ newScale: CGFloat) {
        scale = max(0.5, min(3.0, newScale))
    }
    
    func updateOffset(_ translation: CGSize) {
        offset = CGSize(
            width: offset.width + translation.width,
            height: offset.height + translation.height
        )
    }
    
    func capturePhoto() {
        // Simulate photo capture
        Task {
            await simulateMediaCapture(type: .image)
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
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
            if self.isRecording {
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
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
        focusPoint = point
        focusPulseID = UUID()
        haptic.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.focusPoint = nil
        }
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingDuration = String(format: "%02d:%02d", minutes, seconds)
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
        isProcessing = true
        uploadProgress = 0.0
        
        // Simulate upload progress
        for i in 1...10 {
            uploadProgress = Double(i) / 10.0
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        let storyContent = createStoryContent()
        let storyStickers = createStoryStickers()
        let storyMusic = createStoryMusic()
        
        let story = Story(
            creatorId: User.sampleUsers.first?.id ?? "user1",
            mediaURL: selectedMedia?.url.absoluteString ?? "",
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
        
        isProcessing = false
        uploadProgress = 0.0
        return story
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
                stickerData = .mention(stickerItem.data as? String ?? "username")
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
        errorMessage = message
        showingError = true
    }
}