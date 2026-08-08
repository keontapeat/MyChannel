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
        case .fashion: return Color(hexString: "F3F0FF") ?? AppTheme.Colors.backgroundSecondary
        case .tech: return Color(hexString: "EDF4FF") ?? AppTheme.Colors.backgroundSecondary
        case .beauty: return Color(hexString: "FDF2F8") ?? AppTheme.Colors.backgroundSecondary
        case .home: return Color(hexString: "F5F5F0") ?? AppTheme.Colors.backgroundSecondary
        case .sports: return Color(hexString: "EDF8F2") ?? AppTheme.Colors.backgroundSecondary
        case .food: return Color(hexString: "FFF5EB") ?? AppTheme.Colors.backgroundSecondary
        case .books: return Color(hexString: "F6EFE4") ?? AppTheme.Colors.backgroundSecondary
        case .art: return Color(hexString: "F7ECFF") ?? AppTheme.Colors.backgroundSecondary
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
    // App Store Guideline 3.1.5(a)–compliant external checkout link (physical goods).
    var storefrontURL: String? = nil
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
    var storefrontURL: String? = nil
}

// MARK: - ViewModel

@MainActor
class LiveShoppingViewModel: ObservableObject {
    @Published var liveShows: [LiveShoppingShow] = []
    @Published var featuredProducts: [ShoppingProduct] = []
    @Published var flashSaleProducts: [ShoppingProduct] = []
    @Published var creatorShops: [CreatorShop] = []
    @Published var metrics: [ShoppingMetric] = ShoppingMetric.defaultMetrics
    @Published var flashSaleTimeRemaining: String = "2h 34m"
    @Published private(set) var isLoading = false

    private let service = LiveShoppingService.shared
    private var flashSaleEnd = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    private var countdownTimer: Timer?

    func loadLiveShops() async {
        isLoading = true
        defer { isLoading = false }

        // Real Firestore data first.
        async let showsTask = service.fetchLiveShows()
        async let trendingTask = service.fetchTrendingProducts()
        async let flashTask = service.fetchFlashSaleProducts()
        async let shopsTask = service.fetchCreatorShops()
        async let metricsTask = service.fetchMetrics()

        let (shows, trending, flash, shops, liveMetrics) = await (showsTask, trendingTask, flashTask, shopsTask, metricsTask)

        liveShows = shows
        featuredProducts = trending
        flashSaleProducts = flash
        creatorShops = shops
        if !liveMetrics.isEmpty { metrics = liveMetrics }

        // In DEBUG/dev (no seeded data yet) fall back to samples so the UI is never empty.
        if AppConfig.Features.enableMockData {
            if liveShows.isEmpty { liveShows = Self.sampleShows() }
            if featuredProducts.isEmpty { featuredProducts = Self.sampleProducts() }
            if flashSaleProducts.isEmpty { flashSaleProducts = Array(Self.sampleProducts().prefix(3)) }
            if creatorShops.isEmpty { creatorShops = Self.sampleCreatorShops() }
        }

        startCountdown()
        updateCountdownLabel()
    }

    func search(_ query: String) async -> [ShoppingProduct] {
        let results = await service.searchProducts(query: query)
        if results.isEmpty && AppConfig.Features.enableMockData {
            let q = query.lowercased()
            return Self.sampleProducts().filter {
                $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
            }
        }
        return results
    }

    // MARK: - Flash sale countdown

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateCountdownLabel() }
        }
    }

    private func updateCountdownLabel() {
        let remaining = max(0, flashSaleEnd.timeIntervalSinceNow)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        flashSaleTimeRemaining = "\(hours)h \(minutes)m"
    }

    deinit { countdownTimer?.invalidate() }

    // MARK: - DEBUG-only sample fallbacks

    private static func sampleShows() -> [LiveShoppingShow] {
        [
            LiveShoppingShow(
                id: "sample-1",
                title: "Holiday Fashion Sale 🎄",
                description: "Get ready for the holidays with amazing deals",
                thumbnailURL: "",
                creator: LiveShoppingShow.ShowCreator(id: "c1", name: "Fashion Queen", avatarURL: ""),
                startTime: Date(),
                viewerCount: 3456,
                featuredProducts: ["p1", "p2"],
                isLive: true
            )
        ]
    }

    private static func sampleProducts() -> [ShoppingProduct] {
        [
            ShoppingProduct(
                id: "sample-1",
                name: "Premium Wireless Headphones",
                description: "High-quality sound with active noise cancellation",
                price: 199.99, originalPrice: 299, discount: 33, imageURL: "",
                category: .tech, creatorId: "c1", creatorCommission: 15.0,
                rating: 4.8, reviews: 1234, hasARTryOn: true, stockRemaining: 45, brand: "SoundPro",
                storefrontURL: "https://mychannel.app/shop/soundpro-headphones"
            ),
            ShoppingProduct(
                id: "sample-2",
                name: "Designer Sneakers",
                description: "Limited edition colorway",
                price: 149.99, originalPrice: 200, discount: 25, imageURL: "",
                category: .fashion, creatorId: "c1", creatorCommission: 20.0,
                rating: 4.9, reviews: 567, hasARTryOn: true, stockRemaining: 12, brand: "StepUp",
                storefrontURL: "https://mychannel.app/shop/stepup-sneakers"
            )
        ]
    }

    private static func sampleCreatorShops() -> [CreatorShop] {
        [
            CreatorShop(
                id: "sample-1",
                creator: LiveShoppingShow.ShowCreator(id: "c1", name: "Tech Guru", avatarURL: ""),
                productCount: 45, totalSales: 12500, rating: 4.9,
                storefrontURL: "https://mychannel.app/shop/tech-guru"
            )
        ]
    }
}

