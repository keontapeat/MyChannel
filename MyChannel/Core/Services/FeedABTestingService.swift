//
//  FeedABTestingService.swift
//  MyChannel
//
//  Phase 277: Feed A/B Testing — layout experiments, ranking experiments,
//  section ordering tests, significance tracking.
//

import Foundation

struct FeedExperimentAssignment: Codable, Identifiable {
    let id: String
    let experimentId: String
    let variant: String
    let assignedAt: Date
}

@MainActor
final class FeedABTestingService: ObservableObject {
    static let shared = FeedABTestingService()
    private init() {}

    @Published private(set) var assignments: [String: FeedExperimentAssignment] = [:]

    func assign(userId: String, experimentId: String) async throws -> String {
        guard AppConfig.Features.enableFeedABTesting else { return "control" }
        struct Req: Encodable { let task: String; let userId: String; let experimentId: String }
        struct Raw: Decodable { let variant: String }
        let r: Raw = try await CloudRunAgentRouter.post(.abTestingAI, path: "/predict", body: Req(task: "assign_feed_experiment", userId: userId, experimentId: experimentId))
        assignments[experimentId] = FeedExperimentAssignment(id: UUID().uuidString, experimentId: experimentId, variant: r.variant, assignedAt: Date())
        return r.variant
    }

    func variant(for experimentId: String) -> String { assignments[experimentId]?.variant ?? "control" }
}
