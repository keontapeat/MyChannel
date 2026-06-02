//
//  CreatorMerchFirestoreService.swift
//  MyChannel
//
//  Firestore-backed creator MERCHANDISE CATALOG (YouTube "Merch shelf" parity).
//  This persists the products a creator lists — name, price, stock, category,
//  image. It is product CONFIGURATION authored by the creator, not a money
//  ledger: actual checkout/fulfillment/payment is a separate flow that must run
//  through IAP/commerce + compliance and is intentionally NOT implemented here.
//
//  Layout: creator_products/{productId} with a `creatorId` field (flat
//  collection, public read so viewers see the shelf, owner-only write).
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Stored product model

struct CreatorProduct: Identifiable, Equatable {
    let id: String
    var name: String
    var price: Double
    var stock: Int
    var imageSystemName: String   // SF Symbol for now; real image URL later
    var category: String
    var isActive: Bool
    var updatedAt: Date

    static func == (lhs: CreatorProduct, rhs: CreatorProduct) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class CreatorMerchFirestoreService: ObservableObject {
    static let shared = CreatorMerchFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published var isLoading = false

    func isMerchEnabled(for creatorId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return false }
        let doc = try? await db.collection("creator_merch_settings").document(creatorId).getDocument()
        return (doc?.data()?["enabled"] as? Bool) ?? false
        #else
        return false
        #endif
    }

    func setMerchEnabled(_ enabled: Bool, for creatorId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return }
        try await db.collection("creator_merch_settings").document(creatorId).setData([
            "enabled": enabled,
            "creatorId": creatorId,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }

    func getProducts(for creatorId: String) async throws -> [CreatorProduct] {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return [] }
        isLoading = true; defer { isLoading = false }
        let snap = try await db.collection("creator_products")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        return snap.documents.map { doc in
            let d = doc.data()
            return CreatorProduct(
                id: doc.documentID,
                name: d["name"] as? String ?? "Untitled",
                price: (d["price"] as? Double) ?? (d["price"] as? Int).map(Double.init) ?? 0,
                stock: d["stock"] as? Int ?? 0,
                imageSystemName: d["imageSystemName"] as? String ?? "bag.fill",
                category: d["category"] as? String ?? "General",
                isActive: d["isActive"] as? Bool ?? true,
                updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #else
        return []
        #endif
    }

    @discardableResult
    func saveProduct(_ product: CreatorProduct, for creatorId: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else {
            throw NSError(domain: "Merch", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        guard product.price >= 0.01 && product.price <= 100000 else {
            throw NSError(domain: "Merch", code: 422, userInfo: [NSLocalizedDescriptionKey: "Price must be between $0.01 and $100,000"])
        }
        guard product.stock >= 0 else {
            throw NSError(domain: "Merch", code: 422, userInfo: [NSLocalizedDescriptionKey: "Stock cannot be negative"])
        }
        try await db.collection("creator_products").document(product.id).setData([
            "creatorId": creatorId,
            "name": product.name,
            "price": product.price,
            "stock": product.stock,
            "imageSystemName": product.imageSystemName,
            "category": product.category,
            "isActive": product.isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return product.id
        #else
        return product.id
        #endif
    }

    func deleteProduct(_ productId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("creator_products").document(productId).delete()
        #endif
    }
}
