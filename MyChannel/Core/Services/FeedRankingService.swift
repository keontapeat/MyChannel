//
//  FeedRankingService.swift
//  MyChannel
//
//  Phase 266: Personalized Feed Ranking — relevance scoring, freshness decay,
//  diversity injection, creator affinity, watch-time prediction.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct RankedFeedItem: Codable, Identifiable {
    let id: String
    let videoId: String
    let relevanceScore: Double
    let freshnessScore: Double
    let affinityScore: Double
    let diversityBoost: Double
    let finalScore: Double
    let reason: String
}

@MainActor
final class FeedRankingService: ObservableObject {
    static let shared = FeedRankingService()
    private init() {}
    @Published private(set) var rankedItems: [RankedFeedItem] = []

    func rankFeed(userId: String, candidateIds: [String]) async throws {
        guard AppConfig.Features.enableFeedRanking else { return }
        struct Req: Encodable { let task: String; let userId: String; let candidates: [String] }
        struct RawR: Decodable { let id: String; let videoId: String; let relevance: Double; let freshness: Double; let affinity: Double; let diversity: Double; let final_score: Double; let reason: String }
        struct Raw: Decodable { let ranked: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "rank_feed", userId: userId, candidates: candidateIds))
        rankedItems = (r.ranked ?? []).map {
            RankedFeedItem(id: $0.id, videoId: $0.videoId, relevanceScore: $0.relevance, freshnessScore: $0.freshness,
                affinityScore: $0.affinity, diversityBoost: $0.diversity, finalScore: $0.final_score, reason: $0.reason)
        }
    }

    func injectDiversity(items: [RankedFeedItem], maxConsecutiveSameCreator: Int = 2) -> [RankedFeedItem] {
        var result: [RankedFeedItem] = []
        var pending = items
        var lastCreatorIds: [String] = []
        while !pending.isEmpty {
            if let idx = pending.firstIndex(where: { item in
                let count = lastCreatorIds.suffix(maxConsecutiveSameCreator).filter { $0 == item.videoId }.count
                return count < maxConsecutiveSameCreator
            }) {
                result.append(pending.remove(at: idx))
                lastCreatorIds.append(result.last!.videoId)
            } else {
                result.append(pending.removeFirst())
            }
        }
        return result
    }
}
