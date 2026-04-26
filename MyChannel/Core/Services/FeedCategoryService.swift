//
//  FeedCategoryService.swift
//  MyChannel
//
//  Phase 267: Feed Category Intelligence — auto-categorization,
//  category affinity scoring, cross-category discovery, trending boost.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct FeedCategory: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let affinityScore: Double
    let isTrending: Bool
    let videoCount: Int
}

@MainActor
final class FeedCategoryService: ObservableObject {
    static let shared = FeedCategoryService()
    private init() {}
    @Published private(set) var categories: [FeedCategory] = []
    @Published private(set) var activeCategory: String?

    func fetchCategories(userId: String) async throws {
        guard AppConfig.Features.enableFeedCategory else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawC: Decodable { let id: String; let name: String; let slug: String; let affinity: Double; let trending: Bool; let count: Int }
        struct Raw: Decodable { let categories: [RawC]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "fetch_feed_categories", userId: userId))
        categories = (r.categories ?? []).map {
            FeedCategory(id: $0.id, name: $0.name, slug: $0.slug, affinityScore: $0.affinity, isTrending: $0.trending, videoCount: $0.count)
        }.sorted { $0.affinityScore > $1.affinityScore }
    }

    func selectCategory(_ slug: String?) { activeCategory = slug }

    func crossCategoryDiscover(userId: String, currentCategory: String) async throws -> [String] {
        struct Req: Encodable { let task: String; let userId: String; let category: String }
        struct Raw: Decodable { let suggested_categories: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "cross_category_discover", userId: userId, category: currentCategory))
        return r.suggested_categories ?? []
    }
}
