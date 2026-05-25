//
//  FeedCreatorMixService.swift
//  MyChannel
//
//  Phase 268: Feed Creator Mix — subscribed/suggested/new creator ratio,
//  creator diversity scoring, discovery quota, creator rotation.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct CreatorMixConfig: Codable {
    let subscribedPct: Double
    let suggestedPct: Double
    let newCreatorPct: Double
    let maxConsecutiveSameCreator: Int
    let discoveryQuotaPerFeed: Int
}

@MainActor
final class FeedCreatorMixService: ObservableObject {
    static let shared = FeedCreatorMixService()
    private init() {}
    @Published private(set) var config = CreatorMixConfig(subscribedPct: 0.5, suggestedPct: 0.35, newCreatorPct: 0.15, maxConsecutiveSameCreator: 2, discoveryQuotaPerFeed: 3)

    func fetchMixConfig(userId: String) async throws {
        guard AppConfig.Features.enableFeedCreatorMix else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let subscribed: Double?; let suggested: Double?; let new_creator: Double?; let max_consecutive: Int?; let quota: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
            body: Req(task: "fetch_creator_mix", userId: userId))
        config = CreatorMixConfig(subscribedPct: r.subscribed ?? 0.5, suggestedPct: r.suggested ?? 0.35,
            newCreatorPct: r.new_creator ?? 0.15, maxConsecutiveSameCreator: r.max_consecutive ?? 2, discoveryQuotaPerFeed: r.quota ?? 3)
    }

    func applyMix(subscribed: [String], suggested: [String], newCreators: [String], totalCount: Int) -> [String] {
        let subCount = Int(Double(totalCount) * config.subscribedPct)
        let sugCount = Int(Double(totalCount) * config.suggestedPct)
        let newCount = totalCount - subCount - sugCount
        var result = Array(subscribed.prefix(subCount)) + Array(suggested.prefix(sugCount)) + Array(newCreators.prefix(newCount))
        result.shuffle()
        return result
    }
}
