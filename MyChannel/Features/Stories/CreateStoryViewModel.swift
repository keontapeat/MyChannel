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
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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

    enum Audience: String, CaseIterable {
        case `public`
        case friends
        case closeFriends = "close_friends"
        case followers = "followers"
        case hiddenFrom = "hidden_from"

        var displayName: String {
            switch self {
            case .public: return "Public"
            case .friends: return "Friends"
            case .closeFriends: return "Close Friends"
            case .followers: return "Followers"
            case .hiddenFrom: return "Hide From Some"
            }
        }
    }

    struct TextOverlayCodable: Codable {
        let text: String
        let x: Double
        let y: Double
        let scale: Double
        let rotation: Double
        let colorHex: String
    }
    
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

    private func createStoryPolls() -> [StoryPoll] {
        stickers.compactMap { stickerItem -> StoryPoll? in
            guard stickerItem.type == .poll,
                  let rawPoll = stickerItem.data as? String,
                  !rawPoll.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let options = [
                StoryPoll.PollOption(text: "Yes"),
                StoryPoll.PollOption(text: "No")
            ]
            return StoryPoll(
                question: rawPoll,
                options: options,
                x: stickerItem.position.x,
                y: stickerItem.position.y
            )
        }
    }

    private func createStoryLinks() -> [StoryLink] {
        stickers.compactMap { stickerItem -> StoryLink? in
            guard stickerItem.type == .mention || stickerItem.type == .hashtag || stickerItem.type == .location else {
                return nil
            }
            let rawValue = String(describing: stickerItem.data)
            guard !rawValue.isEmpty else { return nil }

            switch stickerItem.type {
            case .mention:
                return StoryLink(
                    url: "https://mychannel.app/@\(rawValue)",
                    title: "@\(rawValue)",
                    x: stickerItem.position.x,
                    y: stickerItem.position.y
                )
            case .hashtag:
                return StoryLink(
                    url: "https://mychannel.app/hashtag/\(rawValue)",
                    title: "#\(rawValue)",
                    x: stickerItem.position.x,
                    y: stickerItem.position.y
                )
            case .location:
                return StoryLink(
                    url: "https://maps.apple.com/?q=\(rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawValue)",
                    title: rawValue,
                    x: stickerItem.position.x,
                    y: stickerItem.position.y
                )
            default:
                return nil
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
        
        enum StickerType: String {
            case emoji
            case location
            case mention
            case hashtag
            case poll
            case time
            case weather
        }
    }

    struct StickerItemCodable: Codable {
        let type: String
        let x: Double
        let y: Double
        let scale: Double
        let rotation: Double
        let value: String
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

    func saveDraft() {
        #if canImport(FirebaseAuth)
        guard let creatorId = Auth.auth().currentUser?.uid ?? AuthenticationManager.shared.currentUser?.id else { return }
        #else
        guard let creatorId = AuthenticationManager.shared.currentUser?.id else { return }
        #endif

        let draft = StoryDraft(
            creatorId: creatorId,
            caption: caption,
            audience: audience.rawValue,
            stickers: stickers.map { sticker in
                StickerItemCodable(
                    type: sticker.type.rawValue,
                    x: sticker.position.x,
                    y: sticker.position.y,
                    scale: sticker.scale,
                    rotation: sticker.rotation,
                    value: String(describing: sticker.data)
                )
            },
            textOverlay: textOverlay.map {
                TextOverlayCodable(
                    text: $0.text,
                    x: $0.position.x,
                    y: $0.position.y,
                    scale: $0.scale,
                    rotation: $0.rotation,
                    colorHex: colorToHex($0.color)
                )
            },
            backgroundColors: backgroundGradient.map { colorToHex($0) },
            mediaURL: selectedMedia?.url.absoluteString,
            mediaType: selectedMedia.map { $0.type == .image ? "image" : "video" }
        )
        StoryDraftService.shared.saveDraft(draft, creatorId: creatorId)
    }

    func restoreDraftIfAvailable() {
        #if canImport(FirebaseAuth)
        guard let creatorId = Auth.auth().currentUser?.uid ?? AuthenticationManager.shared.currentUser?.id else { return }
        #else
        guard let creatorId = AuthenticationManager.shared.currentUser?.id else { return }
        #endif

        guard let draft = StoryDraftService.shared.loadDraft(creatorId: creatorId) else { return }

        caption = draft.caption
        audience = Audience(rawValue: draft.audience) ?? .public
        stickers = draft.stickers.compactMap { item in
            guard let type = StickerItem.StickerType(rawValue: item.type) else { return nil }
            return StickerItem(
                type: type,
                position: CGPoint(x: item.x, y: item.y),
                scale: item.scale,
                rotation: item.rotation,
                data: item.value
            )
        }
        textOverlay = draft.textOverlay.map {
            TextOverlay(
                text: $0.text,
                position: CGPoint(x: $0.x, y: $0.y),
                scale: $0.scale,
                rotation: $0.rotation,
                color: Color(hexString: $0.colorHex) ?? .white
            )
        }
        if !draft.backgroundColors.isEmpty {
            backgroundGradient = draft.backgroundColors.compactMap { Color(hexString: $0) }
        }
        if let mediaURL = draft.mediaURL, let url = URL(string: mediaURL), let mediaType = draft.mediaType {
            selectedMedia = MediaItem(url: url, type: mediaType == "image" ? .image : .video, duration: nil)
            storyType = mediaType == "image" ? .photo : .video
        }
    }

    func clearDraft() {
        #if canImport(FirebaseAuth)
        guard let creatorId = Auth.auth().currentUser?.uid ?? AuthenticationManager.shared.currentUser?.id else { return }
        #else
        guard let creatorId = AuthenticationManager.shared.currentUser?.id else { return }
        #endif
        StoryDraftService.shared.clearDraft(creatorId: creatorId)
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
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if self?.cameraState.isRecording == true {
                self?.stopRecording()
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
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
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
        print("⚠️ [CreateStoryViewModel] simulateMediaCapture called - media should come from ModernCameraView callback")
    }
    
    func createStory() async -> Story {
        print("📸 [Story Upload] Starting story creation...")
        processingState.isProcessing = true
        processingState.uploadProgress = 0.0
        
        defer {
            processingState.isProcessing = false
            processingState.uploadProgress = 0.0
        }
        
        let storyContent = createStoryContent()
        let storyStickers = createStoryStickers()
        let storyMusic = createStoryMusic()
        let storyPolls = createStoryPolls()
        let storyLinks = createStoryLinks()
        // Use Firebase Auth UID directly to match Firestore security rules
        #if canImport(FirebaseAuth)
        let creatorId = Auth.auth().currentUser?.uid ?? AuthenticationManager.shared.currentUser?.id ?? "user1"
        #else
        let creatorId = AuthenticationManager.shared.currentUser?.id ?? "user1"
        #endif
        print("📸 [Story Upload] Creator ID: \(creatorId)")
        var created: Story? = nil
        let currentMedia = selectedMedia
        
        // Upload media to Firebase Storage then save story to Firestore
        if let media = currentMedia {
            print("📸 [Story Upload] Media found: \(media.url)")
            do {
                let mediaURL = try await uploadMediaToFirebaseStorage(media)
                print("✅ [Story Upload] Media uploaded, public URL: \(mediaURL)")
                processingState.uploadProgress = 0.8

                let s = Story(
                    creatorId: creatorId,
                    mediaURL: mediaURL,
                    mediaType: getStoryMediaType(),
                    duration: getStoryDuration(),
                    caption: caption.isEmpty ? nil : caption,
                    text: textOverlay?.text,
                    isCloseFriends: audience == .closeFriends,
                    content: [storyContent],
                    backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
                    textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
                    music: storyMusic,
                    stickers: storyStickers,
                    polls: storyPolls,
                    links: storyLinks,
                    audience: audience.rawValue
                )
                print("📸 [Story Upload] Saving story to Firestore...")
                try await DatabaseService.shared.saveStory(s)
                print("✅ [Story Upload] Story saved to Firestore: \(s.id)")
                created = s
                processingState.uploadProgress = 1.0
            } catch {
                print("🚨 [Story Upload] Error: \(error.localizedDescription)")
                showError(error.localizedDescription)
                let failedStory = Story(
                    creatorId: creatorId,
                    mediaURL: media.url.absoluteString,
                    mediaType: getStoryMediaType(),
                    duration: getStoryDuration(),
                    caption: caption.isEmpty ? nil : caption,
                    text: textOverlay?.text,
                    isCloseFriends: audience == .closeFriends,
                    content: [storyContent],
                    backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
                    textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
                    music: storyMusic,
                    stickers: storyStickers,
                    polls: storyPolls,
                    links: storyLinks,
                    audience: audience.rawValue
                )
                return failedStory
            }
        } else {
            print("📸 [Story Upload] No media selected (text-only story)")
            created = Story(
                creatorId: creatorId,
                mediaURL: "",
                mediaType: getStoryMediaType(),
                duration: getStoryDuration(),
                caption: caption.isEmpty ? nil : caption,
                text: textOverlay?.text,
                isCloseFriends: audience == .closeFriends,
                content: [storyContent],
                backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
                textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
                music: storyMusic,
                stickers: storyStickers,
                polls: storyPolls,
                links: storyLinks,
                audience: audience.rawValue
            )
            if let c = created {
                do {
                    try await DatabaseService.shared.saveStory(c)
                    print("✅ [Story Upload] Text-only story saved")
                } catch {
                    print("� [Story Upload] Failed to save text-only story: \(error.localizedDescription)")
                    showError(error.localizedDescription)
                    return c
                }
            }
        }

        let finalStory = created ?? Story(
            creatorId: creatorId,
            mediaURL: currentMedia?.url.absoluteString ?? "",
            mediaType: getStoryMediaType(),
            duration: getStoryDuration(),
            caption: caption.isEmpty ? nil : caption,
            text: textOverlay?.text,
            isCloseFriends: audience == .closeFriends,
            content: [storyContent],
            backgroundColor: storyType == .text ? colorToHex(backgroundGradient.first ?? .blue) : nil,
            textColor: textOverlay != nil ? colorToHex(textOverlay!.color) : nil,
            music: storyMusic,
            stickers: storyStickers,
            polls: storyPolls,
            links: storyLinks,
            audience: audience.rawValue
        )
        print("📸 [Story Upload] Returning story: \(finalStory.id)")
        return finalStory
    }
    
    private func uploadMediaToFirebaseStorage(_ media: MediaItem) async throws -> String {
        #if canImport(FirebaseStorage) && canImport(FirebaseAuth)
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StoryError.processingFailed("Not signed in. Please log in and try again.")
        }
        let storage = Storage.storage()
        let storageRef = storage.reference()

        switch media.type {
        case .image:
            let rawData = try Data(contentsOf: media.url)
            let imageData: Data
            if let uiImage = UIImage(data: rawData), let compressed = uiImage.jpegData(compressionQuality: 0.8) {
                imageData = compressed
            } else {
                imageData = rawData
            }
            let path = "stories/\(userId)/\(UUID().uuidString).jpg"
            let ref = storageRef.child(path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString

        case .video:
            let path = "stories/\(userId)/\(UUID().uuidString).mp4"
            let ref = storageRef.child(path)
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            _ = try await ref.putFileAsync(from: media.url, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        }
        #else
        throw StoryError.processingFailed("Firebase Storage not available")
        #endif
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