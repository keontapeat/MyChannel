//
//  NFTCollectiblesService.swift
//  MyChannel
//
//  Phase 162: NFT & Digital Collectibles.
//  Creator-minted collectibles, blockchain verification, marketplace.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct DigitalCollectible: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let title: String
    let description: String
    let mediaURL: URL?
    let edition: Int
    let totalEditions: Int
    let priceUSD: Double
    let ownerUid: String?
    let mintedAt: Date
    let blockchainRef: String?
}

struct CollectibleListing: Codable, Identifiable {
    let id: String
    let collectibleId: String
    let sellerUid: String
    let askingPriceUSD: Double
    let status: String
    let listedAt: Date
}

// MARK: - Service

@MainActor
final class NFTCollectiblesService: ObservableObject {
    static let shared = NFTCollectiblesService()
    private init() {}

    @Published private(set) var collectibles: [DigitalCollectible] = []
    @Published private(set) var marketplace: [CollectibleListing] = []

    func loadCreatorCollectibles(creatorUid: String) async throws {
        guard AppConfig.Features.enableNFTCollectibles else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("collectibles").whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "mintedAt", descending: true).getDocuments()
        collectibles = snap.documents.compactMap { doc in
            let d = doc.data()
            return DigitalCollectible(
                id: doc.documentID, creatorUid: d["creatorUid"] as? String ?? "",
                title: d["title"] as? String ?? "", description: d["description"] as? String ?? "",
                mediaURL: (d["mediaURL"] as? String).flatMap(URL.init(string:)),
                edition: d["edition"] as? Int ?? 1, totalEditions: d["totalEditions"] as? Int ?? 1,
                priceUSD: d["priceUSD"] as? Double ?? 0, ownerUid: d["ownerUid"] as? String,
                mintedAt: (d["mintedAt"] as? Timestamp)?.dateValue() ?? Date(),
                blockchainRef: d["blockchainRef"] as? String
            )
        }
        #endif
    }

    func mint(creatorUid: String, title: String, description: String, mediaURL: URL?, totalEditions: Int, priceUSD: Double) async throws -> String {
        guard AppConfig.Features.enableNFTCollectibles else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("collectibles").document()
        try await ref.setData([
            "creatorUid": creatorUid, "title": title, "description": description,
            "mediaURL": mediaURL?.absoluteString as Any, "edition": 1,
            "totalEditions": totalEditions, "priceUSD": priceUSD,
            "mintedAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func loadMarketplace() async throws {
        guard AppConfig.Features.enableNFTCollectibles else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("collectible_listings").whereField("status", isEqualTo: "active")
            .order(by: "listedAt", descending: true).limit(to: 50).getDocuments()
        marketplace = snap.documents.compactMap { doc in
            let d = doc.data()
            return CollectibleListing(
                id: doc.documentID, collectibleId: d["collectibleId"] as? String ?? "",
                sellerUid: d["sellerUid"] as? String ?? "",
                askingPriceUSD: d["askingPriceUSD"] as? Double ?? 0,
                status: d["status"] as? String ?? "", listedAt: (d["listedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }
}
