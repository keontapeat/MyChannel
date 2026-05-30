//
//  PlatformGovernanceService.swift
//  MyChannel
//
//  Phase 140: Platform Constitution & Governance.
//  Community-elected trust council, policy change proposals, public voting, transparency.
//  Uses `trust-safety-ai` + `super-ai-team` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct GovernanceProposal: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let proposerUid: String
    let category: GovernanceCategory
    let status: ProposalStatus
    let votesFor: Int
    let votesAgainst: Int
    let votingDeadline: Date
    let createdAt: Date
}

enum GovernanceCategory: String, Codable, CaseIterable {
    case contentPolicy, monetization, algorithm, privacy, safety, moderation, feature
}

enum ProposalStatus: String, Codable { case draft, voting, approved, rejected, implemented }

struct TrustCouncilMember: Codable, Identifiable, Equatable {
    let id: String
    let uid: String
    let displayName: String
    let region: String
    let termStartDate: Date
    let termEndDate: Date
    let votesReceived: Int
}

struct GovernanceVote: Codable, Identifiable {
    let id: String
    let proposalId: String
    let voterUid: String
    let direction: String   // "for" or "against"
    let reason: String?
    let castedAt: Date
}

struct GovernanceTransparencyReport: Codable, Identifiable {
    let id: String
    let period: String
    let contentRemovals: Int
    let appealRate: Double
    let overturns: Int
    let avgResponseTimeHours: Double
    let generatedAt: Date
}

// MARK: - Service

@MainActor
final class PlatformGovernanceService: ObservableObject {
    static let shared = PlatformGovernanceService()
    init() {}

    @Published private(set) var proposals: [GovernanceProposal] = []
    @Published private(set) var councilMembers: [TrustCouncilMember] = []
    @Published private(set) var latestTransparency: GovernanceTransparencyReport?

    func loadProposals() async throws {
        guard AppConfig.Features.enablePlatformGovernance else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("governance_proposals")
            .order(by: "createdAt", descending: true).limit(to: 30).getDocuments()
        proposals = snap.documents.compactMap { doc in
            let d = doc.data()
            return GovernanceProposal(
                id: doc.documentID, title: d["title"] as? String ?? "",
                description: d["description"] as? String ?? "",
                proposerUid: d["proposerUid"] as? String ?? "",
                category: GovernanceCategory(rawValue: d["category"] as? String ?? "") ?? .contentPolicy,
                status: ProposalStatus(rawValue: d["status"] as? String ?? "") ?? .draft,
                votesFor: d["votesFor"] as? Int ?? 0, votesAgainst: d["votesAgainst"] as? Int ?? 0,
                votingDeadline: (d["votingDeadline"] as? Timestamp)?.dateValue() ?? Date(),
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func submitProposal(title: String, description: String, proposerUid: String, category: GovernanceCategory, votingDays: Int) async throws -> String {
        guard AppConfig.Features.enablePlatformGovernance else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("governance_proposals").document()
        let deadline = Calendar.current.date(byAdding: .day, value: votingDays, to: Date()) ?? Date()
        try await ref.setData([
            "title": title, "description": description, "proposerUid": proposerUid,
            "category": category.rawValue, "status": ProposalStatus.voting.rawValue,
            "votesFor": 0, "votesAgainst": 0,
            "votingDeadline": Timestamp(date: deadline),
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func castVote(proposalId: String, voterUid: String, isFor: Bool, reason: String?) async throws {
        guard AppConfig.Features.enablePlatformGovernance else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("governance_votes").document().setData([
            "proposalId": proposalId, "voterUid": voterUid,
            "direction": isFor ? "for" : "against",
            "reason": reason as Any, "castedAt": FieldValue.serverTimestamp()
        ])
        let field = isFor ? "votesFor" : "votesAgainst"
        try await Firestore.firestore().collection("governance_proposals").document(proposalId)
            .updateData([field: FieldValue.increment(Int64(1))])
        #endif
    }

    func loadCouncil() async throws {
        guard AppConfig.Features.enablePlatformGovernance else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("trust_council").order(by: "votesReceived", descending: true).getDocuments()
        councilMembers = snap.documents.compactMap { doc in
            let d = doc.data()
            return TrustCouncilMember(
                id: doc.documentID, uid: d["uid"] as? String ?? "",
                displayName: d["displayName"] as? String ?? "", region: d["region"] as? String ?? "",
                termStartDate: (d["termStartDate"] as? Timestamp)?.dateValue() ?? Date(),
                termEndDate: (d["termEndDate"] as? Timestamp)?.dateValue() ?? Date(),
                votesReceived: d["votesReceived"] as? Int ?? 0
            )
        }
        #endif
    }

    func generateTransparencyReport() async throws {
        guard AppConfig.Features.enablePlatformGovernance else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable { let period: String?; let removals: Int?; let appeal_rate: Double?; let overturns: Int?; let avg_response_hours: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "transparency_report")
        )
        latestTransparency = GovernanceTransparencyReport(
            id: UUID().uuidString, period: r.period ?? "",
            contentRemovals: r.removals ?? 0, appealRate: r.appeal_rate ?? 0,
            overturns: r.overturns ?? 0, avgResponseTimeHours: r.avg_response_hours ?? 0,
            generatedAt: Date()
        )
    }
}
