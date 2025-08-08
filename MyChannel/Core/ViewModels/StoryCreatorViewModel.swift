//
//  StoryCreatorViewModel.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

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
    
    // Mock upload methods - replace with actual implementation
    private func uploadImage(_ image: UIImage) async -> String? {
        // Simulate upload delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock URL
        return "https://your-cdn.com/images/\(UUID().uuidString).jpg"
    }
    
    private func uploadVideo(_ videoURL: URL) async -> String? {
        // Simulate upload delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Return mock URL
        return "https://your-cdn.com/videos/\(UUID().uuidString).mp4"
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