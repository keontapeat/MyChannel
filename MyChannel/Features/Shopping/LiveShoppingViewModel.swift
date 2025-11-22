//
//  LiveShoppingViewModel.swift
//  MyChannel
//
//  ViewModel for Live Shopping
//

import Foundation
import SwiftUI

// MARK: - Models

enum ShoppingCategory: String, CaseIterable, Identifiable, Codable {
    case fashion = "Fashion"
    case tech = "Tech"
    case beauty = "Beauty"
    case home = "Home"
    case sports = "Sports"
    case food = "Food"
    case books = "Books"
    case art = "Art"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .fashion: return "tshirt.fill"
        case .tech: return "iphone"
        case .beauty: return "drop.fill"
        case .home: return "house.fill"
        case .sports: return "sportscourt.fill"
        case .food: return "fork.knife"
        case .books: return "book.fill"
        case .art: return "paintbrush.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fashion: return Color(hex: "F3F0FF") ?? AppTheme.Colors.backgroundSecondary
        case .tech: return Color(hex: "EDF4FF") ?? AppTheme.Colors.backgroundSecondary
        case .beauty: return Color(hex: "FDF2F8") ?? AppTheme.Colors.backgroundSecondary
        case .home: return Color(hex: "F5F5F0") ?? AppTheme.Colors.backgroundSecondary
        case .sports: return Color(hex: "EDF8F2") ?? AppTheme.Colors.backgroundSecondary
        case .food: return Color(hex: "FFF5EB") ?? AppTheme.Colors.backgroundSecondary
        case .books: return Color(hex: "F6EFE4") ?? AppTheme.Colors.backgroundSecondary
        case .art: return Color(hex: "F7ECFF") ?? AppTheme.Colors.backgroundSecondary
        }
    }
}

struct ShoppingProduct: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let originalPrice: Int
    let discount: Int
    let imageURL: String
    let category: ShoppingCategory
    let creatorId: String
    let creatorCommission: Double // Percentage
    let rating: Double
    let reviews: Int
    let hasARTryOn: Bool
    var stockRemaining: Int
    let brand: String
}

struct LiveShoppingShow: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let creator: ShowCreator
    let startTime: Date
    var viewerCount: Int
    let featuredProducts: [String] // Product IDs
    let isLive: Bool
    
    struct ShowCreator: Codable {
        let id: String
        let name: String
        let avatarURL: String
    }
}

struct CreatorShop: Identifiable, Codable {
    let id: String
    let creator: LiveShoppingShow.ShowCreator
    let productCount: Int
    let totalSales: Int
    let rating: Double
}

// MARK: - ViewModel

@MainActor
class LiveShoppingViewModel: ObservableObject {
    @Published var liveShows: [LiveShoppingShow] = []
    @Published var featuredProducts: [ShoppingProduct] = []
    @Published var flashSaleProducts: [ShoppingProduct] = []
    @Published var creatorShops: [CreatorShop] = []
    @Published var flashSaleTimeRemaining: String = "2h 34m"
    
    func loadLiveShops() async {
        // Load from Firestore
        liveShows = [
            LiveShoppingShow(
                id: "1",
                title: "Holiday Fashion Sale 🎄",
                description: "Get ready for the holidays with amazing deals",
                thumbnailURL: "",
                creator: LiveShoppingShow.ShowCreator(
                    id: "c1",
                    name: "Fashion Queen",
                    avatarURL: ""
                ),
                startTime: Date(),
                viewerCount: 3456,
                featuredProducts: ["p1", "p2"],
                isLive: true
            )
        ]
        
        featuredProducts = mockProducts()
        flashSaleProducts = Array(mockProducts().prefix(3))
        creatorShops = mockCreatorShops()
    }
    
    private func mockProducts() -> [ShoppingProduct] {
        return [
            ShoppingProduct(
                id: "1",
                name: "Premium Wireless Headphones",
                description: "High-quality sound with active noise cancellation",
                price: 199.99,
                originalPrice: 299,
                discount: 33,
                imageURL: "",
                category: .tech,
                creatorId: "c1",
                creatorCommission: 15.0,
                rating: 4.8,
                reviews: 1234,
                hasARTryOn: true,
                stockRemaining: 45,
                brand: "SoundPro"
            ),
            ShoppingProduct(
                id: "2",
                name: "Designer Sneakers",
                description: "Limited edition colorway",
                price: 149.99,
                originalPrice: 200,
                discount: 25,
                imageURL: "",
                category: .fashion,
                creatorId: "c1",
                creatorCommission: 20.0,
                rating: 4.9,
                reviews: 567,
                hasARTryOn: true,
                stockRemaining: 12,
                brand: "StepUp"
            )
        ]
    }
    
    private func mockCreatorShops() -> [CreatorShop] {
        return [
            CreatorShop(
                id: "1",
                creator: LiveShoppingShow.ShowCreator(
                    id: "c1",
                    name: "Tech Guru",
                    avatarURL: ""
                ),
                productCount: 45,
                totalSales: 12500,
                rating: 4.9
            )
        ]
    }
}

