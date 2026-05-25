//
//  BlockchainService.swift
//  MyChannel
//
//  Blockchain integration: content provenance, NFT minting,
//  ownership verification, Polygon chain. Uses `trust-safety-ai` Cloud Run.
//

import Foundation

struct BlockchainRecord: Codable, Identifiable {
    let id: String
    let contentId: String
    let txHash: String
    let blockNumber: Int
    let chain: String
    let timestamp: Date
    let verifiedAt: Date?
}

struct NFTMintRequest: Codable, Identifiable {
    let id: String
    let contentId: String
    let creatorId: String
    let tokenURI: String
    let contractAddress: String
    let tokenId: String?
    let status: MintStatus
    let mintedAt: Date?
    enum MintStatus: String, Codable { case pending, minted, failed }
}

@MainActor
final class BlockchainService: ObservableObject {
    static let shared = BlockchainService()
    private init() {}
    @Published private(set) var records: [BlockchainRecord] = []
    @Published private(set) var nfts: [NFTMintRequest] = []

    func registerProvenance(contentId: String, creatorId: String, metadata: [String: String]) async throws -> BlockchainRecord {
        struct Req: Encodable { let task: String; let contentId: String; let creatorId: String; let metadata: [String: String] }
        struct Raw: Decodable { let id: String; let txHash: String; let block: Int; let chain: String }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "register_provenance", contentId: contentId, creatorId: creatorId, metadata: metadata), timeout: 30)
        let record = BlockchainRecord(id: r.id, contentId: contentId, txHash: r.txHash, blockNumber: r.block, chain: r.chain, timestamp: Date(), verifiedAt: nil)
        records.append(record); return record
    }

    func verifyProvenance(contentId: String) async throws -> BlockchainRecord? {
        struct Req: Encodable { let task: String; let contentId: String }
        struct Raw: Decodable { let id: String; let txHash: String; let block: Int; let chain: String; let verified: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "verify_provenance", contentId: contentId))
        guard !r.id.isEmpty else { return nil }
        return BlockchainRecord(id: r.id, contentId: contentId, txHash: r.txHash, blockNumber: r.block, chain: r.chain,
            timestamp: Date(), verifiedAt: r.verified.flatMap { ISO8601DateFormatter().date(from: $0) })
    }

    func mintNFT(contentId: String, creatorId: String, tokenURI: String) async throws -> NFTMintRequest {
        struct Req: Encodable { let task: String; let contentId: String; let creatorId: String; let tokenURI: String }
        struct Raw: Decodable { let id: String; let contract: String; let tokenId: String?; let status: String }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "mint_nft", contentId: contentId, creatorId: creatorId, tokenURI: tokenURI), timeout: 45)
        let nft = NFTMintRequest(id: r.id, contentId: contentId, creatorId: creatorId, tokenURI: tokenURI,
            contractAddress: r.contract, tokenId: r.tokenId, status: .init(rawValue: r.status) ?? .pending, mintedAt: r.status == "minted" ? Date() : nil)
        nfts.append(nft); return nft
    }
}
