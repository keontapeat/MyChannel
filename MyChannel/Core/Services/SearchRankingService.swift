//
//  SearchRankingService.swift
//  MyChannel
//
//  Search result ranking: relevance scoring, personalization,
//  freshness boosting, engagement signals. Uses `recommendations` Cloud Run.
//

import Foundation

struct RankedResult: Codable, Identifiable {
    let id: String
    let contentId: String
    let contentType: String
    let title: String
    let thumbnailURL: String?
    let relevanceScore: Double
    let personalizationBoost: Double
    let freshnessBoost: Double
    let finalScore: Double
}

struct RankingConfig: Codable {
    let relevanceWeight: Double
    let personalizationWeight: Double
    let freshnessWeight: Double
    let engagementWeight: Double
}

@MainActor
final class SearchRankingService: ObservableObject {
    static let shared = SearchRankingService()
    private init() {}
    @Published private(set) var config: RankingConfig = RankingConfig(relevanceWeight: 0.4, personalizationWeight: 0.25, freshnessWeight: 0.15, engagementWeight: 0.2)

    func rank(query: String, userId: String?, limit: Int = 20) async throws -> [RankedResult] {
        struct Req: Encodable { let task: String; let query: String; let userId: String?; let limit: Int }
        struct RawR: Decodable { let id: String; let content_id: String; let type: String; let title: String; let thumbnail: String?; let relevance: Double; let personalization: Double; let freshness: Double; let final: Double }
        struct Raw: Decodable { let results: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "rank_search_results", query: query, userId: userId, limit: limit))
        return (r.results ?? []).map {
            RankedResult(id: $0.id, contentId: $0.content_id, contentType: $0.type, title: $0.title, thumbnailURL: $0.thumbnail,
                relevanceScore: $0.relevance, personalizationBoost: $0.personalization, freshnessBoost: $0.freshness, finalScore: $0.final)
        }
    }

    func updateConfig(relevance: Double, personalization: Double, freshness: Double, engagement: Double) async throws {
        struct Req: Encodable { let task: String; let relevance: Double; let personalization: Double; let freshness: Double; let engagement: Double }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "update_ranking_config", relevance: relevance, personalization: personalization, freshness: freshness, engagement: engagement))
        config = RankingConfig(relevanceWeight: relevance, personalizationWeight: personalization, freshnessWeight: freshness, engagementWeight: engagement)
    }
}
