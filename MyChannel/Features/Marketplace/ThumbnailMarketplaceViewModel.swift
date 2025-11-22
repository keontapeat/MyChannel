//
//  ThumbnailMarketplaceViewModel.swift
//  MyChannel
//
//  ViewModel for Thumbnail Marketplace
//

import Foundation
import SwiftUI
import Combine

// MARK: - Template Category
enum TemplateCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case gaming = "Gaming"
    case tutorial = "Tutorial"
    case vlog = "Vlog"
    case tech = "Tech"
    case lifestyle = "Lifestyle"
    case fitness = "Fitness"
    case cooking = "Cooking"
    case music = "Music"
    case comedy = "Comedy"
    case educational = "Educational"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .gaming: return "gamecontroller.fill"
        case .tutorial: return "book.fill"
        case .vlog: return "video.fill"
        case .tech: return "cpu.fill"
        case .lifestyle: return "star.fill"
        case .fitness: return "figure.run"
        case .cooking: return "fork.knife"
        case .music: return "music.note"
        case .comedy: return "face.smiling"
        case .educational: return "graduationcap.fill"
        }
    }
}

// MARK: - Template Product Model
struct ThumbnailTemplateProduct: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let previewURL: String
    let downloadURL: String
    let price: Double
    let category: TemplateCategory
    let creator: TemplateCreator
    let rating: Double
    let salesCount: Int
    let likesCount: Int
    let createdAt: Date
    let tags: [String]
    
    struct TemplateCreator: Codable {
        let id: String
        let displayName: String
        let profileImageURL: String
    }
}

// MARK: - ViewModel
@MainActor
class ThumbnailMarketplaceViewModel: ObservableObject {
    @Published var templates: [ThumbnailTemplateProduct] = []
    @Published var featuredTemplates: [ThumbnailTemplateProduct] = []
    @Published var userIsCreator = false
    @Published var creatorRevenue: Double = 0
    @Published var templateSales: Int = 0
    @Published var myTemplatesCount: Int = 0
    
    func loadTemplates() async {
        // Load from Firestore
        // For now, mock data
        templates = mockTemplates()
        featuredTemplates = Array(templates.prefix(5))
        
        // Load creator stats if user has templates
        await loadCreatorStats()
    }
    
    func filterByCategory(_ category: TemplateCategory) async {
        if category == .all {
            await loadTemplates()
        } else {
            templates = templates.filter { $0.category == category }
        }
    }
    
    private func loadCreatorStats() async {
        // Check if user is a template creator
        userIsCreator = true // Mock
        creatorRevenue = 1234.56
        templateSales = 87
        myTemplatesCount = 12
    }
    
    private func mockTemplates() -> [ThumbnailTemplateProduct] {
        let mockCreator = ThumbnailTemplateProduct.TemplateCreator(
            id: "creator1",
            displayName: "Pro Designer",
            profileImageURL: ""
        )
        
        return [
            ThumbnailTemplateProduct(
                id: "1",
                name: "Epic Gaming Thumbnail",
                description: "Perfect for gaming videos with bold text and vibrant colors",
                previewURL: "",
                downloadURL: "",
                price: 9.99,
                category: .gaming,
                creator: mockCreator,
                rating: 4.9,
                salesCount: 234,
                likesCount: 567,
                createdAt: Date(),
                tags: ["gaming", "bold", "colorful"]
            ),
            ThumbnailTemplateProduct(
                id: "2",
                name: "Tech Review Pro",
                description: "Clean, professional template for tech reviews and tutorials",
                previewURL: "",
                downloadURL: "",
                price: 12.99,
                category: .tech,
                creator: mockCreator,
                rating: 4.8,
                salesCount: 189,
                likesCount: 432,
                createdAt: Date(),
                tags: ["tech", "clean", "professional"]
            ),
            ThumbnailTemplateProduct(
                id: "3",
                name: "Vlog Lifestyle",
                description: "Trendy template perfect for lifestyle and travel vlogs",
                previewURL: "",
                downloadURL: "",
                price: 7.99,
                category: .vlog,
                creator: mockCreator,
                rating: 4.7,
                salesCount: 156,
                likesCount: 389,
                createdAt: Date(),
                tags: ["vlog", "lifestyle", "trendy"]
            )
        ]
    }
}

// MARK: - Upload Template ViewModel
@MainActor
class UploadTemplateViewModel: ObservableObject {
    @Published var templateImage: UIImage?
    @Published var name = ""
    @Published var description = ""
    @Published var price: Double = 9.99
    @Published var category: TemplateCategory = .gaming
    @Published var showImagePicker = false
    @Published var isUploading = false
    
    var isValid: Bool {
        !name.isEmpty && !description.isEmpty && templateImage != nil && price > 0
    }
    
    func uploadTemplate() async {
        isUploading = true
        
        // Upload to Firebase Storage
        // Create Firestore document
        // Process payment setup
        
        print("📤 Uploading template: \(name)")
        print("💰 Price: $\(price)")
        print("📁 Category: \(category.rawValue)")
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        isUploading = false
        print("✅ Template listed successfully!")
    }
}

extension TemplateCategory: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TemplateCategory(rawValue: rawValue) ?? .all
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

