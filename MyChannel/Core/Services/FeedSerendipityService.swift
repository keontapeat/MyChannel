//
//  FeedSerendipityService.swift
//  MyChannel
//
//  Phase 270: Feed Serendipity Engine — unexpected discovery injection,
//  exploration vs exploitation balance, novelty scoring, surprise-and-delight.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct SerendipityItem: Codable, Identifiable {
    let id: String
    let videoId: String
    let noveltyScore: Double
    let surpriseFactor: Double
    let reason: String
    let category: String
}

@MainActor
final class FeedSerendipityService: ObservableObject {
    static let shared = FeedSerendipityService()
    private init() {}
    @Published private(set) var serendipityItems: [SerendipityItem] = []
    @Published var explorationRate: Double = 0.15

    func fetchSerendipity(userId: String, feedSize: Int = 20) async throws {
        guard AppConfig.Features.enableFeedSerendipity else { return }
        let count = max(1, Int(Double(feedSize) * explorationRate))
        struct Req: Encodable { let task: String; let userId: String; let count: Int }
        struct RawS: Decodable { let id: String; let videoId: String; let novelty: Double; let surprise: Double; let reason: String; let category: String }
        struct Raw: Decodable { let items: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "fetch_serendipity", userId: userId, count: count))
        serendipityItems = (r.items ?? []).map {
            SerendipityItem(id: $0.id, videoId: $0.videoId, noveltyScore: $0.novelty, surpriseFactor: $0.surprise, reason: $0.reason, category: $0.category)
        }
    }

    func adjustExplorationRate(engagement: Double) {
        if engagement > 0.7 { explorationRate = min(0.25, explorationRate + 0.02) }
        else if engagement < 0.3 { explorationRate = max(0.05, explorationRate - 0.02) }
    }
}
