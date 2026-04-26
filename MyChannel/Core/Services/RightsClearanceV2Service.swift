//
//  RightsClearanceV2Service.swift
//  MyChannel
//
//  Phase 108: Rights & Clearance Console v2.
//  Territory conflict detection, policy packs, pre-publish legal risk
//  checks via `legal-compliance-ai` and `copyright-claims-ai`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct ClearanceRequest: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let creatorUid: String
    let territories: [String]     // ISO 3166-1 alpha-2
    let riskLevel: ClearanceRiskLevel
    let status: ClearanceStatus
    let issues: [ClearanceIssue]
    let createdAt: Date
}

enum ClearanceRiskLevel: String, Codable { case low, medium, high, critical }
enum ClearanceStatus: String, Codable { case pending, cleared, blocked, needsReview }

struct ClearanceIssue: Codable, Equatable {
    let type: IssueType
    let territory: String
    let description: String

    enum IssueType: String, Codable { case copyright, trademark, territorial, ageRating, sanctions }
}

struct PolicyPack: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let rules: [String]
    let territories: [String]
}

// MARK: - Service

@MainActor
final class RightsClearanceV2Service: ObservableObject {
    static let shared = RightsClearanceV2Service()
    private init() {}

    @Published private(set) var clearances: [ClearanceRequest] = []
    @Published private(set) var policyPacks: [PolicyPack] = []

    func loadClearances(creatorUid: String) async throws {
        guard AppConfig.Features.enableRightsClearanceV2 else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("rights_clearances")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        clearances = snap.documents.compactMap { doc in
            try? doc.data(as: ClearanceRequest.self)
        }
        #endif
    }

    func assessRisk(videoId: String, territories: [String]) async throws -> ClearanceRequest {
        guard AppConfig.Features.enableRightsClearanceV2 else {
            return ClearanceRequest(id: "", videoId: videoId, creatorUid: "", territories: territories, riskLevel: .low, status: .cleared, issues: [], createdAt: Date())
        }
        struct Request: Encodable { let task: String; let videoId: String; let territories: [String] }
        struct RawIssue: Decodable { let type: String; let territory: String; let description: String }
        struct Raw: Decodable { let risk_level: String?; let status: String?; let issues: [RawIssue]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .legalCompliance,
            path: "/predict",
            body: Request(task: "assess_risk", videoId: videoId, territories: territories)
        )
        return ClearanceRequest(
            id: UUID().uuidString,
            videoId: videoId,
            creatorUid: "",
            territories: territories,
            riskLevel: ClearanceRiskLevel(rawValue: r.risk_level ?? "low") ?? .low,
            status: ClearanceStatus(rawValue: r.status ?? "cleared") ?? .cleared,
            issues: (r.issues ?? []).map {
                ClearanceIssue(type: ClearanceIssue.IssueType(rawValue: $0.type) ?? .copyright, territory: $0.territory, description: $0.description)
            },
            createdAt: Date()
        )
    }

    func submitClearanceRequest(videoId: String, creatorUid: String, territories: [String]) async throws {
        guard AppConfig.Features.enableRightsClearanceV2 else { return }
        let assessment = try await assessRisk(videoId: videoId, territories: territories)
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("rights_clearances").document()
            .setData([
                "videoId": videoId,
                "creatorUid": creatorUid,
                "territories": territories,
                "riskLevel": assessment.riskLevel.rawValue,
                "status": assessment.status.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func loadPolicyPacks() async throws {
        guard AppConfig.Features.enableRightsClearanceV2 else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("policy_packs").getDocuments()
        policyPacks = snap.documents.compactMap { doc in
            let d = doc.data()
            return PolicyPack(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                description: d["description"] as? String ?? "",
                rules: d["rules"] as? [String] ?? [],
                territories: d["territories"] as? [String] ?? []
            )
        }
        #endif
    }
}
