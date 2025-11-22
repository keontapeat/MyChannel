//
//  ThumbnailCreatorViewModel.swift
//  MyChannel
//
//  ViewModel for Thumbnail Creator
//

import Foundation
import SwiftUI

struct ThumbnailAnalysis: Identifiable {
    let id = UUID()
    let score: Int
    let readability: String
    let emotionalImpact: String
    let clickPotential: String
    let clickPrediction: Int
    let textReadability: Int
    let faceScore: Int
    let colorScore: Int
    let suggestions: [String]
    
    var verdict: String {
        switch score {
        case 90...100: return "🔥 Viral Potential"
        case 75..<90: return "✅ Strong Thumbnail"
        case 60..<75: return "👍 Good Thumbnail"
        case 40..<60: return "⚠️ Needs Improvement"
        default: return "❌ Poor Performance"
        }
    }
}

struct GeneratedThumbnail: Identifiable {
    let id = UUID()
    let imageURL: String
    let style: String
    let prompt: String
    let aiModel: String
}

struct ThumbnailFilter: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct ThumbnailTemplate: Identifiable {
    let id = UUID()
    let name: String
    let thumbnailURL: String
    let category: String
    let price: Double
    let creator: String
}

extension ThumbnailTemplate {
    static let allTemplates: [ThumbnailTemplate] = [
        ThumbnailTemplate(name: "Bold Text", thumbnailURL: "https://picsum.photos/seed/tt1/800/450", category: "Text", price: 0, creator: "AI"),
        ThumbnailTemplate(name: "Cinematic", thumbnailURL: "https://picsum.photos/seed/tt2/800/450", category: "Cinematic", price: 0, creator: "AI"),
        ThumbnailTemplate(name: "Vibrant", thumbnailURL: "https://picsum.photos/seed/tt3/800/450", category: "Color", price: 0, creator: "AI")
    ]
}

@MainActor
class ThumbnailCreatorViewModel: ObservableObject {
    @Published var currentThumbnail: UIImage?
    @Published var analysis: ThumbnailAnalysis?
    @Published var generatedThumbnails: [GeneratedThumbnail] = []
    @Published var isGenerating = false
    @Published var selectedTemplate: ThumbnailTemplate?
    
    // UI state needed by view
    @Published var isAnalyzing: Bool = false
    @Published var viralScore: Int?
    @Published var videoTitle: String = ""
    @Published var selectedStyle: ThumbnailStyle = .clickbait
    
    // Edit controls
    @Published var brightness: Double = 0.0
    @Published var contrast: Double = 1.0
    @Published var saturation: Double = 1.0
    
    // Text overlay
    @Published var showTextOverlay: Bool = false
    @Published var overlayText: String = ""
    @Published var textSize: Double = 48
    
    // Filters
    @Published var selectedFilter: ThumbnailFilter?
    
    // Image picker
    @Published var showImagePicker: Bool = false
    
    // AI Suggestions
    @Published var suggestions: [String] = [
        "Add high-contrast text",
        "Use emotion in faces",
        "Include action elements",
        "Try red/yellow accents"
    ]
    
    // Available filters
    let filters: [ThumbnailFilter] = [
        ThumbnailFilter(name: "Enhance", icon: "cpu"),
        ThumbnailFilter(name: "Brighten", icon: "sun.max"),
        ThumbnailFilter(name: "Contrast", icon: "circle.lefthalf.filled"),
        ThumbnailFilter(name: "Saturation", icon: "drop.fill"),
        ThumbnailFilter(name: "Sharpen", icon: "square.grid.3x3"),
        ThumbnailFilter(name: "Blur", icon: "aqi.medium")
    ]
    
    func generateThumbnails(prompt: String) async {
        isGenerating = true
        // Simulate AI generation
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        generatedThumbnails = [
            GeneratedThumbnail(imageURL: "", style: "Cinematic", prompt: prompt, aiModel: "DALL-E 3"),
            GeneratedThumbnail(imageURL: "", style: "Bold", prompt: prompt, aiModel: "Midjourney"),
            GeneratedThumbnail(imageURL: "", style: "Minimalist", prompt: prompt, aiModel: "Stable Diffusion"),
            GeneratedThumbnail(imageURL: "", style: "Dramatic", prompt: prompt, aiModel: "GPT-5 Vision")
        ]
        
        isGenerating = false
    }
    
    func analyzeThumbnail(_ image: UIImage) async {
        // Simulate AI analysis
        isAnalyzing = true
        defer { isAnalyzing = false }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        analysis = ThumbnailAnalysis(
            score: Int.random(in: 70...95),
            readability: "High",
            emotionalImpact: "Strong",
            clickPotential: "Excellent",
            clickPrediction: Int.random(in: 65...95),
            textReadability: Int.random(in: 70...100),
            faceScore: Int.random(in: 60...90),
            colorScore: Int.random(in: 75...95),
            suggestions: [
                "Text is clear and bold ✓",
                "Good use of contrast",
                "Consider adding a subtle shadow to face",
                "Color scheme is eye-catching"
            ]
        )
    }
    
    func analyzeThumbnail() async {
        guard let img = currentThumbnail else { return }
        await analyzeThumbnail(img)
    }
    
    func applyFilter(_ filter: ThumbnailFilter) {
        // Apply filter logic
        print("Applying filter: \(filter.name)")
        selectedFilter = filter
    }
    
    func applyFilters() {
        // Apply current edit sliders
        print("Applying edits: brightness=\(brightness), contrast=\(contrast), saturation=\(saturation)")
    }
    
    var recentThumbnails: [GeneratedThumbnail] { generatedThumbnails }
    
    func clearRecent() { generatedThumbnails.removeAll() }
    
    func selectThumbnail(_ thumbnail: GeneratedThumbnail) {
        print("Selected thumbnail: \(thumbnail.style)")
    }
    
    func createABTest() { print("Creating A/B test") }
    
    func saveThumbnail() {
        // Save thumbnail logic
        print("Saving thumbnail")
    }

    // Export helpers used by Export sheet
    func saveToPhotos() { print("Saved to Photos") }
    func shareThumbnail() { print("Share thumbnail") }
    func useForVideo() { print("Use for video") }

    func applyTemplate(_ template: ThumbnailTemplate) {
        selectedTemplate = template
        print("Applied template: \(template.name)")
    }
    
    // 🎨 Generate thumbnail (placeholder-based for now - AI moved to Parachute app)
    func generateThumbnail() async {
        isGenerating = true
        defer { isGenerating = false }
        
        print("🎨 Generating thumbnail preview...")
        
        // Simulate generation delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Create placeholder thumbnail
        let newThumbnail = GeneratedThumbnail(
            imageURL: "https://picsum.photos/seed/\(UUID().uuidString)/800/450",
            style: selectedStyle.rawValue,
            prompt: videoTitle,
            aiModel: "Preview"
        )
        generatedThumbnails.insert(newThumbnail, at: 0)
        
        // Auto-analyze the generated thumbnail
        await analyzeThumbnail()
        
        print("✅ Thumbnail preview generated!")
    }
    
    // 🎨 Generate multiple variations (placeholder-based for now - AI moved to Parachute app)
    func generateMultipleVariations(count: Int = 4) async {
        isGenerating = true
        defer { isGenerating = false }
        
        print("🎨 Generating \(count) preview variations...")
        
        // Simulate generation delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        for index in 0..<count {
            let newThumbnail = GeneratedThumbnail(
                imageURL: "https://picsum.photos/seed/var\(index)_\(UUID().uuidString)/800/450",
                style: selectedStyle.rawValue,
                prompt: "\(videoTitle) (Variation \(index + 1))",
                aiModel: "Preview"
            )
            generatedThumbnails.insert(newThumbnail, at: 0)
        }
        
        // Auto-analyze the first variation
        await analyzeThumbnail()
        
        print("✅ Generated \(count) preview variations!")
    }
}


