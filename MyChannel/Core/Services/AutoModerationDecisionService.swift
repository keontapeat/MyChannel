//
//  AutoModerationDecisionService.swift
//  MyChannel
//
//  Phase 887: Automated Moderation Decision Engine
//  AI-driven auto-moderation with confidence scoring, policy-based auto-action
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AutoModerationDecisionService: ObservableObject {
    static let shared = AutoModerationDecisionService()

    // MARK: - Domain Models

    struct ModerationDecision: Identifiable, Codable {
        let id: String
        let contentId: String
        let contentType: ContentType
        let creatorId: String
        let creatorName: String
        let violationType: String
        let confidence: Double
        let decision: DecisionType
        let autoAction: AutoAction
        let policyRule: String
        let timestamp: Date
        let reviewedBy: String?
        let appealable: Bool
        let appealStatus: AppealStatus?
    }

    enum ContentType: String, Codable {
        case video = "VIDEO"
        case comment = "COMMENT"
        case story = "STORY"
        case live = "LIVE"
        case profile = "PROFILE"
        case thumbnail = "THUMBNAIL"
    }

    enum DecisionType: String, Codable {
        case autoApproved = "AUTO_APPROVED"
        case autoRemoved = "AUTO_REMOVED"
        case autoAgeGated = "AUTO_AGE_GATED"
        case autoWarned = "AUTO_WARNED"
        case humanReview = "HUMAN_REVIEW"
    }

    enum AutoAction: String, Codable {
        case none = "NONE"
        case remove = "REMOVE"
        case ageGate = "AGE_GATE"
        case warn = "WARN"
        case strike = "STRIKE"
        case shadowBlock = "SHADOW_BLOCK"
    }

    enum AppealStatus: String, Codable {
        case pending = "PENDING"
        case upheld = "UPHELD"
        case overturned = "OVERTURNED"
    }

    struct ModerationVelocity: Codable {
        let autoDecisionsPerHour: Int
        let humanReviewsPerHour: Int
        let avgDecisionTimeMs: Double
        let autoApprovalRate: Double
        let falsePositiveRate: Double
    }

    // MARK: - Published State

    @Published private(set) var pendingDecisions: [ModerationDecision] = []
    @Published private(set) var recentDecisions: [ModerationDecision] = []
    @Published private(set) var velocity: ModerationVelocity?
    @Published private(set) var autoApprovedToday: Int = 0
    @Published private(set) var autoRemovedToday: Int = 0
    @Published private(set) var humanReviewQueue: Int = 0

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://auto-moderation-decision-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableAutoModerationDecision else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableAutoModerationDecision else { return }

        // Load pending human review decisions
        let pendingSnap = try? await db.collection("moderationDecisions")
            .whereField("decision", isEqualTo: "HUMAN_REVIEW")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        pendingDecisions = pendingSnap?.documents.compactMap { parseDecision($0.data(), id: $0.documentID) } ?? []
        humanReviewQueue = pendingDecisions.count

        // Load recent decisions
        let recentSnap = try? await db.collection("moderationDecisions")
            .order(by: "timestamp", descending: true)
            .limit(to: 30)
            .getDocuments()
        recentDecisions = recentSnap?.documents.compactMap { parseDecision($0.data(), id: $0.documentID) } ?? []

        autoApprovedToday = recentDecisions.filter { $0.decision == .autoApproved && Calendar.current.isDateInToday($0.timestamp) }.count
        autoRemovedToday = recentDecisions.filter { $0.decision == .autoRemoved && Calendar.current.isDateInToday($0.timestamp) }.count

        // Cloud Run for velocity metrics
        if let result = await callCloudRun(endpoint: "velocity") {
            velocity = ModerationVelocity(
                autoDecisionsPerHour: result["autoDecisionsPerHour"] as? Int ?? 0,
                humanReviewsPerHour: result["humanReviewsPerHour"] as? Int ?? 0,
                avgDecisionTimeMs: result["avgDecisionTimeMs"] as? Double ?? 0,
                autoApprovalRate: result["autoApprovalRate"] as? Double ?? 0,
                falsePositiveRate: result["falsePositiveRate"] as? Double ?? 0
            )
        }
    }

    // MARK: - Actions

    func submitForAutoDecision(contentId: String, contentType: ContentType, creatorId: String, creatorName: String) async -> ModerationDecision? {
        let result = await callCloudRun(endpoint: "decide", body: [
            "contentId": contentId,
            "contentType": contentType.rawValue,
            "creatorId": creatorId,
            "creatorName": creatorName
        ])
        guard let result else { return nil }

        let decision = ModerationDecision(
            id: result["id"] as? String ?? UUID().uuidString,
            contentId: contentId,
            contentType: contentType,
            creatorId: creatorId,
            creatorName: creatorName,
            violationType: result["violationType"] as? String ?? "none",
            confidence: result["confidence"] as? Double ?? 0,
            decision: DecisionType(rawValue: result["decision"] as? String ?? "") ?? .humanReview,
            autoAction: AutoAction(rawValue: result["autoAction"] as? String ?? "") ?? .none,
            policyRule: result["policyRule"] as? String ?? "",
            timestamp: Date(),
            reviewedBy: nil,
            appealable: result["appealable"] as? Bool ?? true,
            appealStatus: nil
        )

        // Persist to Firestore
        try? await db.collection("moderationDecisions").document(decision.id).setData([
            "contentId": contentId, "contentType": contentType.rawValue,
            "creatorId": creatorId, "creatorName": creatorName,
            "violationType": decision.violationType, "confidence": decision.confidence,
            "decision": decision.decision.rawValue, "autoAction": decision.autoAction.rawValue,
            "policyRule": decision.policyRule, "timestamp": Timestamp(date: Date()),
            "appealable": decision.appealable
        ])

        return decision
    }

    func humanOverride(_ decisionId: String, newDecision: DecisionType, reviewer: String) async {
        try? await db.collection("moderationDecisions").document(decisionId).updateData([
            "decision": newDecision.rawValue,
            "reviewedBy": reviewer,
            "reviewedAt": Timestamp(date: Date())
        ])
        _ = await callCloudRun(endpoint: "feedback", body: [
            "decisionId": decisionId,
            "override": newDecision.rawValue,
            "reviewer": reviewer
        ])
    }

    // MARK: - Helpers

    private func parseDecision(_ d: [String: Any], id: String) -> ModerationDecision? {
        guard let contentType = ContentType(rawValue: d["contentType"] as? String ?? ""),
              let decision = DecisionType(rawValue: d["decision"] as? String ?? "") else { return nil }
        return ModerationDecision(
            id: id,
            contentId: d["contentId"] as? String ?? "",
            contentType: contentType,
            creatorId: d["creatorId"] as? String ?? "",
            creatorName: d["creatorName"] as? String ?? "",
            violationType: d["violationType"] as? String ?? "",
            confidence: d["confidence"] as? Double ?? 0,
            decision: decision,
            autoAction: AutoAction(rawValue: d["autoAction"] as? String ?? "") ?? .none,
            policyRule: d["policyRule"] as? String ?? "",
            timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            reviewedBy: d["reviewedBy"] as? String,
            appealable: d["appealable"] as? Bool ?? true,
            appealStatus: AppealStatus(rawValue: d["appealStatus"] as? String ?? "")
        )
    }
}
