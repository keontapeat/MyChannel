//
//  LiveCommerceService.swift
//  MyChannel
//
//  Phase 172: Live Commerce & Auctions.
//  Real-time bidding, product drops, countdown timers, payment integration.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct LiveProduct: Codable, Identifiable, Equatable {
    let id: String
    let streamId: String
    let name: String
    let imageURL: URL?
    let priceUSD: Double
    let stock: Int
    let status: String
}

struct LiveAuction: Codable, Identifiable {
    let id: String
    let streamId: String
    let productId: String
    let startingBidUSD: Double
    let currentBidUSD: Double
    let currentBidderUid: String?
    let endsAt: Date
    let status: String
}

struct ProductDrop: Codable, Identifiable {
    let id: String
    let streamId: String
    let productId: String
    let dropsAt: Date
    let quantity: Int
    let claimed: Int
}

// MARK: - Service

@MainActor
final class LiveCommerceService: ObservableObject {
    static let shared = LiveCommerceService()
    private init() {}

    @Published private(set) var products: [LiveProduct] = []
    @Published private(set) var auctions: [LiveAuction] = []
    @Published private(set) var drops: [ProductDrop] = []
    @Published var featuredProduct: LiveProduct?

    func loadProducts(streamId: String) async throws {
        guard AppConfig.Features.enableLiveCommerce else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("live_products").whereField("streamId", isEqualTo: streamId).getDocuments()
        products = snap.documents.compactMap { doc in
            let d = doc.data()
            return LiveProduct(id: doc.documentID, streamId: d["streamId"] as? String ?? "",
                             name: d["name"] as? String ?? "",
                             imageURL: (d["imageURL"] as? String).flatMap(URL.init(string:)),
                             priceUSD: d["priceUSD"] as? Double ?? 0,
                             stock: d["stock"] as? Int ?? 0, status: d["status"] as? String ?? "active")
        }
        #endif
    }

    func placeBid(auctionId: String, bidderUid: String, amountUSD: Double) async throws {
        guard AppConfig.Features.enableLiveCommerce else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("live_auctions").document(auctionId)
            .updateData(["currentBidUSD": amountUSD, "currentBidderUid": bidderUid])
        #endif
    }

    func createDrop(streamId: String, productId: String, dropsAt: Date, quantity: Int) async throws -> String {
        guard AppConfig.Features.enableLiveCommerce else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("product_drops").document()
        try await ref.setData([
            "streamId": streamId, "productId": productId,
            "dropsAt": Timestamp(date: dropsAt), "quantity": quantity, "claimed": 0
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func claimDrop(dropId: String, uid: String) async throws -> Bool {
        guard AppConfig.Features.enableLiveCommerce else { return false }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("product_drops").document(dropId)
            .updateData(["claimed": FieldValue.increment(Int64(1))])
        return true
        #else
        return false
        #endif
    }
}
