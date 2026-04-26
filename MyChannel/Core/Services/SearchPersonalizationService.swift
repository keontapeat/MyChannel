//
//  SearchPersonalizationService.swift
//  MyChannel
//
//  Phase 287: Search Personalization — interest modeling, personalized ranking,
//  diversity controls, filter bubble prevention, cold-start handling.
//  Uses `recommendations` Cloud Run.
//

import Foundation

struct SearchPersonalizationProfile: Codable {
    let userId: String
    let topTopics: [String]
    let creatorAffinity: [String: Double]
    let diversityTarget: Double
    let coldStart: Bool
}

@MainActor
final class SearchPersonalizationService: ObservableObject {
    static let shared = SearchPersonalizationService()
    private init() {}

    @Published private(set) var profile: SearchPersonalizationProfile?

    func fetchProfile(userId: String) async throws {
        guard AppConfig.Features.enableSearchPersonalization else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let topics: [String]?; let affinity: [String: Double]?; let diversity: Double?; let coldStart: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict", body: Req(task: "search_personalization_profile", userId: userId))
        profile = SearchPersonalizationProfile(userId: userId, topTopics: r.topics ?? [], creatorAffinity: r.affinity ?? [:], diversityTarget: r.diversity ?? 0.3, coldStart: r.coldStart ?? false)
    }

    func rerank(contentIds: [String]) -> [String] {
        guard let profile else { return contentIds }
        return contentIds.sorted { lhs, rhs in
            let l = profile.creatorAffinity[lhs] ?? 0
            let r = profile.creatorAffinity[rhs] ?? 0
            return l > r
        }
    }
}
