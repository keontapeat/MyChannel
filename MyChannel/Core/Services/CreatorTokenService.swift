//
//  CreatorTokenService.swift
//  MyChannel
//
//  Phase 165: Creator Token Economy.
//  Fan tokens, token-gated content, staking rewards.
//  Uses `creator-fund-allocator` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CreatorToken: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let symbol: String
    let totalSupply: Int
    let circulatingSupply: Int
    let pricePerToken: Double
    let createdAt: Date
}

struct TokenBalance: Codable, Identifiable {
    let id: String
    let uid: String
    let tokenId: String
    let balance: Int
    let stakedAmount: Int
}

struct TokenGatedContent: Codable, Identifiable {
    let id: String
    let videoId: String
    let tokenId: String
    let minTokensRequired: Int
}

// MARK: - Service

@MainActor
final class CreatorTokenService: ObservableObject {
    static let shared = CreatorTokenService()
    private init() {}

    @Published private(set) var tokens: [CreatorToken] = []
    @Published private(set) var balances: [TokenBalance] = []

    func loadTokens(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorTokens else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("creator_tokens").whereField("creatorUid", isEqualTo: creatorUid).getDocuments()
        tokens = snap.documents.compactMap { doc in
            let d = doc.data()
            return CreatorToken(
                id: doc.documentID, creatorUid: d["creatorUid"] as? String ?? "",
                symbol: d["symbol"] as? String ?? "", totalSupply: d["totalSupply"] as? Int ?? 0,
                circulatingSupply: d["circulatingSupply"] as? Int ?? 0,
                pricePerToken: d["pricePerToken"] as? Double ?? 0,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func buyTokens(uid: String, tokenId: String, amount: Int) async throws {
        guard AppConfig.Features.enableCreatorTokens else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("token_balances").document("\(uid)_\(tokenId)")
        try await ref.setData(["uid": uid, "tokenId": tokenId, "balance": FieldValue.increment(Int64(amount)), "stakedAmount": 0], merge: true)
        #endif
    }

    func stakeTokens(uid: String, tokenId: String, amount: Int) async throws {
        guard AppConfig.Features.enableCreatorTokens else { return }
        struct Request: Encodable { let task: String; let uid: String; let tokenId: String; let amount: Int }
        struct Raw: Decodable { let reward_rate: Double? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Request(task: "stake_tokens", uid: uid, tokenId: tokenId, amount: amount)
        )
    }

    func canAccessGatedContent(uid: String, videoId: String) async -> Bool {
        guard AppConfig.Features.enableCreatorTokens else { return true }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let videoDoc = try await db.collection("videos").document(videoId).getDocument()
            guard let data = videoDoc.data(),
                  let creatorId = data["creatorId"] as? String,
                  let isGated = data["isGated"] as? Bool,
                  isGated else { return true }
            let tokenDoc = try await db.collection("user_tokens").document("\(uid)_\(creatorId)").getDocument()
            guard let tokenData = tokenDoc.data(),
                  let balance = tokenData["balance"] as? Int,
                  balance > 0 else { return false }
            return true
        } catch {
            print("⚠️ [CreatorTokenService] Error checking gated content: \(error)")
            return false
        }
        #else
        return true
        #endif
    }

    func createToken(creatorUid: String, symbol: String, totalSupply: Int, pricePerToken: Double) async throws -> String {
        guard AppConfig.Features.enableCreatorTokens else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("creator_tokens").document()
        try await ref.setData([
            "creatorUid": creatorUid, "symbol": symbol, "totalSupply": totalSupply,
            "circulatingSupply": 0, "pricePerToken": pricePerToken,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }
}
