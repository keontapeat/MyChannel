//
//  ProfileMerchService.swift
//  MyChannel
//
//  Phase 254: Profile Merch & Storefront Integration.
//  In-profile merch shelf, product cards, purchase flow,
//  inventory sync, storefront link-in-bio.
//  Uses `merchandise-ai` + `escrow-payments` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileMerchProduct: Codable, Identifiable {
    let id: String
    let creatorId: String
    let name: String
    let description: String
    let price: Double
    let currency: String
    let imageURL: String?
    let category: String
    let inStock: Bool
    let stockCount: Int
    let salesCount: Int
}

struct MerchOrder: Codable, Identifiable {
    let id: String
    let productId: String
    let buyerId: String
    let quantity: Int
    let total: Double
    let status: OrderStatus
    let createdAt: Date

    enum OrderStatus: String, Codable { case pending, processing, shipped, delivered, cancelled }
}

// MARK: - Service

@MainActor
final class ProfileMerchService: ObservableObject {
    static let shared = ProfileMerchService()
    private init() {}

    @Published private(set) var products: [ProfileMerchProduct] = []
    @Published private(set) var recentOrders: [MerchOrder] = []

    func fetchMerch(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileMerch else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawP: Decodable { let id: String; let name: String; let desc: String; let price: Double; let currency: String; let image: String?; let category: String; let in_stock: Bool; let stock: Int; let sales: Int }
        struct Raw: Decodable { let products: [RawP]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .merchandiseAI, path: "/predict",
            body: Req(task: "fetch_merch", creatorId: creatorId)
        )
        products = (r.products ?? []).map {
            ProfileMerchProduct(id: $0.id, creatorId: creatorId, name: $0.name, description: $0.desc,
                                price: $0.price, currency: $0.currency, imageURL: $0.image, category: $0.category,
                                inStock: $0.in_stock, stockCount: $0.stock, salesCount: $0.sales)
        }
    }

    func placeOrder(productId: String, buyerId: String, quantity: Int) async throws -> MerchOrder {
        guard AppConfig.Features.enableProfileMerch else {
            return MerchOrder(id: "", productId: productId, buyerId: buyerId, quantity: quantity,
                                total: 0, status: .pending, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let productId: String; let buyerId: String; let quantity: Int }
        struct Raw: Decodable { let id: String; let total: Double?; let status: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .escrowPayments, path: "/predict",
            body: Req(task: "place_merch_order", productId: productId, buyerId: buyerId, quantity: quantity), timeout: 30
        )
        let order = MerchOrder(id: r.id, productId: productId, buyerId: buyerId, quantity: quantity,
                                 total: r.total ?? 0, status: .init(rawValue: r.status) ?? .pending, createdAt: Date())
        recentOrders.append(order)
        return order
    }

    func syncInventory(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileMerch else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawP: Decodable { let id: String; let in_stock: Bool; let stock: Int }
        struct Raw: Decodable { let products: [RawP]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .merchandiseAI, path: "/predict",
            body: Req(task: "sync_inventory", creatorId: creatorId)
        )
        for update in (r.products ?? []) {
            if let idx = products.firstIndex(where: { $0.id == update.id }) {
                let old = products[idx]
                products[idx] = ProfileMerchProduct(id: old.id, creatorId: old.creatorId, name: old.name, description: old.description,
                                                    price: old.price, currency: old.currency, imageURL: old.imageURL, category: old.category,
                                                    inStock: update.in_stock, stockCount: update.stock, salesCount: old.salesCount)
            }
        }
    }
}
