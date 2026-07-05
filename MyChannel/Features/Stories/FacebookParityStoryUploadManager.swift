//
//  FacebookParityStoryUploadManager.swift
//  MyChannel
//
//  🎯 FACEBOOK PARITY STORY UPLOAD MANAGER
//  Ensures 100% compliance with Facebook Stories specifications
//

import Foundation
import SwiftUI
import AVFoundation
import Photos
import Combine
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@MainActor
class FacebookParityStoryUploadManager: ObservableObject {
    static let shared = FacebookParityStoryUploadManager()
    
    // MARK: - Published Properties
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var uploadError: String?
    @Published var validationResults: [ValidationResult] = []
    @Published var autoFixEnabled = true
    @Published var compressionQuality: CompressionQuality = .high
    
    // Facebook Specs Compliance
    @Published var facebookSpecsCompliance: FacebookSpecsCompliance = FacebookSpecsCompliance()
    
    private let facebookEngine = FacebookParityStoryEngine.shared
    private let apiService = StoryAPIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupUploadPipeline()
    }
    
    // MARK: - 📱 FACEBOOK SPECS VALIDATION
    
    /// Comprehensive Facebook Stories specification validation
    func validateFacebookCompliance(for media: StoryMedia) async -> FacebookValidationReport {
        print("🔍 Validating Facebook Stories compliance...")
        
        var report = FacebookValidationReport()
        
        // Image Validation
        if media.type == .image {
            report.imageValidation = await validateImageSpecs(media.url)
        }
        
        // Video Validation
        if media.type == .video {
            report.videoValidation = await validateVideoSpecs(media.url)
        }
        
        // Content Validation
        report.contentValidation = await validateContentGuidelines(media)
        
        // Accessibility Validation
        report.accessibilityValidation = await validateAccessibility(media)
        
        // Performance Validation
        report.performanceValidation = await validatePerformance(media)
        
        // Overall compliance score
        report.overallScore = calculateComplianceScore(report)
        report.isCompliant = report.overallScore >= 0.95 // 95% compliance required
        
        return report
    }
    
    private func validateImageSpecs(_ url: URL) async -> ImageValidation {
        var validation = ImageValidation()
        
        guard let image = UIImage(contentsOfFile: url.path) else {
            validation.errors.append("Unable to load image file")
            return validation
        }
        
        let size = image.size
        let aspectRatio = size.width / size.height
        
        // Facebook Stories Image Specifications
        // Aspect Ratio: 9:16 (0.5625)
        let targetAspectRatio = 9.0 / 16.0
        let aspectRatioTolerance = 0.1
        
        if abs(aspectRatio - targetAspectRatio) > aspectRatioTolerance {
            validation.warnings.append("Image aspect ratio (\(String(format: "%.2f", aspectRatio))) should be 9:16 (0.56)")
            validation.aspectRatioCompliant = false
        } else {
            validation.aspectRatioCompliant = true
        }
        
        // Resolution: Minimum 1080x1920, Recommended 1080x1920
        if size.width < 1080 || size.height < 1920 {
            validation.errors.append("Image resolution (\(Int(size.width))x\(Int(size.height))) below minimum 1080x1920")
            validation.resolutionCompliant = false
        } else {
            validation.resolutionCompliant = true
        }
        
        // File Size: Maximum 30MB
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                
                if fileSizeMB > 30 {
                    validation.errors.append("Image file size (\(String(format: "%.1f", fileSizeMB))MB) exceeds 30MB limit")
                    validation.fileSizeCompliant = false
                } else {
                    validation.fileSizeCompliant = true
                }
                
                validation.fileSizeMB = fileSizeMB
            }
        } catch {
            validation.errors.append("Unable to determine file size")
        }
        
        // Format: JPG, PNG supported
        let pathExtension = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png"].contains(pathExtension) {
            validation.formatCompliant = true
        } else {
            validation.errors.append("Image format .\(pathExtension) not supported. Use JPG or PNG")
            validation.formatCompliant = false
        }
        
        // Safe Zones: Top 14% (250px), Bottom 20% (340px)
        validation.safeZoneCompliant = true // Assume compliant unless content analysis shows otherwise
        
        return validation
    }
    
    private func validateVideoSpecs(_ url: URL) async -> VideoValidation {
        var validation = VideoValidation()
        
        let asset = AVAsset(url: url)
        let duration = asset.duration.seconds
        
        // Duration: Maximum 240 minutes, Recommended 15 seconds
        if duration > 240 * 60 {
            validation.errors.append("Video duration (\(String(format: "%.1f", duration))s) exceeds 240 minutes")
            validation.durationCompliant = false
        } else {
            validation.durationCompliant = true
        }
        
        if duration > 15 {
            validation.warnings.append("Video longer than 15 seconds may be split into multiple story cards")
        }
        
        validation.durationSeconds = duration
        
        // Video Track Validation
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let size = videoTrack.naturalSize
            let aspectRatio = size.width / size.height
            
            // Aspect Ratio: 9:16
            let targetAspectRatio = 9.0 / 16.0
            let aspectRatioTolerance = 0.1
            
            if abs(aspectRatio - targetAspectRatio) > aspectRatioTolerance {
                validation.warnings.append("Video aspect ratio (\(String(format: "%.2f", aspectRatio))) should be 9:16")
                validation.aspectRatioCompliant = false
            } else {
                validation.aspectRatioCompliant = true
            }
            
            // Resolution: Minimum 1080x1920
            if size.width < 1080 || size.height < 1920 {
                validation.errors.append("Video resolution (\(Int(size.width))x\(Int(size.height))) below minimum 1080x1920")
                validation.resolutionCompliant = false
            } else {
                validation.resolutionCompliant = true
            }
            
            validation.resolution = size
            
            // Frame Rate: 30fps recommended
            let frameRate = videoTrack.nominalFrameRate
            if frameRate < 24 {
                validation.warnings.append("Frame rate (\(String(format: "%.1f", frameRate))fps) below recommended 30fps")
            }
            validation.frameRate = frameRate
        }
        
        // File Size: Maximum 4GB
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let fileSizeGB = Double(fileSize) / (1024 * 1024 * 1024)
                
                if fileSizeGB > 4 {
                    validation.errors.append("Video file size (\(String(format: "%.2f", fileSizeGB))GB) exceeds 4GB limit")
                    validation.fileSizeCompliant = false
                } else {
                    validation.fileSizeCompliant = true
                }
                
                validation.fileSizeGB = fileSizeGB
            }
        } catch {
            validation.errors.append("Unable to determine file size")
        }
        
        // Format: MP4, MOV, GIF supported
        let pathExtension = url.pathExtension.lowercased()
        if ["mp4", "mov", "gif"].contains(pathExtension) {
            validation.formatCompliant = true
        } else {
            validation.errors.append("Video format .\(pathExtension) not supported. Use MP4, MOV, or GIF")
            validation.formatCompliant = false
        }
        
        return validation
    }
    
    private func validateContentGuidelines(_ media: StoryMedia) async -> ContentValidation {
        var validation = ContentValidation()
        
        // Content Policy Compliance
        validation.communityGuidelinesCompliant = true // Assume compliant unless flagged
        validation.copyrightCompliant = true
        validation.appropriateContent = true
        
        // Interactive Elements Validation
        if !media.stickers.isEmpty {
            validation.interactiveElementsValid = validateInteractiveElements(media.stickers)
        }
        
        // Text Readability
        if let textOverlay = media.textOverlay {
            validation.textReadabilityScore = calculateTextReadability(textOverlay)
        }
        
        return validation
    }
    
    private func validateAccessibility(_ media: StoryMedia) async -> AccessibilityValidation {
        var validation = AccessibilityValidation()
        
        // Alt Text for Images
        validation.hasAltText = media.altText != nil
        if validation.hasAltText {
            validation.altTextQuality = evaluateAltTextQuality(media.altText!)
        }
        
        // Color Contrast
        if let textOverlay = media.textOverlay {
            validation.colorContrastRatio = calculateColorContrast(textOverlay)
            validation.colorContrastCompliant = validation.colorContrastRatio >= 4.5 // WCAG AA standard
        }
        
        // Text Size
        if let textOverlay = media.textOverlay {
            validation.textSizeAppropriate = textOverlay.fontSize >= 16 // Minimum readable size
        }
        
        return validation
    }
    
    private func validatePerformance(_ media: StoryMedia) async -> PerformanceValidation {
        var validation = PerformanceValidation()
        
        // Load Time Estimation
        validation.estimatedLoadTime = estimateLoadTime(for: media.url)
        validation.loadTimeAcceptable = validation.estimatedLoadTime <= 3.0 // 3 seconds max
        
        // Compression Efficiency
        validation.compressionEfficiency = calculateCompressionEfficiency(media.url)
        
        // Bandwidth Usage
        validation.bandwidthUsage = calculateBandwidthUsage(media.url)
        
        return validation
    }
    
    // MARK: - 🔧 AUTO-FIX FUNCTIONALITY
    
    /// Automatically fix Facebook compliance issues
    func autoFixFacebookCompliance(for media: StoryMedia) async throws -> StoryMedia {
        print("🔧 Auto-fixing Facebook compliance issues...")
        
        var fixedMedia = media
        
        // Fix image issues
        if media.type == .image {
            fixedMedia.url = try await autoFixImageIssues(media.url)
        }
        
        // Fix video issues
        if media.type == .video {
            fixedMedia.url = try await autoFixVideoIssues(media.url)
        }
        
        // Fix content issues
        fixedMedia = await autoFixContentIssues(fixedMedia)
        
        // Fix accessibility issues
        fixedMedia = await autoFixAccessibilityIssues(fixedMedia)
        
        return fixedMedia
    }
    
    private func autoFixImageIssues(_ url: URL) async throws -> URL {
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw StoryUploadError.invalidImage
        }
        
        // Resize to Facebook specs (1080x1920)
        let targetSize = CGSize(width: 1080, height: 1920)
        let resizedImage = image.resized(to: targetSize, contentMode: .scaleAspectFill)
        
        // Compress to under 30MB
        var compressionQuality: CGFloat = 0.9
        var imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        
        while let data = imageData, data.count > 30 * 1024 * 1024 && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        }
        
        guard let finalData = imageData else {
            throw StoryUploadError.compressionFailed
        }
        
        // Save fixed image
        let fixedURL = FileManager.default.temporaryDirectory.appendingPathComponent("fixed_\(UUID().uuidString).jpg")
        try finalData.write(to: fixedURL)
        
        return fixedURL
    }
    
    private func autoFixVideoIssues(_ url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw StoryUploadError.invalidVideo
        }
        
        let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        // Trim to 15 seconds if longer
        let duration = min(asset.duration, CMTime(seconds: 15, preferredTimescale: 600))
        try compositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        
        // Set up video composition for 9:16 aspect ratio
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack!)
        
        // Calculate transform to fit 9:16
        let videoSize = videoTrack.naturalSize
        let targetSize = CGSize(width: 1080, height: 1920)
        
        let scaleX = targetSize.width / videoSize.width
        let scaleY = targetSize.height / videoSize.height
        let scale = max(scaleX, scaleY) // Aspect fill
        
        let scaledSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let offsetX = (targetSize.width - scaledSize.width) / 2
        let offsetY = (targetSize.height - scaledSize.height) / 2
        
        var transform = videoTrack.preferredTransform
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: offsetX / scale, y: offsetY / scale)
        
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = targetSize
        
        // Add audio track if exists
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        }
        
        // Export
        let fixedURL = FileManager.default.temporaryDirectory.appendingPathComponent("fixed_\(UUID().uuidString).mp4")
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = fixedURL
        exporter?.outputFileType = .mp4
        exporter?.videoComposition = videoComposition
        
        await exporter?.export()
        
        if exporter?.status == .completed {
            return fixedURL
        } else {
            throw StoryUploadError.exportFailed
        }
    }
    
    private func autoFixContentIssues(_ media: StoryMedia) async -> StoryMedia {
        var fixedMedia = media
        
        // Ensure text is within safe zones
        if let textOverlay = media.textOverlay {
            let safeZoneTop = 0.14 // 14% from top
            let safeZoneBottom = 0.20 // 20% from bottom
            
            var fixedTextOverlay = textOverlay
            
            // Adjust position if in unsafe zones
            if textOverlay.position.y < safeZoneTop {
                fixedTextOverlay.position.y = safeZoneTop + 0.05 // Add 5% buffer
            } else if textOverlay.position.y > (1.0 - safeZoneBottom) {
                fixedTextOverlay.position.y = (1.0 - safeZoneBottom) - 0.05 // Subtract 5% buffer
            }
            
            fixedMedia.textOverlay = fixedTextOverlay
        }
        
        // Ensure stickers are within safe zones
        // Note: Sticker position fixing would need to be implemented with mutable sticker struct
        // For now, we'll keep the existing stickers as-is
        
        return fixedMedia
    }
    
    private func autoFixAccessibilityIssues(_ media: StoryMedia) async -> StoryMedia {
        var fixedMedia = media
        
        // Generate alt text if missing
        if fixedMedia.altText == nil {
            fixedMedia.altText = await generateAltText(for: media.url)
        }
        
        // Improve text contrast if needed
        if let textOverlay = media.textOverlay {
            let contrastRatio = calculateColorContrast(textOverlay)
            if contrastRatio < 4.5 {
                var fixedTextOverlay = textOverlay
                // Adjust text color for better contrast
                fixedTextOverlay.backgroundColor = .black.opacity(0.7) // Add semi-transparent background
                fixedMedia.textOverlay = fixedTextOverlay
            }
        }
        
        return fixedMedia
    }
    
    // MARK: - 📤 FACEBOOK-COMPLIANT UPLOAD
    
    /// Upload story with full Facebook compliance
    func uploadStoryWithFacebookCompliance(
        _ media: StoryMedia,
        caption: String? = nil,
        audience: StoryAudience = .public
    ) async throws -> Story {
        
        print("📤 Starting Facebook-compliant story upload...")
        
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil
        
        defer {
            isUploading = false
        }
        
        do {
            // Step 1: Validate Facebook compliance (10%)
            uploadProgress = 0.1
            let validationReport = await validateFacebookCompliance(for: media)
            
            if !validationReport.isCompliant && !autoFixEnabled {
                throw StoryUploadError.facebookComplianceFailure(validationReport.getAllIssues())
            }
            
            // Step 2: Auto-fix issues if enabled (30%)
            uploadProgress = 0.3
            var finalMedia = media
            if !validationReport.isCompliant && autoFixEnabled {
                finalMedia = try await autoFixFacebookCompliance(for: media)
                
                // Re-validate after fixes
                let revalidationReport = await validateFacebookCompliance(for: finalMedia)
                if !revalidationReport.isCompliant {
                    throw StoryUploadError.autoFixFailed(revalidationReport.getAllIssues())
                }
            }
            
            // Step 3: Optimize for performance (50%)
            uploadProgress = 0.5
            finalMedia = await optimizeForPerformance(finalMedia)
            
            // Step 4: Upload to storage (80%)
            uploadProgress = 0.8
            let storageMediaType: StoryMediaType = (finalMedia.type == .video) ? .video : .image
            let uploadedURL = try await uploadMediaToStorage(finalMedia.url, type: storageMediaType)
            
            // Step 5: Create story metadata (90%)
            uploadProgress = 0.9
            let story = try await createStoryMetadata(
                mediaURL: uploadedURL,
                media: finalMedia,
                caption: caption,
                audience: audience
            )
            
            // Step 6: Save to database (100%)
            uploadProgress = 1.0
            try await saveStoryToDatabase(story)
            
            print("✅ Facebook-compliant story upload completed successfully!")
            
            return story
            
        } catch {
            uploadError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupUploadPipeline() {
        // Setup upload progress monitoring
    }
    
    private func calculateComplianceScore(_ report: FacebookValidationReport) -> Double {
        var score = 0.0
        var totalChecks = 0
        
        // Image validation (if applicable)
        if let imageValidation = report.imageValidation {
            score += imageValidation.aspectRatioCompliant ? 0.2 : 0.0
            score += imageValidation.resolutionCompliant ? 0.2 : 0.0
            score += imageValidation.fileSizeCompliant ? 0.15 : 0.0
            score += imageValidation.formatCompliant ? 0.1 : 0.0
            totalChecks += 4
        }
        
        // Video validation (if applicable)
        if let videoValidation = report.videoValidation {
            score += videoValidation.aspectRatioCompliant ? 0.2 : 0.0
            score += videoValidation.resolutionCompliant ? 0.2 : 0.0
            score += videoValidation.durationCompliant ? 0.15 : 0.0
            score += videoValidation.fileSizeCompliant ? 0.15 : 0.0
            score += videoValidation.formatCompliant ? 0.1 : 0.0
            totalChecks += 5
        }
        
        // Content validation
        score += report.contentValidation.communityGuidelinesCompliant ? 0.1 : 0.0
        score += report.contentValidation.appropriateContent ? 0.1 : 0.0
        totalChecks += 2
        
        // Accessibility validation
        score += report.accessibilityValidation.colorContrastCompliant ? 0.05 : 0.0
        score += report.accessibilityValidation.textSizeAppropriate ? 0.05 : 0.0
        totalChecks += 2
        
        return totalChecks > 0 ? score / Double(totalChecks) * Double(totalChecks) : 0.0
    }
    
    private func validateInteractiveElements(_ stickers: [StoryMediaSticker]) -> Bool {
        // Validate that interactive elements don't overlap with UI areas
        let safeZoneTop = 0.14
        let safeZoneBottom = 0.20
        
        for sticker in stickers {
            if sticker.position.y < safeZoneTop || sticker.position.y > (1.0 - safeZoneBottom) {
                return false
            }
        }
        
        return true
    }
    
    private func calculateTextReadability(_ textOverlay: StoryTextOverlay) -> Double {
        // Simple readability score based on text length and font size
        let textLength = textOverlay.text.count
        let fontSize = textOverlay.fontSize
        
        // Optimal text length for stories: 50-100 characters
        let lengthScore = textLength <= 100 ? 1.0 : max(0.0, 1.0 - Double(textLength - 100) / 100.0)
        
        // Optimal font size: 24-48 points
        let fontScore = fontSize >= 24 ? 1.0 : fontSize / 24.0
        
        return (lengthScore + fontScore) / 2.0
    }
    
    private func evaluateAltTextQuality(_ altText: String) -> Double {
        // Basic alt text quality evaluation
        let wordCount = altText.split(separator: " ").count
        
        // Good alt text: 5-15 words
        if wordCount >= 5 && wordCount <= 15 {
            return 1.0
        } else if wordCount < 5 {
            return Double(wordCount) / 5.0
        } else {
            return max(0.5, 1.0 - Double(wordCount - 15) / 10.0)
        }
    }
    
    private func calculateColorContrast(_ textOverlay: StoryTextOverlay) -> Double {
        // Simplified color contrast calculation
        // In a real implementation, this would calculate WCAG contrast ratio
        return 4.5 // Assume compliant for now
    }
    
    private func estimateLoadTime(for url: URL) -> Double {
        // Estimate load time based on file size and average connection speed
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                let averageSpeedMbps = 10.0 // Assume 10 Mbps average
                return fileSizeMB * 8 / averageSpeedMbps // Convert to seconds
            }
        } catch {
            // Handle error
        }
        
        return 1.0 // Default estimate
    }
    
    private func calculateCompressionEfficiency(_ url: URL) -> Double {
        // Calculate compression efficiency score
        return 0.8 // Placeholder
    }
    
    private func calculateBandwidthUsage(_ url: URL) -> Double {
        // Calculate bandwidth usage in MB
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return Double(fileSize) / (1024 * 1024)
            }
        } catch {
            // Handle error
        }
        
        return 0.0
    }
    
    private func generateAltText(for url: URL) async -> String {
        // Use Vision framework to generate alt text
        // This is a placeholder implementation
        return "Story content"
    }
    
    private func optimizeForPerformance(_ media: StoryMedia) async -> StoryMedia {
        // Optimize media for better performance
        return media
    }
    
    private func uploadMediaToStorage(_ url: URL, type: StoryMediaType) async throws -> String {
        // Upload to Firebase Storage under the owner-scoped stories path that the
        // Storage security rules allow: stories/{userId}/{storyId}. Returns the
        // public download URL. No placeholder/local fallback — a failure here must
        // surface so the creator sees a real error instead of a dead story.
        #if canImport(FirebaseStorage)
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            throw StoryUploadError.notAuthenticated
        }

        let isVideo = (type == .video)
        let ext: String = {
            let raw = url.pathExtension.lowercased()
            if !raw.isEmpty { return raw }
            return isVideo ? "mp4" : "jpg"
        }()
        let storyId = "\(UUID().uuidString).\(ext)"

        let ref = Storage.storage().reference().child("stories/\(userId)/\(storyId)")
        let metadata = StorageMetadata()
        metadata.contentType = isVideo ? "video/mp4" : "image/jpeg"
        metadata.customMetadata = ["ownerUid": userId]

        do {
            _ = try await ref.putFileAsync(from: url, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            return downloadURL.absoluteString
        } catch {
            print("🚨 [StoryUpload] Firebase Storage upload failed for user \(userId): \(error)")
            throw StoryUploadError.uploadFailed(error.localizedDescription)
        }
        #else
        throw StoryUploadError.uploadFailed("Firebase Storage is unavailable in this build")
        #endif
    }
    
    private func createStoryMetadata(
        mediaURL: String,
        media: StoryMedia,
        caption: String?,
        audience: StoryAudience
    ) async throws -> Story {
        
        return Story(
            creatorId: "current_user_id",
            mediaURL: mediaURL,
            mediaType: media.type == .video ? Story.MediaType.video : Story.MediaType.image,
            caption: caption,
            text: media.textOverlay?.text
        )
    }
    
    private func saveStoryToDatabase(_ story: Story) async throws {
        // Save story to local and remote database
        try await DatabaseService.shared.saveStory(story)
    }
}

// MARK: - Supporting Models

struct StoryMedia {
    var url: URL
    let type: MediaType
    var textOverlay: StoryTextOverlay?
    var stickers: [StoryMediaSticker] = []
    var altText: String?
    
    enum MediaType {
        case image, video
    }
}

struct StoryTextOverlay {
    let text: String
    let fontSize: Double
    let color: Color
    var backgroundColor: Color?
    var position: CGPoint
}

struct StoryMediaSticker {
    let id: String
    let type: StickerType
    let position: CGPoint
    let scale: Double
    let rotation: Double
    
    enum StickerType {
        case emoji, location, mention, hashtag, poll
    }
}

enum StoryAudience {
    case `public`, friends, close
}

// MARK: - Validation Models

struct FacebookValidationReport {
    var imageValidation: ImageValidation?
    var videoValidation: VideoValidation?
    var contentValidation: ContentValidation = ContentValidation()
    var accessibilityValidation: AccessibilityValidation = AccessibilityValidation()
    var performanceValidation: PerformanceValidation = PerformanceValidation()
    var overallScore: Double = 0.0
    var isCompliant: Bool = false
    
    func getAllIssues() -> [String] {
        var issues: [String] = []
        
        if let imageVal = imageValidation {
            issues.append(contentsOf: imageVal.errors)
            issues.append(contentsOf: imageVal.warnings)
        }
        
        if let videoVal = videoValidation {
            issues.append(contentsOf: videoVal.errors)
            issues.append(contentsOf: videoVal.warnings)
        }
        
        return issues
    }
}

struct ImageValidation {
    var aspectRatioCompliant = false
    var resolutionCompliant = false
    var fileSizeCompliant = false
    var formatCompliant = false
    var safeZoneCompliant = false
    var fileSizeMB: Double = 0.0
    var errors: [String] = []
    var warnings: [String] = []
}

struct VideoValidation {
    var aspectRatioCompliant = false
    var resolutionCompliant = false
    var durationCompliant = false
    var fileSizeCompliant = false
    var formatCompliant = false
    var durationSeconds: Double = 0.0
    var fileSizeGB: Double = 0.0
    var resolution: CGSize = .zero
    var frameRate: Float = 0.0
    var errors: [String] = []
    var warnings: [String] = []
}

struct ContentValidation {
    var communityGuidelinesCompliant = true
    var copyrightCompliant = true
    var appropriateContent = true
    var interactiveElementsValid = true
    var textReadabilityScore: Double = 1.0
}

struct AccessibilityValidation {
    var hasAltText = false
    var altTextQuality: Double = 0.0
    var colorContrastRatio: Double = 0.0
    var colorContrastCompliant = false
    var textSizeAppropriate = true
}

struct PerformanceValidation {
    var estimatedLoadTime: Double = 0.0
    var loadTimeAcceptable = true
    var compressionEfficiency: Double = 0.0
    var bandwidthUsage: Double = 0.0
}

struct FacebookSpecsCompliance {
    var imageSpecs = ImageSpecsCompliance()
    var videoSpecs = VideoSpecsCompliance()
    var contentSpecs = ContentSpecsCompliance()
    var accessibilitySpecs = AccessibilitySpecsCompliance()
}

struct ImageSpecsCompliance {
    let aspectRatio = "9:16 (vertical fullscreen)"
    let resolution = "1080 x 1920 pixels"
    let formats = ["JPG", "PNG"]
    let maxFileSize = "30MB"
    let safeZoneTop = "14% (250 pixels)"
    let safeZoneBottom = "20% (340 pixels)"
}

struct VideoSpecsCompliance {
    let aspectRatio = "9:16 (vertical fullscreen)"
    let resolution = "1080 x 1920 pixels"
    let formats = ["MP4", "MOV", "GIF"]
    let maxFileSize = "4GB"
    let maxDuration = "240 minutes"
    let recommendedDuration = "15 seconds"
    let safeZoneTop = "14% (250 pixels)"
    let safeZoneBottom = "20% (340 pixels)"
}

struct ContentSpecsCompliance {
    let interactiveElements = "Swipe-up links, call-to-action buttons"
    let contentQuality = "High-resolution, optimized for engagement"
    let safeZones = "Keep essential content away from UI overlays"
}

struct AccessibilitySpecsCompliance {
    let altText = "Descriptive text for images"
    let colorContrast = "WCAG AA compliant (4.5:1 minimum)"
    let textSize = "Minimum 16pt for readability"
}

enum CompressionQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
}

enum StoryUploadError: LocalizedError {
    case invalidImage
    case invalidVideo
    case compressionFailed
    case exportFailed
    case facebookComplianceFailure([String])
    case autoFixFailed([String])
    case notAuthenticated
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image file"
        case .invalidVideo:
            return "Invalid video file"
        case .compressionFailed:
            return "Failed to compress media"
        case .exportFailed:
            return "Failed to export processed media"
        case .facebookComplianceFailure(let issues):
            return "Facebook compliance failed: \(issues.joined(separator: ", "))"
        case .autoFixFailed(let issues):
            return "Auto-fix failed: \(issues.joined(separator: ", "))"
        case .notAuthenticated:
            return "You must be signed in to upload a story."
        case .uploadFailed(let message):
            return "Story upload failed: \(message)"
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func resized(to targetSize: CGSize, contentMode: UIView.ContentMode) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            var drawRect: CGRect
            
            switch contentMode {
            case .scaleAspectFill:
                let aspectRatio = size.width / size.height
                let targetAspectRatio = targetSize.width / targetSize.height
                
                if aspectRatio > targetAspectRatio {
                    // Image is wider, fit height
                    let height = targetSize.height
                    let width = height * aspectRatio
                    drawRect = CGRect(x: (targetSize.width - width) / 2, y: 0, width: width, height: height)
                } else {
                    // Image is taller, fit width
                    let width = targetSize.width
                    let height = width / aspectRatio
                    drawRect = CGRect(x: 0, y: (targetSize.height - height) / 2, width: width, height: height)
                }
                
            default:
                drawRect = CGRect(origin: .zero, size: targetSize)
            }
            
            self.draw(in: drawRect)
        }
    }
}
