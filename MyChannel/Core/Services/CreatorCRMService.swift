//
//  CreatorCRMService.swift
//  MyChannel
//
//  Phase 129: Creator CRM & Audience Segments.
//  Segment builder, targeted messaging, churn-risk alerts, re-engagement flows.
//  Uses `audience-segmentation-ai` + `churn-prevention`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CRMAudienceSegment: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let name: String
    let criteria: [SegmentCriterion]
    let memberCount: Int
    let churnRisk: Double
    let createdAt: Date
}

struct SegmentCriterion: Codable, Equatable {
    let field: String       // e.g. "watchTimeHours", "subscriptionAge", "country"
    let op: String          // ">", "<", "==", "in"
    let value: String
}

struct TargetedMessage: Codable, Identifiable {
    let id: String
    let segmentId: String
    let title: String
    let body: String
    let channel: MessageChannel
    let sentCount: Int
    let openRate: Double
    let sentAt: Date
}

enum MessageChannel: String, Codable, CaseIterable { case push, email, inApp, communityPost }

struct ChurnAlert: Codable, Identifiable {
    let id: String
    let segmentName: String
    let riskLevel: Double
    let atRiskCount: Int
    let suggestedAction: String
}

// MARK: - Service

@MainActor
final class CreatorCRMService: ObservableObject {
    static let shared = CreatorCRMService()
    private init() {}

    @Published private(set) var segments: [CRMAudienceSegment] = []
    @Published private(set) var churnAlerts: [ChurnAlert] = []
    @Published private(set) var messageHistory: [TargetedMessage] = []

    func loadSegments(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorCRM else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("audience_segments").whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true).getDocuments()
        segments = snap.documents.compactMap { doc in
            try? doc.data(as: CRMAudienceSegment.self)
        }
        #endif
    }

    func createSegment(creatorUid: String, name: String, criteria: [SegmentCriterion]) async throws -> String {
        guard AppConfig.Features.enableCreatorCRM else { return "" }
        struct CritPayload: Encodable { let field: String; let op: String; let value: String }
        struct Request: Encodable { let task: String; let creatorUid: String; let criteria: [CritPayload] }
        struct Raw: Decodable { let member_count: Int?; let churn_risk: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Request(task: "build_segment", creatorUid: creatorUid,
                         criteria: criteria.map { CritPayload(field: $0.field, op: $0.op, value: $0.value) })
        )
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("audience_segments").document()
        try await ref.setData([
            "creatorUid": creatorUid, "name": name,
            "criteria": criteria.map { ["field": $0.field, "op": $0.op, "value": $0.value] },
            "memberCount": r.member_count ?? 0, "churnRisk": r.churn_risk ?? 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func sendTargetedMessage(segmentId: String, title: String, body: String, channel: MessageChannel) async throws {
        guard AppConfig.Features.enableCreatorCRM else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("targeted_messages").document().setData([
            "segmentId": segmentId, "title": title, "body": body,
            "channel": channel.rawValue, "sentCount": 0, "openRate": 0,
            "sentAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func detectChurnRisks(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorCRM else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawAlert: Decodable { let segment: String; let risk: Double; let count: Int; let action: String }
        struct Raw: Decodable { let alerts: [RawAlert]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .churnPrevention, path: "/predict",
            body: Request(task: "detect_churn", creatorUid: creatorUid)
        )
        churnAlerts = (r.alerts ?? []).map {
            ChurnAlert(id: UUID().uuidString, segmentName: $0.segment, riskLevel: $0.risk, atRiskCount: $0.count, suggestedAction: $0.action)
        }
    }
}
