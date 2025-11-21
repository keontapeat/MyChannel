//
//  StoryCreatorViewModel.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class StoryCreatorViewModel: ObservableObject {
    @Published var contentItems: [StoryContentItem] = []
    @Published var selectedMusic: StoryMusic?
    @Published var stickers: [StorySticker] = []
    @Published var polls: [StoryPoll] = []
    @Published var links: [StoryLink] = []
    @Published var isProcessing: Bool = false
    @Published var processingMessage: String = ""
    
    var hasContent: Bool {
        !contentItems.isEmpty
    }
    
    var estimatedDuration: TimeInterval {
        contentItems.reduce(0) { $0 + $1.duration }
    }
    
    struct StoryContentItem: Identifiable {
        let id = UUID()
        let type: ContentType
        let data: Any
        let duration: TimeInterval
        let thumbnail: UIImage?
        let createdAt: Date = Date()
        
        enum ContentType {
            case image(UIImage)
            case video(URL)
            case music(StoryMusic)
        }
    }
    
    // MARK: - Content Addition Methods
    
    func addImageContent(_ image: UIImage) {
        let item = StoryContentItem(
            type: .image(image),
            data: image,
            duration: 15.0,
            thumbnail: image
        )
        
        withAnimation(.spring()) {
            contentItems.append(item)
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func addVideoContent(_ videoURL: URL, duration: TimeInterval) {
        generateThumbnail(from: videoURL) { [weak self] thumbnail in
            guard let self = self else { return }
            
            let item = StoryContentItem(
                type: .video(videoURL),
                data: videoURL,
                duration: min(duration, 60.0), // Max 60 seconds
                thumbnail: thumbnail
            )
            
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.contentItems.append(item)
                }
                
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    func addMusicContent(_ music: StoryMusic) {
        selectedMusic = music
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func addPhotosFromGallery(_ photos: [PhotosPickerItem]) {
        isProcessing = true
        processingMessage = "Processing photos..."
        
        Task {
            for photo in photos {
                await processPhotoItem(photo)
            }
            
            await MainActor.run {
                isProcessing = false
                processingMessage = ""
            }
        }
    }
    
    private func processPhotoItem(_ item: PhotosPickerItem) async {
        if item.supportedContentTypes.contains(.image) {
            // Process image
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    addImageContent(image)
                }
            }
        } else if item.supportedContentTypes.contains(.movie) {
            // Process video
            if let data = try? await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                try? data.write(to: tempURL)
                
                let asset = AVAsset(url: tempURL)
                let duration = CMTimeGetSeconds(asset.duration)
                
                await MainActor.run {
                    addVideoContent(tempURL, duration: duration)
                }
            }
        }
    }
    
    // MARK: - Content Management
    
    func removeContent(at index: Int) {
        guard index < contentItems.count else { return }
        
        withAnimation(.spring()) {
            contentItems.remove(at: index)
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func moveContent(from source: IndexSet, to destination: Int) {
        withAnimation(.spring()) {
            contentItems.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    func clearAll() {
        withAnimation(.spring()) {
            contentItems.removeAll()
            selectedMusic = nil
            stickers.removeAll()
            polls.removeAll()
            links.removeAll()
        }
    }
    
    // MARK: - Sticker Management
    
    func addSticker(_ sticker: StorySticker) {
        withAnimation(.spring()) {
            stickers.append(sticker)
        }
    }
    
    func removeSticker(_ sticker: StorySticker) {
        withAnimation(.spring()) {
            stickers.removeAll { $0.id == sticker.id }
        }
    }
    
    // MARK: - Poll Management
    
    func addPoll(_ poll: StoryPoll) {
        withAnimation(.spring()) {
            polls.append(poll)
        }
    }
    
    func removePoll(_ poll: StoryPoll) {
        withAnimation(.spring()) {
            polls.removeAll { $0.id == poll.id }
        }
    }
    
    // MARK: - Link Management
    
    func addLink(_ link: StoryLink) {
        withAnimation(.spring()) {
            links.append(link)
        }
    }
    
    func removeLink(_ link: StoryLink) {
        withAnimation(.spring()) {
            links.removeAll { $0.id == link.id }
        }
    }
    
    // MARK: - Story Creation
    
    func createStory(for user: User) async -> Story? {
        guard hasContent else { return nil }
        
        isProcessing = true
        processingMessage = "Creating your story..."
        
        // Convert content items to story content
        var storyContent: [StoryContent] = []
        
        for item in contentItems {
            switch item.type {
            case .image(let image):
                if let imageURL = await uploadImage(image) {
                    let content = StoryContent(
                        url: imageURL,
                        type: .image,
                        duration: item.duration
                    )
                    storyContent.append(content)
                }
                
            case .video(let url):
                if let videoURL = await uploadVideo(url) {
                    let content = StoryContent(
                        url: videoURL,
                        type: .video,
                        duration: item.duration
                    )
                    storyContent.append(content)
                }
                
            case .music(_):
                // Music is handled separately
                break
            }
        }
        
        let story = Story(
            creatorId: user.id,
            mediaURL: storyContent.first?.url ?? "",
            mediaType: storyContent.first?.type ?? .image,
            duration: estimatedDuration,
            content: storyContent,
            music: selectedMusic,
            stickers: stickers,
            polls: polls,
            links: links
        )
        
        await MainActor.run {
            isProcessing = false
            processingMessage = ""
        }
        
        return story
    }
    
    // MARK: - Story Publishing (PRODUCTION)
    
    func createAndPublishStory(for user: User, caption: String? = nil, audience: String = "public") async throws -> Story {
        guard hasContent else {
            throw StoryError.noContent
        }
        
        await MainActor.run {
            isProcessing = true
            processingMessage = "Creating your story..."
        }
        
        // 1. Upload all media to Firebase Storage
        var uploadedContent: [StoryContent] = []
        
        for (index, item) in contentItems.enumerated() {
            await MainActor.run {
                processingMessage = "Uploading item \(index + 1) of \(contentItems.count)..."
            }
            
            switch item.type {
            case .image(let image):
                if let imageURL = await uploadImage(image) {
                    uploadedContent.append(StoryContent(
                        url: imageURL,
                        type: .image,
                        duration: item.duration,
                        text: nil,
                        backgroundColor: nil
                    ))
                }
                
            case .video(let url):
                if let videoURL = await uploadVideo(url) {
                    uploadedContent.append(StoryContent(
                        url: videoURL,
                        type: .video,
                        duration: item.duration,
                        text: nil,
                        backgroundColor: nil
                    ))
                }
                
            case .music(_):
                // Music handled separately
                break
            }
        }
        
        guard !uploadedContent.isEmpty else {
            await MainActor.run {
                isProcessing = false
                processingMessage = ""
            }
            throw StoryError.uploadFailed
        }
        
        // 2. Create story via API
        await MainActor.run {
            processingMessage = "Publishing story..."
        }
        
        do {
            let story = try await StoryAPIService.shared.createStory(
                mediaUrl: uploadedContent.first!.url,
                mediaType: uploadedContent.first!.type,
                duration: estimatedDuration,
                caption: caption,
                text: nil,
                backgroundColor: nil,
                textColor: nil,
                music: selectedMusic,
                stickers: stickers,
                audience: audience
            )
            
            // 3. Save to Firestore directly as backup
            #if canImport(FirebaseFirestore)
            try await saveStoryToFirestore(story)
            #endif
            
            await MainActor.run {
                isProcessing = false
                processingMessage = ""
            }
            
            print("✅ Story created & published: \(story.id)")
            return story
            
        } catch {
            await MainActor.run {
                isProcessing = false
                processingMessage = ""
            }
            print("🚨 Failed to create story: \(error)")
            throw StoryError.apiError(error)
        }
    }
    
    // Save story to Firestore
    private func saveStoryToFirestore(_ story: Story) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let storyData: [String: Any] = [
            "id": story.id,
            "creatorId": story.creatorId,
            "mediaURL": story.mediaURL,
            "mediaType": story.mediaType.rawValue,
            "duration": story.duration,
            "caption": story.caption ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: story.expiresAt),
            "viewCount": 0,
            "isLive": false
        ]
        
        try await db.collection("stories").document(story.id).setData(storyData)
        print("✅ Story saved to Firestore: \(story.id)")
        #endif
    }
    
    enum StoryError: LocalizedError {
        case noContent
        case uploadFailed
        case apiError(Error)
        
        var errorDescription: String? {
            switch self {
            case .noContent:
                return "No content to upload. Please add photos or videos."
            case .uploadFailed:
                return "Failed to upload media. Please try again."
            case .apiError(let error):
                return "Story creation failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateThumbnail(from videoURL: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 60)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                completion(thumbnail)
            }
        } catch {
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    // MARK: - Firebase Storage Upload (PRODUCTION)
    
    private func uploadImage(_ image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("🚨 Failed to convert image to JPEG")
            return nil
        }
        
        #if canImport(FirebaseStorage)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🚨 No authenticated user")
            return nil
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imagePath = "stories/\(userId)/\(UUID().uuidString).jpg"
        let imageRef = storageRef.child(imagePath)
        
        do {
            // Upload with metadata
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            metadata.customMetadata = [
                "uploadedBy": userId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date()),
                "type": "story"
            ]
            
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            
            print("✅ Story image uploaded: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("🚨 Story image upload error: \(error)")
            return nil
        }
        #else
        // Fallback for simulator/testing
        print("⚠️ Firebase Storage not available - using mock URL")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return "https://your-cdn.com/images/\(UUID().uuidString).jpg"
        #endif
    }
    
    private func uploadVideo(_ videoURL: URL) async -> String? {
        #if canImport(FirebaseStorage)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🚨 No authenticated user")
            return nil
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let videoPath = "stories/\(userId)/\(UUID().uuidString).mp4"
        let videoRef = storageRef.child(videoPath)
        
        do {
            // Upload with metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "uploadedBy": userId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date()),
                "type": "story"
            ]
            
            _ = try await videoRef.putFileAsync(from: videoURL, metadata: metadata)
            let downloadURL = try await videoRef.downloadURL()
            
            print("✅ Story video uploaded: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("🚨 Story video upload error: \(error)")
            return nil
        }
        #else
        // Fallback for simulator/testing
        print("⚠️ Firebase Storage not available - using mock URL")
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return "https://your-cdn.com/videos/\(UUID().uuidString).mp4"
        #endif
    }
}

// MARK: - Color Extension
extension Color {
    func toHexString() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}