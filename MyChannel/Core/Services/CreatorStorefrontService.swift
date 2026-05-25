//
//  CreatorStorefrontService.swift
//  MyChannel
//
//  Phase 223: Creator Storefronts v2.
//  Merch, presets, templates, digital bundles, native storefront analytics,
//  rights-aware product attachments.
//  Uses `merchandise-ai` + `sponsorship-matcher` Cloud Run.
//

import Foundation

// MARK: - Models

struct StorefrontProduct: Codable, Identifiable {
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let type: ProductType
    let price: Double
    let currency: String
    let imageURL: URL?
    let isAvailable: Bool
    let rightsCleared: Bool
    let salesCount: Int

    enum ProductType: String, Codable {
        case merch, preset, template, bundle, digital
    }
}

struct StorefrontAnalytics: Codable {
    let totalRevenue: Double
    let topProduct: String?
    let conversionRate: Double
    let uniqueVisitors: Int
    let repeatBuyers: Int
}

// MARK: - Service

@MainActor
final class CreatorStorefrontService: ObservableObject {
    static let shared = CreatorStorefrontService()
    private init() {}

    @Published private(set) var products: [StorefrontProduct] = []
    @Published private(set) var analytics: StorefrontAnalytics?
    @Published var isCreating: Bool = false

    func fetchStorefront(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorStorefrontsV2 else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawProd: Decodable { let id: String; let title: String; let desc: String; let type: String; let price: Double; let currency: String; let image: String?; let available: Bool; let rights: Bool; let sales: Int }
        struct Raw: Decodable { let products: [RawProd]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .merchandiseAI, path: "/predict",
            body: Req(task: "fetch_storefront", creatorId: creatorId)
        )
        products = (r.products ?? []).map {
            StorefrontProduct(id: $0.id, creatorId: creatorId, title: $0.title, description: $0.desc,
                              type: .init(rawValue: $0.type) ?? .digital, price: $0.price, currency: $0.currency,
                              imageURL: $0.image.flatMap(URL.init(string:)), isAvailable: $0.available,
                              rightsCleared: $0.rights, salesCount: $0.sales)
        }
    }

    func createProduct(creatorId: String, title: String, type: StorefrontProduct.ProductType, price: Double) async throws -> StorefrontProduct {
        guard AppConfig.Features.enableCreatorStorefrontsV2 else {
            return StorefrontProduct(id: "", creatorId: creatorId, title: title, description: "", type: type,
                                     price: price, currency: "USD", imageURL: nil, isAvailable: false, rightsCleared: false, salesCount: 0)
        }
        isCreating = true
        defer { isCreating = false }
        struct Req: Encodable { let task: String; let creatorId: String; let title: String; let type: String; let price: Double }
        struct Raw: Decodable { let id: String; let rights: Bool }
        let r: Raw = try await CloudRunAgentRouter.post(
            .merchandiseAI, path: "/predict",
            body: Req(task: "create_product", creatorId: creatorId, title: title, type: type.rawValue, price: price)
        )
        let product = StorefrontProduct(id: r.id, creatorId: creatorId, title: title, description: "", type: type,
                                         price: price, currency: "USD", imageURL: nil, isAvailable: true,
                                         rightsCleared: r.rights, salesCount: 0)
        products.append(product)
        return product
    }

    func fetchAnalytics(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorStorefrontsV2 else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let revenue: Double?; let top_product: String?; let conversion: Double?; let visitors: Int?; let repeat_buyers: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcher, path: "/predict",
            body: Req(task: "storefront_analytics", creatorId: creatorId)
        )
        analytics = StorefrontAnalytics(totalRevenue: r.revenue ?? 0, topProduct: r.top_product,
                                         conversionRate: r.conversion ?? 0, uniqueVisitors: r.visitors ?? 0,
                                         repeatBuyers: r.repeat_buyers ?? 0)
    }

    func checkRights(productId: String) async throws -> Bool {
        guard AppConfig.Features.enableCreatorStorefrontsV2 else { return false }
        struct Req: Encodable { let task: String; let productId: String }
        struct Raw: Decodable { let cleared: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .copyrightDetection, path: "/predict",
            body: Req(task: "check_product_rights", productId: productId)
        )
        return r.cleared ?? false
    }
}
