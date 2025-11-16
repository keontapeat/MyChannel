// 🔥 iOS VIDEO THUMBNAIL SERVICE - VIDEO PREVIEW & EXTRACTION 💣

import Foundation
import AVFoundation
import UIKit
import Combine

@MainActor
final class VideoThumbnailService: ObservableObject {
    static let shared = VideoThumbnailService()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var extractedFrames: [VideoFrame] = []
    
    private init() {}
    
    // MARK: - Video Frame Model
    
    struct VideoFrame: Identifiable {
        let id = UUID()
        let timestamp: TimeInterval
        let image: UIImage
        let width: CGFloat
        let height: CGFloat
    }
    
    // MARK: - Extract Single Frame
    
    func extractFrame(
        from videoURL: URL,
        at time: TimeInterval = 0
    ) async throws -> VideoFrame {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        do {
            let cgImage = try await imageGenerator.image(at: cmTime).image
            let image = UIImage(cgImage: cgImage)
            
            return VideoFrame(
                timestamp: time,
                image: image,
                width: image.size.width,
                height: image.size.height
            )
        } catch {
            print("🚨 [iOS] Failed to extract frame:", error)
            throw error
        }
    }
    
    // MARK: - Extract Multiple Frames
    
    func extractFrames(
        from videoURL: URL,
        count: Int = 10
    ) async throws -> [VideoFrame] {
        isProcessing = true
        progress = 0.0
        
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let interval = durationSeconds / Double(count)
        var frames: [VideoFrame] = []
        
        for i in 0..<count {
            let timestamp = Double(i) * interval
            
            do {
                let frame = try await extractFrame(from: videoURL, at: timestamp)
                frames.append(frame)
                
                progress = Double(i + 1) / Double(count)
                print("✅ [iOS] Extracted frame \(i + 1)/\(count)")
            } catch {
                print("🚨 [iOS] Failed to extract frame \(i + 1):", error)
            }
        }
        
        extractedFrames = frames
        return frames
    }
    
    // MARK: - Find Best Frame (Most Interesting)
    
    func findBestFrame(from videoURL: URL) async throws -> VideoFrame {
        // Extract 20 frames
        let frames = try await extractFrames(from: videoURL, count: 20)
        
        // Analyze each frame for "interestingness"
        var bestFrame: VideoFrame?
        var bestScore: Double = 0.0
        
        for frame in frames {
            let score = analyzeFrameInterest(frame.image)
            
            if score > bestScore {
                bestScore = score
                bestFrame = frame
            }
        }
        
        guard let best = bestFrame else {
            throw VideoThumbnailError.noFramesFound
        }
        
        print("✅ [iOS] Best frame found at \(best.timestamp)s with score \(bestScore)")
        return best
    }
    
    // MARK: - Analyze Frame Interest
    
    private func analyzeFrameInterest(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0.0
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.0 }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Calculate variance (higher = more interesting)
        var sum: Double = 0.0
        var sumSq: Double = 0.0
        let pixelCount = width * height
        
        for i in 0..<pixelCount {
            let offset = i * 4
            let r = Double(buffer[offset])
            let g = Double(buffer[offset + 1])
            let b = Double(buffer[offset + 2])
            
            let brightness = (r + g + b) / 3.0
            sum += brightness
            sumSq += brightness * brightness
        }
        
        let mean = sum / Double(pixelCount)
        let variance = (sumSq / Double(pixelCount)) - (mean * mean)
        
        return variance
    }
    
    // MARK: - Create Thumbnail with Overlay
    
    func createThumbnailWithOverlay(
        videoURL: URL,
        overlayText: String,
        at time: TimeInterval = 0
    ) async throws -> UIImage {
        let frame = try await extractFrame(from: videoURL, at: time)
        
        let size = CGSize(width: frame.width, height: frame.height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            throw VideoThumbnailError.renderFailed
        }
        
        // Draw video frame
        frame.image.draw(in: CGRect(origin: .zero, size: size))
        
        // Draw overlay
        let overlayHeight: CGFloat = 100
        let overlayRect = CGRect(
            x: 0,
            y: size.height - overlayHeight,
            width: size.width,
            height: overlayHeight
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(overlayRect)
        
        // Draw text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 48),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let textRect = CGRect(
            x: 20,
            y: size.height - 60,
            width: size.width - 40,
            height: 60
        )
        
        overlayText.draw(in: textRect, withAttributes: attributes)
        
        guard let resultImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw VideoThumbnailError.renderFailed
        }
        
        return resultImage
    }
    
    // MARK: - Batch Process Videos
    
    func batchProcessVideos(
        urls: [URL],
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> [(url: URL, thumbnail: UIImage)] {
        var results: [(url: URL, thumbnail: UIImage)] = []
        
        for (index, url) in urls.enumerated() {
            do {
                let frame = try await findBestFrame(from: url)
                results.append((url: url, thumbnail: frame.image))
                
                onProgress(index + 1, urls.count)
                print("✅ [iOS] Processed video \(index + 1)/\(urls.count)")
            } catch {
                print("🚨 [iOS] Failed to process video \(index + 1):", error)
            }
        }
        
        return results
    }
    
    // MARK: - Resize Thumbnail
    
    func resizeThumbnail(
        _ image: UIImage,
        to size: CGSize
    ) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - Export Formats
    
    func exportThumbnail(
        _ image: UIImage,
        format: ExportFormat = .png,
        quality: CGFloat = 0.95
    ) -> Data? {
        switch format {
        case .png:
            return image.pngData()
        case .jpg:
            return image.jpegData(compressionQuality: quality)
        }
    }
    
    enum ExportFormat {
        case png
        case jpg
    }
    
    // MARK: - Errors
    
    enum VideoThumbnailError: LocalizedError {
        case noFramesFound
        case renderFailed
        case exportFailed
        
        var errorDescription: String? {
            switch self {
            case .noFramesFound: return "No frames found in video"
            case .renderFailed: return "Failed to render thumbnail"
            case .exportFailed: return "Failed to export thumbnail"
            }
        }
    }
}


