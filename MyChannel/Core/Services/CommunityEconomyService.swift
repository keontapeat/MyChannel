//
//  CommunityEconomyService.swift
//  MyChannel
//
//  Phase 233: Community Economy Layer.
//  Bounties for mods, clippers, translators, reputation-linked earning rails,
//  quality scoring.
//  Uses `creator-fund-allocator` + `content-quality-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct Bounty: Codable, Identifiable {
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let role: BountyRole
    let reward: Double
    let currency: String
    let claimCount: Int
    let maxClaims: Int
    let status: BountyStatus
    let createdAt: Date

    enum BountyRole: String, Codable { case mod, clipper, translator, curator, reviewer }
    enum BountyStatus: String, Codable { case open, inProgress, completed, cancelled }
}

struct BountyClaim: Codable, Identifiable {
    let id: String
    let bountyId: String
    let userId: String
    let qualityScore: Double
    let status: String
    let submittedAt: Date
    let paidAt: Date?
}

struct ReputationScore: Codable {
    let userId: String
    let totalScore: Double
    let level: String
    let completedBounties: Int
    let avgQuality: Double
}

// MARK: - Service

@MainActor
final class CommunityEconomyService: ObservableObject {
    static let shared = CommunityEconomyService()
    private init() {}

    @Published private(set) var bounties: [Bounty] = []
    @Published private(set) var claims: [BountyClaim] = []
    @Published private(set) var reputation: ReputationScore?

    func fetchBounties(creatorId: String) async throws {
        guard AppConfig.Features.enableCommunityEconomy else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawB: Decodable { let id: String; let title: String; let desc: String; let role: String; let reward: Double; let currency: String; let claims: Int; let max: Int; let status: String; let created: String? }
        struct Raw: Decodable { let bounties: [RawB]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Req(task: "fetch_bounties", creatorId: creatorId)
        )
        bounties = (r.bounties ?? []).map {
            Bounty(id: $0.id, creatorId: creatorId, title: $0.title, description: $0.desc,
                   role: .init(rawValue: $0.role) ?? .mod, reward: $0.reward, currency: $0.currency,
                   claimCount: $0.claims, maxClaims: $0.max, status: .init(rawValue: $0.status) ?? .open,
                   createdAt: $0.created.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }

    func createBounty(creatorId: String, title: String, role: Bounty.BountyRole, reward: Double, maxClaims: Int) async throws -> Bounty {
        guard AppConfig.Features.enableCommunityEconomy else {
            return Bounty(id: "", creatorId: creatorId, title: title, description: "", role: role,
                          reward: reward, currency: "USD", claimCount: 0, maxClaims: maxClaims, status: .open, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let title: String; let role: String; let reward: Double; let max: Int }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Req(task: "create_bounty", creatorId: creatorId, title: title, role: role.rawValue, reward: reward, max: maxClaims)
        )
        let bounty = Bounty(id: r.id, creatorId: creatorId, title: title, description: "", role: role,
                              reward: reward, currency: "USD", claimCount: 0, maxClaims: maxClaims, status: .open, createdAt: Date())
        bounties.append(bounty)
        return bounty
    }

    func claimBounty(bountyId: String, userId: String) async throws -> BountyClaim {
        guard AppConfig.Features.enableCommunityEconomy else {
            return BountyClaim(id: "", bountyId: bountyId, userId: userId, qualityScore: 0, status: "pending", submittedAt: Date(), paidAt: nil)
        }
        struct Req: Encodable { let task: String; let bountyId: String; let userId: String }
        struct Raw: Decodable { let id: String; let quality: Double?; let status: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Req(task: "claim_bounty", bountyId: bountyId, userId: userId)
        )
        let claim = BountyClaim(id: r.id, bountyId: bountyId, userId: userId, qualityScore: r.quality ?? 0,
                                 status: r.status, submittedAt: Date(), paidAt: nil)
        claims.append(claim)
        return claim
    }

    func scoreQuality(submissionId: String, content: String) async throws -> Double {
        guard AppConfig.Features.enableCommunityEconomy else { return 0 }
        struct Req: Encodable { let task: String; let submissionId: String; let content: String }
        struct Raw: Decodable { let score: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .contentQuality, path: "/predict",
            body: Req(task: "score_quality", submissionId: submissionId, content: content)
        )
        return r.score ?? 0
    }

    func fetchReputation(userId: String) async throws {
        guard AppConfig.Features.enableCommunityEconomy else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let score: Double?; let level: String?; let completed: Int?; let avg_quality: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Req(task: "fetch_reputation", userId: userId)
        )
        reputation = ReputationScore(userId: userId, totalScore: r.score ?? 0, level: r.level ?? "bronze",
                                      completedBounties: r.completed ?? 0, avgQuality: r.avg_quality ?? 0)
    }
}
