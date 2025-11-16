//
//  GreenScreenEngine.swift
//  MyChannel
//
//  🎬 GREEN SCREEN ENGINE
//  Real-time background removal and replacement (like TikTok)
//

import SwiftUI
import CoreImage
import Vision
import AVFoundation

@MainActor
class GreenScreenEngine: ObservableObject {
    
    // MARK: - Published State
    @Published var isProcessing = false
    @Published var backgroundImage: UIImage?
    @Published var selectedBackground: BackgroundType = .blur
    @Published var maskQuality: MaskQuality = .high
    @Published var edgeFeathering: CGFloat = 5.0
    
    // Core Image context
    private let ciContext = CIContext()
    
    // Vision request
    private var segmentationRequest: VNGeneratePersonSegmentationRequest?
    
    // Available backgrounds
    let availableBackgrounds: [BackgroundOption] = [
        BackgroundOption(type: .blur, name: "Blur", icon: "circle.hexagongrid"),
        BackgroundOption(type: .color(.white), name: "White", icon: "square.fill"),
        BackgroundOption(type: .color(.black), name: "Black", icon: "square.fill"),
        BackgroundOption(type: .gradient([.purple, .pink]), name: "Gradient", icon: "square.split.2x2"),
        BackgroundOption(type: .image("beach"), name: "Beach", icon: "beach.umbrella"),
        BackgroundOption(type: .image("city"), name: "City", icon: "building.2"),
        BackgroundOption(type: .image("nature"), name: "Nature", icon: "tree"),
        BackgroundOption(type: .image("space"), name: "Space", icon: "sparkles"),
        BackgroundOption(type: .custom, name: "Custom", icon: "photo")
    ]
    
    enum BackgroundType: Equatable {
        case blur
        case color(Color)
        case gradient([Color])
        case image(String)
        case custom
        case none
    }
    
    enum MaskQuality {
        case low
        case medium
        case high
        
        var visionQuality: VNGeneratePersonSegmentationRequest.QualityLevel {
            switch self {
            case .low: return .fast
            case .medium: return .balanced
            case .high: return .accurate
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupSegmentationRequest()
    }
    
    private func setupSegmentationRequest() {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest?.qualityLevel = maskQuality.visionQuality
    }
    
    // MARK: - Background Removal
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw GreenScreenError.invalidImage
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Create segmentation mask
        let mask = try await createPersonMask(from: ciImage)
        
        // Apply background
        let result = try applyBackground(to: ciImage, mask: mask)
        
        guard let cgImage = ciContext.createCGImage(result, from: result.extent) else {
            throw GreenScreenError.processingFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func removeBackgroundRealtime(from pixelBuffer: CVPixelBuffer) async throws -> CIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create segmentation mask
        let mask = try await createPersonMask(from: ciImage)
        
        // Apply background
        let result = try applyBackground(to: ciImage, mask: mask)
        
        return result
    }
    
    // MARK: - Person Segmentation
    private func createPersonMask(from image: CIImage) async throws -> CIImage {
        guard let request = segmentationRequest else {
            throw GreenScreenError.setupFailed
        }
        
        // Create request handler
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        
        // Perform segmentation
        try handler.perform([request])
        
        // Get mask
        guard let observation = request.results?.first else {
            throw GreenScreenError.segmentationFailed
        }
        
        // Convert mask to CIImage
        let maskPixelBuffer = observation.pixelBuffer
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale mask to match original image size
        let scaleX = image.extent.width / maskImage.extent.width
        let scaleY = image.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Apply feathering to edges
        if edgeFeathering > 0 {
            return applyFeathering(to: scaledMask, radius: edgeFeathering)
        }
        
        return scaledMask
    }
    
    private func applyFeathering(to mask: CIImage, radius: CGFloat) -> CIImage {
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(mask, forKey: kCIInputImageKey)
        blurFilter.setValue(radius, forKey: kCIInputRadiusKey)
        
        return blurFilter.outputImage ?? mask
    }
    
    // MARK: - Background Application
    private func applyBackground(to image: CIImage, mask: CIImage) throws -> CIImage {
        switch selectedBackground {
        case .blur:
            return try applyBlurBackground(to: image, mask: mask)
            
        case .color(let color):
            return try applyColorBackground(to: image, mask: mask, color: color)
            
        case .gradient(let colors):
            return try applyGradientBackground(to: image, mask: mask, colors: colors)
            
        case .image(let imageName):
            return try applyImageBackground(to: image, mask: mask, imageName: imageName)
            
        case .custom:
            if let customBg = backgroundImage {
                return try applyCustomBackground(to: image, mask: mask, background: customBg)
            }
            return image
            
        case .none:
            return image
        }
    }
    
    private func applyBlurBackground(to image: CIImage, mask: CIImage) throws -> CIImage {
        // Blur the background
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
        
        guard let blurredBg = blurFilter.outputImage else {
            throw GreenScreenError.filterFailed
        }
        
        // Composite person over blurred background
        return compositePerson(foreground: image, background: blurredBg, mask: mask)
    }
    
    private func applyColorBackground(to image: CIImage, mask: CIImage, color: Color) throws -> CIImage {
        // Create solid color background
        let uiColor = UIColor(color)
        let colorImage = CIImage(color: CIColor(color: uiColor))
            .cropped(to: image.extent)
        
        return compositePerson(foreground: image, background: colorImage, mask: mask)
    }
    
    private func applyGradientBackground(to image: CIImage, mask: CIImage, colors: [Color]) throws -> CIImage {
        // Create gradient background
        let gradientImage = createGradientImage(colors: colors, size: image.extent.size)
        
        guard let ciGradient = CIImage(image: gradientImage) else {
            throw GreenScreenError.backgroundCreationFailed
        }
        
        return compositePerson(foreground: image, background: ciGradient, mask: mask)
    }
    
    private func applyImageBackground(to image: CIImage, mask: CIImage, imageName: String) throws -> CIImage {
        // Load background image
        guard let bgImage = UIImage(named: imageName),
              let ciBgImage = CIImage(image: bgImage) else {
            throw GreenScreenError.backgroundNotFound
        }
        
        // Scale background to match image size
        let scaleX = image.extent.width / ciBgImage.extent.width
        let scaleY = image.extent.height / ciBgImage.extent.height
        let scaledBg = ciBgImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        return compositePerson(foreground: image, background: scaledBg, mask: mask)
    }
    
    private func applyCustomBackground(to image: CIImage, mask: CIImage, background: UIImage) throws -> CIImage {
        guard let ciBgImage = CIImage(image: background) else {
            throw GreenScreenError.invalidBackground
        }
        
        // Scale background to match image size
        let scaleX = image.extent.width / ciBgImage.extent.width
        let scaleY = image.extent.height / ciBgImage.extent.height
        let scaledBg = ciBgImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        return compositePerson(foreground: image, background: scaledBg, mask: mask)
    }
    
    private func compositePerson(foreground: CIImage, background: CIImage, mask: CIImage) -> CIImage {
        // Use blend with mask filter
        let blendFilter = CIFilter(name: "CIBlendWithMask")!
        blendFilter.setValue(foreground, forKey: kCIInputImageKey)
        blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        return blendFilter.outputImage ?? foreground
    }
    
    // MARK: - Helper Methods
    private func createGradientImage(colors: [Color], size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgColors = colors.map { UIColor($0).cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: nil)!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }
    
    func updateMaskQuality(_ quality: MaskQuality) {
        maskQuality = quality
        segmentationRequest?.qualityLevel = quality.visionQuality
    }
}

// MARK: - Supporting Types
struct BackgroundOption: Identifiable {
    let id = UUID()
    let type: GreenScreenEngine.BackgroundType
    let name: String
    let icon: String
}

enum GreenScreenError: LocalizedError {
    case invalidImage
    case setupFailed
    case segmentationFailed
    case filterFailed
    case backgroundCreationFailed
    case backgroundNotFound
    case invalidBackground
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .setupFailed: return "Failed to setup segmentation"
        case .segmentationFailed: return "Person segmentation failed"
        case .filterFailed: return "Filter application failed"
        case .backgroundCreationFailed: return "Failed to create background"
        case .backgroundNotFound: return "Background image not found"
        case .invalidBackground: return "Invalid background image"
        case .processingFailed: return "Processing failed"
        }
    }
}


