//
//  CreatorNetworkService.swift
//  MyChannel
//
//  Phase 229: Multi-Brand Creator Network.
//  Portfolio channel management, shared assets, network permissions,
//  sponsorship coordination.
//  Uses `sponsorship-matcher-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct CreatorNetwork: Codable, Identifiable {
    let id: String
    let name: String
    let ownerUserId: String
    let channels: [NetworkChannel]
    let sharedAssets: [SharedAsset]
    let permissions: [NetworkPermission]

    struct NetworkChannel: Codable, Identifiable {
        let id: String
        let channelId: String
        let role: String
        let joinedAt: Date
    }

    struct SharedAsset: Codable, Identifiable {
        let id: String
        let type: String
        let url: String
        let accessLevel: String
    }

    struct NetworkPermission: Codable {
        let userId: String
        let role: String
        let canPost: Bool
        let canManage: Bool
        let canSponsor: Bool
    }
}

struct SponsorshipOpportunity: Codable, Identifiable {
    let id: String
    let brandName: String
    let budget: Double
    let targetChannels: [String]
    let status: String
}

// MARK: - Service

@MainActor
final class CreatorNetworkService: ObservableObject {
    static let shared = CreatorNetworkService()
    private init() {}

    @Published private(set) var networks: [CreatorNetwork] = []
    @Published private(set) var opportunities: [SponsorshipOpportunity] = []

    func fetchNetworks(userId: String) async throws {
        guard AppConfig.Features.enableCreatorNetwork else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawNet: Decodable { let id: String; let name: String; let owner: String }
        struct Raw: Decodable { let networks: [RawNet]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcherAI, path: "/predict",
            body: Req(task: "fetch_networks", userId: userId)
        )
        networks = (r.networks ?? []).map {
            CreatorNetwork(id: $0.id, name: $0.name, ownerUserId: $0.owner, channels: [], sharedAssets: [], permissions: [])
        }
    }

    func createNetwork(name: String, ownerUserId: String) async throws -> CreatorNetwork {
        guard AppConfig.Features.enableCreatorNetwork else {
            return CreatorNetwork(id: "", name: name, ownerUserId: ownerUserId, channels: [], sharedAssets: [], permissions: [])
        }
        struct Req: Encodable { let task: String; let name: String; let owner: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcherAI, path: "/predict",
            body: Req(task: "create_network", name: name, owner: ownerUserId)
        )
        let net = CreatorNetwork(id: r.id, name: name, ownerUserId: ownerUserId, channels: [], sharedAssets: [], permissions: [])
        networks.append(net)
        return net
    }

    func addChannel(networkId: String, channelId: String, role: String) async throws {
        guard AppConfig.Features.enableCreatorNetwork else { return }
        struct Req: Encodable { let task: String; let networkId: String; let channelId: String; let role: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcherAI, path: "/predict",
            body: Req(task: "add_channel", networkId: networkId, channelId: channelId, role: role)
        )
    }

    func findSponsorships(networkId: String) async throws {
        guard AppConfig.Features.enableCreatorNetwork else { return }
        struct Req: Encodable { let task: String; let networkId: String }
        struct RawOpp: Decodable { let id: String; let brand: String; let budget: Double; let targets: [String]?; let status: String }
        struct Raw: Decodable { let opportunities: [RawOpp]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcherAI, path: "/predict",
            body: Req(task: "find_sponsorships", networkId: networkId), timeout: 30
        )
        opportunities = (r.opportunities ?? []).map {
            SponsorshipOpportunity(id: $0.id, brandName: $0.brand, budget: $0.budget,
                                    targetChannels: $0.targets ?? [], status: $0.status)
        }
    }
}
