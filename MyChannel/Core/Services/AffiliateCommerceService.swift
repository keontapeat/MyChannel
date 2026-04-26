//
//  AffiliateCommerceService.swift
//  MyChannel
//
//  Phase 164: Affiliate Commerce Engine.
//  Product tagging in videos, commission tracking, storefront integration.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct ProductTag: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let productName: String
    let productURL: URL?
    let imageURL: URL?
    let priceUSD: Double
    let affiliateNetwork: String
    let commissionPercent: Double
    let timestampSec: Double?
    let positionX: Double?
    let positionY: Double?
}

struct AffiliateEarning: Codable, Identifiable {
    let id: String
    let creatorUid: String
    let productTagId: String
    let clicks: Int
    let conversions: Int
    let revenueUSD: Double
    let period: String
}

// MARK: - Service

@MainActor
final class AffiliateCommerceService: ObservableObject {
    static let shared = AffiliateCommerceService()
    private init() {}

    @Published private(set) var tags: [ProductTag] = []
    @Published private(set) var earnings: [AffiliateEarning] = []
    @Published var visibleTags: [ProductTag] = []

    func loadTags(videoId: String) async throws {
        guard AppConfig.Features.enableAffiliateCommerce else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("product_tags").whereField("videoId", isEqualTo: videoId).getDocuments()
        tags = snap.documents.compactMap { doc in
            let d = doc.data()
            return ProductTag(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                productName: d["productName"] as? String ?? "",
                productURL: (d["productURL"] as? String).flatMap(URL.init(string:)),
                imageURL: (d["imageURL"] as? String).flatMap(URL.init(string:)),
                priceUSD: d["priceUSD"] as? Double ?? 0,
                affiliateNetwork: d["affiliateNetwork"] as? String ?? "",
                commissionPercent: d["commissionPercent"] as? Double ?? 0,
                timestampSec: d["timestampSec"] as? Double,
                positionX: d["positionX"] as? Double, positionY: d["positionY"] as? Double
            )
        }
        #endif
    }

    func updateVisible(currentTime: Double) {
        guard AppConfig.Features.enableAffiliateCommerce else { return }
        visibleTags = tags.filter { tag in
            guard let ts = tag.timestampSec else { return false }
            return currentTime >= ts && currentTime <= ts + 8
        }
    }

    func trackClick(tagId: String) async throws {
        guard AppConfig.Features.enableAffiliateCommerce else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("product_tags").document(tagId)
            .updateData(["clicks": FieldValue.increment(Int64(1))])
        #endif
    }

    func addTag(videoId: String, productName: String, productURL: URL, priceUSD: Double, network: String, commission: Double, timestampSec: Double?) async throws -> String {
        guard AppConfig.Features.enableAffiliateCommerce else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("product_tags").document()
        try await ref.setData([
            "videoId": videoId, "productName": productName,
            "productURL": productURL.absoluteString, "priceUSD": priceUSD,
            "affiliateNetwork": network, "commissionPercent": commission,
            "timestampSec": timestampSec as Any, "clicks": 0
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }
}
