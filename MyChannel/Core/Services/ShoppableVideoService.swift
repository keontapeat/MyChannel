//
//  ShoppableVideoService.swift
//  MyChannel
//
//  Phase 56: Shoppable video (IAP-safe path).
//  Creators tag products on a timeline. The tag opens the merchant URL
//  in the external browser (compliant with App Store Guideline 3.1.1 until
//  a certified Apple Pay merchant flow is added).
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct VideoProductTag: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let productId: String        // SKU / internal id
    let title: String
    let imageURL: URL?
    let price: Decimal?
    let currency: String?
    let merchantURL: URL         // external link opened via SFSafariViewController
    let affiliateCode: String?
    let startSeconds: Double     // appears at this time
    let endSeconds: Double       // disappears at
    let position: CGPoint        // 0..1 normalized on screen
}

@MainActor
final class ShoppableVideoService: ObservableObject {
    static let shared = ShoppableVideoService()
    private init() {}

    @Published private(set) var tagsByVideo: [String: [VideoProductTag]] = [:]

    // MARK: - Fetch tags for a video

    func loadTags(videoId: String) async throws -> [VideoProductTag] {
        guard AppConfig.Features.enableShoppableVideo else { return [] }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("videos").document(videoId)
            .collection("productTags")
            .order(by: "startSeconds")
            .getDocuments()

        let tags = snap.documents.compactMap { doc -> VideoProductTag? in
            let d = doc.data()
            guard
                let urlStr = d["merchantURL"] as? String,
                let merchantURL = URL(string: urlStr)
            else { return nil }
            var price: Decimal? = nil
            if let p = d["price"] as? Double { price = Decimal(p) }
            return VideoProductTag(
                id: doc.documentID,
                videoId: videoId,
                productId: d["productId"] as? String ?? "",
                title: d["title"] as? String ?? "",
                imageURL: (d["imageURL"] as? String).flatMap(URL.init),
                price: price,
                currency: d["currency"] as? String,
                merchantURL: merchantURL,
                affiliateCode: d["affiliateCode"] as? String,
                startSeconds: d["startSeconds"] as? Double ?? 0,
                endSeconds: d["endSeconds"] as? Double ?? 0,
                position: CGPoint(
                    x: (d["positionX"] as? Double) ?? 0.5,
                    y: (d["positionY"] as? Double) ?? 0.5
                )
            )
        }
        tagsByVideo[videoId] = tags
        return tags
        #else
        return []
        #endif
    }

    // MARK: - Authoring (Creator Studio)

    func addTag(_ tag: VideoProductTag) async throws {
        guard AppConfig.Features.enableShoppableVideo else { throw ShoppableError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("videos").document(tag.videoId)
            .collection("productTags").document(tag.id)
            .setData([
                "productId": tag.productId,
                "title": tag.title,
                "imageURL": tag.imageURL?.absoluteString as Any,
                "price": (tag.price as NSDecimalNumber?)?.doubleValue as Any,
                "currency": tag.currency as Any,
                "merchantURL": tag.merchantURL.absoluteString,
                "affiliateCode": tag.affiliateCode as Any,
                "startSeconds": tag.startSeconds,
                "endSeconds": tag.endSeconds,
                "positionX": Double(tag.position.x),
                "positionY": Double(tag.position.y)
            ])
        #endif
    }

    // MARK: - Attribution click tracking

    func trackClick(videoId: String, tagId: String, uid: String?) async {
        struct Request: Encodable {
            let task: String
            let videoId: String
            let tagId: String
            let uid: String?
        }
        _ = try? await CloudRunAgentRouter.post(
            .shoppingAIv2,
            path: "/predict",
            body: Request(task: "click", videoId: videoId, tagId: tagId, uid: uid)
        ) as _Ack
    }

    // MARK: - AI suggestions

    /// Returns ranked product suggestions for a given creator+video based on
    /// `shopping-ai-v2`. Used in Creator Studio to autofill tags.
    func suggestProducts(videoId: String, creatorId: String) async throws -> [VideoProductTag] {
        guard AppConfig.Features.enableShoppableVideo else { return [] }
        struct Request: Encodable {
            let task: String
            let videoId: String
            let creatorId: String
        }
        struct Raw: Decodable {
            struct Item: Decodable {
                let product_id: String
                let title: String
                let image_url: String?
                let price: Double?
                let currency: String?
                let merchant_url: String
                let affiliate_code: String?
                let start_seconds: Double
                let end_seconds: Double
            }
            let items: [Item]?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .shoppingAIv2,
            path: "/predict",
            body: Request(task: "suggest", videoId: videoId, creatorId: creatorId)
        )
        return (r.items ?? []).compactMap { item in
            guard let url = URL(string: item.merchant_url) else { return nil }
            return VideoProductTag(
                id: UUID().uuidString,
                videoId: videoId,
                productId: item.product_id,
                title: item.title,
                imageURL: item.image_url.flatMap(URL.init),
                price: item.price.map { Decimal($0) },
                currency: item.currency,
                merchantURL: url,
                affiliateCode: item.affiliate_code,
                startSeconds: item.start_seconds,
                endSeconds: item.end_seconds,
                position: CGPoint(x: 0.8, y: 0.8)
            )
        }
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum ShoppableError: LocalizedError {
        case disabled
        var errorDescription: String? { "Shoppable video is not enabled." }
    }
}
