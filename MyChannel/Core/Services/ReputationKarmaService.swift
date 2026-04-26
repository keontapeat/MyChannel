//
//  ReputationKarmaService.swift
//  MyChannel
//
//  Phase 182: Reputation & Karma Engine.
//  User karma scores, trust tiers, privilege escalation.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct UserKarma: Codable, Identifiable {
    let id: String      // uid
    let score: Int
    let tier: TrustTier
    let badges: [String]
    let positiveActions: Int
    let negativeActions: Int
    let lastUpdated: Date
}

enum TrustTier: String, Codable, CaseIterable {
    case newcomer, member, trusted, expert, guardian
    var privileges: [String] {
        switch self {
        case .newcomer: return ["comment", "like"]
        case .member: return ["comment", "like", "post", "playlist"]
        case .trusted: return ["comment", "like", "post", "playlist", "community_note", "flag"]
        case .expert: return ["comment", "like", "post", "playlist", "community_note", "flag", "moderate"]
        case .guardian: return ["comment", "like", "post", "playlist", "community_note", "flag", "moderate", "appeal_vote"]
        }
    }
}

// MARK: - Service

@MainActor
final class ReputationKarmaService: ObservableObject {
    static let shared = ReputationKarmaService()
    private init() {}

    @Published private(set) var currentKarma: UserKarma?

    func loadKarma(uid: String) async throws {
        guard AppConfig.Features.enableReputationKarma else { return }
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore().collection("user_karma").document(uid).getDocument()
        guard let d = doc.data() else { return }
        currentKarma = UserKarma(
            id: uid, score: d["score"] as? Int ?? 0,
            tier: TrustTier(rawValue: d["tier"] as? String ?? "") ?? .newcomer,
            badges: d["badges"] as? [String] ?? [],
            positiveActions: d["positiveActions"] as? Int ?? 0,
            negativeActions: d["negativeActions"] as? Int ?? 0,
            lastUpdated: (d["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        )
        #endif
    }

    func addPositiveAction(uid: String, action: String) async throws {
        guard AppConfig.Features.enableReputationKarma else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("user_karma").document(uid).setData([
            "score": FieldValue.increment(Int64(1)),
            "positiveActions": FieldValue.increment(Int64(1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }

    func computeTier(uid: String) async throws -> TrustTier {
        guard AppConfig.Features.enableReputationKarma else { return .member }
        struct Request: Encodable { let task: String; let uid: String }
        struct Raw: Decodable { let tier: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "compute_karma_tier", uid: uid)
        )
        return TrustTier(rawValue: r.tier ?? "") ?? .member
    }

    func hasPrivilege(_ privilege: String) -> Bool {
        currentKarma?.tier.privileges.contains(privilege) ?? false
    }
}
