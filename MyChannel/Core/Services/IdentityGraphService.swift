//
//  IdentityGraphService.swift
//  MyChannel
//
//  Phase 222: Cross-App Identity Graph.
//  Account linking, device graph, consent-aware profile merge,
//  recovery intelligence, abuse correlation.
//  Uses `mychannel-auth` Cloud Run.
//

import Foundation

// MARK: - Models

struct IdentityNode: Codable, Identifiable {
    let id: String
    let userId: String
    let provider: String
    let providerId: String
    let linkedAt: Date
    let isPrimary: Bool
    let consentStatus: ConsentStatus

    enum ConsentStatus: String, Codable { case granted, denied, pending }
}

struct DeviceNode: Codable, Identifiable {
    let id: String
    let userId: String
    let deviceId: String
    let platform: String
    let lastSeen: Date
    let trustScore: Double
}

struct ProfileMergeResult: Codable {
    let mergedUserId: String
    let sourceIds: [String]
    let conflicts: [MergeConflict]
}

struct MergeConflict: Codable {
    let field: String
    let values: [String]
    let autoResolved: Bool
}

// MARK: - Service

@MainActor
final class IdentityGraphService: ObservableObject {
    static let shared = IdentityGraphService()
    private init() {}

    @Published private(set) var identities: [IdentityNode] = []
    @Published private(set) var devices: [DeviceNode] = []
    @Published private(set) var isLinking: Bool = false

    func fetchIdentityGraph(userId: String) async throws {
        guard AppConfig.Features.enableIdentityGraph else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawId: Decodable { let id: String; let provider: String; let provider_id: String; let linked: String?; let primary: Bool; let consent: String }
        struct RawDev: Decodable { let id: String; let device_id: String; let platform: String; let last_seen: String?; let trust: Double }
        struct Raw: Decodable { let identities: [RawId]?; let devices: [RawDev]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "fetch_identity_graph", userId: userId)
        )
        identities = (r.identities ?? []).map {
            IdentityNode(id: $0.id, userId: userId, provider: $0.provider, providerId: $0.provider_id,
                         linkedAt: ISO8601DateFormatter().date(from: $0.linked ?? "") ?? Date(),
                         isPrimary: $0.primary, consentStatus: .init(rawValue: $0.consent) ?? .pending)
        }
        devices = (r.devices ?? []).map {
            DeviceNode(id: $0.id, userId: userId, deviceId: $0.device_id, platform: $0.platform,
                       lastSeen: ISO8601DateFormatter().date(from: $0.last_seen ?? "") ?? Date(), trustScore: $0.trust)
        }
    }

    func linkAccount(userId: String, provider: String, providerToken: String) async throws -> IdentityNode {
        guard AppConfig.Features.enableIdentityGraph else {
            return IdentityNode(id: "", userId: userId, provider: provider, providerId: "",
                                linkedAt: Date(), isPrimary: false, consentStatus: .pending)
        }
        isLinking = true
        defer { isLinking = false }
        struct Req: Encodable { let task: String; let userId: String; let provider: String; let token: String }
        struct Raw: Decodable { let id: String; let provider_id: String; let consent: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "link_account", userId: userId, provider: provider, token: providerToken)
        )
        let node = IdentityNode(id: r.id, userId: userId, provider: provider, providerId: r.provider_id,
                                 linkedAt: Date(), isPrimary: false, consentStatus: .init(rawValue: r.consent) ?? .pending)
        identities.append(node)
        return node
    }

    func mergeProfiles(sourceIds: [String], targetUserId: String) async throws -> ProfileMergeResult {
        guard AppConfig.Features.enableIdentityGraph else {
            return ProfileMergeResult(mergedUserId: targetUserId, sourceIds: sourceIds, conflicts: [])
        }
        struct Req: Encodable { let task: String; let source_ids: [String]; let target: String }
        struct RawConflict: Decodable { let field: String; let values: [String]; let auto_resolved: Bool }
        struct Raw: Decodable { let merged_id: String; let conflicts: [RawConflict]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "merge_profiles", source_ids: sourceIds, target: targetUserId), timeout: 30
        )
        return ProfileMergeResult(mergedUserId: r.merged_id, sourceIds: sourceIds,
                                   conflicts: (r.conflicts ?? []).map { MergeConflict(field: $0.field, values: $0.values, autoResolved: $0.auto_resolved) })
    }

    func correlateAbuse(userId: String) async throws -> [String] {
        guard AppConfig.Features.enableIdentityGraph else { return [] }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let flags: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "correlate_abuse", userId: userId)
        )
        return r.flags ?? []
    }
}
