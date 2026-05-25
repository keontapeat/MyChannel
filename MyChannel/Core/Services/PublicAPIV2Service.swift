//
//  PublicAPIV2Service.swift
//  MyChannel
//
//  Phase 103: Public API v2 + Usage Tiers.
//  Metered API key plans, rotation, webhook retries, tenant-level quotas.
//  Uses `api-shield` and `rate-limiter-ai` Cloud Run services.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct PublicAPIClient: Codable, Identifiable, Equatable {
    let id: String
    let ownerUid: String
    let name: String
    let apiKey: String
    let tier: APITier
    let monthlyQuota: Int
    let usedThisMonth: Int
    let webhookURL: URL?
    let active: Bool
    let createdAt: Date
}

enum APITier: String, Codable, CaseIterable {
    case free       // 1 000 req/mo
    case starter    // 50 000 req/mo
    case pro        // 500 000 req/mo
    case enterprise // unlimited
}

struct APIUsageSnapshot: Codable {
    let clientId: String
    let date: Date
    let requestCount: Int
    let errorCount: Int
    let avgLatencyMs: Double
    let rateLimitHits: Int
}

// MARK: - Service

@MainActor
final class PublicAPIV2Service: ObservableObject {
    static let shared = PublicAPIV2Service()
    private init() {}

    @Published private(set) var clients: [PublicAPIClient] = []
    @Published private(set) var usageSnapshots: [APIUsageSnapshot] = []

    func loadClients(ownerUid: String) async throws {
        guard AppConfig.Features.enablePublicAPIV2 else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("api_clients")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .getDocuments()
        clients = snap.documents.compactMap { doc in
            let d = doc.data()
            return PublicAPIClient(
                id: doc.documentID,
                ownerUid: d["ownerUid"] as? String ?? "",
                name: d["name"] as? String ?? "",
                apiKey: d["apiKey"] as? String ?? "",
                tier: APITier(rawValue: d["tier"] as? String ?? "") ?? .free,
                monthlyQuota: d["monthlyQuota"] as? Int ?? 1000,
                usedThisMonth: d["usedThisMonth"] as? Int ?? 0,
                webhookURL: (d["webhookURL"] as? String).flatMap(URL.init(string:)),
                active: d["active"] as? Bool ?? true,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func issueKey(ownerUid: String, name: String, tier: APITier) async throws -> String {
        guard AppConfig.Features.enablePublicAPIV2 else { return "" }
        let newKey = "mc_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32))"
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("api_clients").document()
        try await ref.setData([
            "ownerUid": ownerUid,
            "name": name,
            "apiKey": newKey,
            "tier": tier.rawValue,
            "monthlyQuota": quotaForTier(tier),
            "usedThisMonth": 0,
            "active": true,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
        return newKey
    }

    func rotateKey(clientId: String) async throws -> String {
        guard AppConfig.Features.enablePublicAPIV2 else { return "" }
        let newKey = "mc_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32))"
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("api_clients").document(clientId)
            .updateData(["apiKey": newKey])
        #endif
        return newKey
    }

    func revokeKey(clientId: String) async throws {
        guard AppConfig.Features.enablePublicAPIV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("api_clients").document(clientId)
            .updateData(["active": false])
        #endif
    }

    func checkQuota(clientId: String) async throws -> Bool {
        guard AppConfig.Features.enablePublicAPIV2 else { return true }
        struct Request: Encodable { let task: String; let clientId: String }
        struct Raw: Decodable { let within_quota: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .rateLimiterAI,
            path: "/predict",
            body: Request(task: "check_quota", clientId: clientId)
        )
        return r.within_quota ?? true
    }

    private func quotaForTier(_ tier: APITier) -> Int {
        switch tier {
        case .free: return 1_000
        case .starter: return 50_000
        case .pro: return 500_000
        case .enterprise: return 10_000_000
        }
    }
}
