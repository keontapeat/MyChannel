//
//  PublicAPIGatewayV2Service.swift
//  MyChannel
//
//  Phase 220: Public API gateway — rate limiting, API key management,
//  usage quotas, developer portal integration. Uses `mychannel-auth` Cloud Run.
//

import Foundation

struct APIKey: Codable, Identifiable {
    let id: String
    let key: String
    let developerId: String
    let name: String
    let tier: APITier
    let rateLimitPerMin: Int
    let monthlyQuota: Int
    let usedThisMonth: Int
    let createdAt: Date
    let isActive: Bool
    enum APITier: String, Codable { case free, starter, pro, enterprise }
}

struct APIRateLimitStatus: Codable {
    let keyId: String
    let remaining: Int
    let resetAt: Date
    let limit: Int
}

@MainActor
final class PublicAPIGatewayV2Service: ObservableObject {
    static let shared = PublicAPIGatewayV2Service()
    private init() {}
    @Published private(set) var keys: [APIKey] = []

    func createKey(developerId: String, name: String, tier: APIKey.APITier) async throws -> APIKey {
        struct Req: Encodable { let task: String; let developerId: String; let name: String; let tier: String }
        struct Raw: Decodable { let id: String; let key: String; let limit: Int?; let quota: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "create_api_key", developerId: developerId, name: name, tier: tier.rawValue))
        let limits: [APIKey.APITier: Int] = [.free: 60, .starter: 300, .pro: 1500, .enterprise: 10000]
        let quotas: [APIKey.APITier: Int] = [.free: 10000, .starter: 100000, .pro: 1000000, .enterprise: 10000000]
        let k = APIKey(id: r.id, key: r.key, developerId: developerId, name: name, tier: tier,
            rateLimitPerMin: r.limit ?? limits[tier] ?? 60, monthlyQuota: r.quota ?? quotas[tier] ?? 10000,
            usedThisMonth: 0, createdAt: Date(), isActive: true)
        keys.append(k); return k
    }

    func checkRateLimit(keyId: String) async throws -> APIRateLimitStatus {
        struct Req: Encodable { let task: String; let keyId: String }
        struct Raw: Decodable { let remaining: Int?; let reset: String?; let limit: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "check_rate_limit", keyId: keyId))
        return APIRateLimitStatus(keyId: keyId, remaining: r.remaining ?? 0,
            resetAt: r.reset.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date().addingTimeInterval(60), limit: r.limit ?? 60)
    }

    func revokeKey(keyId: String) async throws {
        struct Req: Encodable { let task: String; let keyId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "revoke_api_key", keyId: keyId))
        keys.removeAll { $0.id == keyId }
    }
}
