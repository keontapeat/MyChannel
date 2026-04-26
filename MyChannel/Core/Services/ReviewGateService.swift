//
//  ReviewGateService.swift
//  MyChannel
//
//  Phase 204: Review gate — human approval for AI actions.
//  Approval workflows, escalation, audit trail. Uses `trust-safety-ai` Cloud Run.
//

import Foundation

struct ReviewItem: Codable, Identifiable {
    let id: String
    let actionType: String
    let actionDescription: String
    let requestedBy: String
    let riskLevel: RiskLevel
    let status: ReviewStatus
    let createdAt: Date
    let reviewedAt: Date?
    let reviewerId: String?
    let decision: String?
    let notes: String?
    enum RiskLevel: String, Codable { case low, medium, high, critical }
    enum ReviewStatus: String, Codable { case pending, approved, rejected, escalated, expired }
}

@MainActor
final class ReviewGateService: ObservableObject {
    static let shared = ReviewGateService()
    private init() {}
    @Published private(set) var pending: [ReviewItem] = []
    @Published private(set) var history: [ReviewItem] = []

    func submitForReview(actionType: String, description: String, requestedBy: String, riskLevel: ReviewItem.RiskLevel) async throws -> ReviewItem {
        struct Req: Encodable { let task: String; let actionType: String; let description: String; let requestedBy: String; let risk: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "submit_for_review", actionType: actionType, description: description, requestedBy: requestedBy, risk: riskLevel.rawValue))
        let item = ReviewItem(id: r.id, actionType: actionType, actionDescription: description, requestedBy: requestedBy,
            riskLevel: riskLevel, status: .pending, createdAt: Date(), reviewedAt: nil, reviewerId: nil, decision: nil, notes: nil)
        pending.append(item); return item
    }

    func approve(itemId: String, reviewerId: String, notes: String?) async throws {
        struct Req: Encodable { let task: String; let itemId: String; let reviewerId: String; let decision: String; let notes: String? }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "review_decision", itemId: itemId, reviewerId: reviewerId, decision: "approved", notes: notes))
        moveFromPending(itemId: itemId, status: .approved, reviewerId: reviewerId, decision: "approved", notes: notes)
    }

    func reject(itemId: String, reviewerId: String, notes: String?) async throws {
        struct Req: Encodable { let task: String; let itemId: String; let reviewerId: String; let decision: String; let notes: String? }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "review_decision", itemId: itemId, reviewerId: reviewerId, decision: "rejected", notes: notes))
        moveFromPending(itemId: itemId, status: .rejected, reviewerId: reviewerId, decision: "rejected", notes: notes)
    }

    func escalate(itemId: String, reviewerId: String) async throws {
        struct Req: Encodable { let task: String; let itemId: String; let reviewerId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "escalate_review", itemId: itemId, reviewerId: reviewerId))
        moveFromPending(itemId: itemId, status: .escalated, reviewerId: reviewerId, decision: "escalated", notes: nil)
    }

    private func moveFromPending(itemId: String, status: ReviewItem.ReviewStatus, reviewerId: String, decision: String?, notes: String?) {
        guard let idx = pending.firstIndex(where: { $0.id == itemId }) else { return }
        let old = pending.remove(at: idx)
        let completed = ReviewItem(id: old.id, actionType: old.actionType, actionDescription: old.actionDescription,
            requestedBy: old.requestedBy, riskLevel: old.riskLevel, status: status, createdAt: old.createdAt,
            reviewedAt: Date(), reviewerId: reviewerId, decision: decision, notes: notes)
        history.insert(completed, at: 0)
    }
}
