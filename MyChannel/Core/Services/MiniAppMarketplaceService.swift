//
//  MiniAppMarketplaceService.swift
//  MyChannel
//
//  Phase 101: Mini-App Marketplace v1.
//  Discoverable store for third-party mini-apps with quality ranking,
//  revenue-share rails, and moderation review flow.
//  Extends Phase 99 MiniAppSDKService with discovery and commerce.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct MarketplaceListing: Codable, Identifiable, Equatable {
    let id: String
    let miniAppId: String
    let developerName: String
    let title: String
    let description: String
    let iconURL: URL?
    let screenshotURLs: [URL]
    let category: MarketplaceCategory
    let qualityScore: Double          // 0–1, from AI ranking
    let installCount: Int
    let rating: Double                // 1–5 stars
    let revenueSharePercent: Double   // platform take
    let reviewStatus: ReviewStatus
    let publishedAt: Date?
}

enum MarketplaceCategory: String, Codable, CaseIterable {
    case shopping, polls, donations, education, gaming, social, utilities, entertainment
}

enum ReviewStatus: String, Codable {
    case pending, approved, rejected, suspended
}

struct MarketplaceSearchResult: Codable {
    let listings: [MarketplaceListing]
    let totalCount: Int
    let page: Int
}

// MARK: - Service

@MainActor
final class MiniAppMarketplaceService: ObservableObject {
    static let shared = MiniAppMarketplaceService()
    private init() {}

    @Published private(set) var featuredListings: [MarketplaceListing] = []
    @Published private(set) var searchResults: [MarketplaceListing] = []

    // MARK: - Browse

    func loadFeatured() async throws {
        guard AppConfig.Features.enableMiniAppMarketplace else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("mini_app_listings")
            .whereField("reviewStatus", isEqualTo: "approved")
            .order(by: "qualityScore", descending: true)
            .limit(to: 20)
            .getDocuments()
        featuredListings = snap.documents.compactMap { doc in
            let d = doc.data()
            return MarketplaceListing(
                id: doc.documentID,
                miniAppId: d["miniAppId"] as? String ?? "",
                developerName: d["developerName"] as? String ?? "",
                title: d["title"] as? String ?? "",
                description: d["description"] as? String ?? "",
                iconURL: (d["iconURL"] as? String).flatMap(URL.init(string:)),
                screenshotURLs: (d["screenshotURLs"] as? [String])?.compactMap(URL.init(string:)) ?? [],
                category: MarketplaceCategory(rawValue: d["category"] as? String ?? "") ?? .utilities,
                qualityScore: d["qualityScore"] as? Double ?? 0,
                installCount: d["installCount"] as? Int ?? 0,
                rating: d["rating"] as? Double ?? 0,
                revenueSharePercent: d["revenueSharePercent"] as? Double ?? 30,
                reviewStatus: .approved,
                publishedAt: (d["publishedAt"] as? Timestamp)?.dateValue()
            )
        }
        #endif
    }

    // MARK: - Search

    func search(query: String, category: MarketplaceCategory? = nil) async throws {
        guard AppConfig.Features.enableMiniAppMarketplace else { return }
        struct Request: Encodable { let task: String; let query: String; let category: String? }
        struct Raw: Decodable { let listing_ids: [String]?; let scores: [Double]? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .superAITeam,
            path: "/predict",
            body: Request(task: "marketplace_search", query: query, category: category?.rawValue)
        )
        // For v1, reload from Firestore after ranking
        try await loadFeatured()
    }

    // MARK: - Submit for Review

    func submitForReview(miniAppId: String, developerUid: String) async throws {
        guard AppConfig.Features.enableMiniAppMarketplace else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("mini_app_listings").document(miniAppId)
            .setData([
                "miniAppId": miniAppId,
                "developerUid": developerUid,
                "reviewStatus": "pending",
                "submittedAt": FieldValue.serverTimestamp()
            ], merge: true)
        #endif
    }

    // MARK: - Install / Uninstall

    func install(listingId: String, creatorUid: String) async throws {
        guard AppConfig.Features.enableMiniAppMarketplace else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("mini_app_installs").document()
        try await ref.setData([
            "listingId": listingId,
            "creatorUid": creatorUid,
            "installedAt": FieldValue.serverTimestamp()
        ])
        try await Firestore.firestore()
            .collection("mini_app_listings").document(listingId)
            .updateData(["installCount": FieldValue.increment(Int64(1))])
        #endif
    }

    func uninstall(installId: String, listingId: String) async throws {
        guard AppConfig.Features.enableMiniAppMarketplace else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("mini_app_installs").document(installId).delete()
        try await Firestore.firestore()
            .collection("mini_app_listings").document(listingId)
            .updateData(["installCount": FieldValue.increment(Int64(-1))])
        #endif
    }
}
