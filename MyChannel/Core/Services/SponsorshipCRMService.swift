//
//  SponsorshipCRMService.swift
//  MyChannel
//
//  Phase 109: Sponsorship CRM.
//  Campaign brief pipeline, deliverable tracking, creator-brand SLA
//  dashboards. Uses `sponsorship-matcher-ai` and `sponsorship-maximizer`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct SponsorshipCampaign: Codable, Identifiable, Equatable {
    let id: String
    let brandName: String
    let creatorUid: String
    let briefSummary: String
    let budgetUSD: Double
    let status: SponsorshipCampaignStatus
    let deliverables: [Deliverable]
    let slaDeadline: Date?
    let createdAt: Date
}

enum SponsorshipCampaignStatus: String, Codable {
    case proposed, negotiating, active, delivered, completed, cancelled
}

struct Deliverable: Codable, Identifiable, Equatable {
    let id: String
    let type: DeliverableType
    let description: String
    let dueDate: Date?
    let completed: Bool
}

enum DeliverableType: String, Codable, CaseIterable {
    case video, short, story, communityPost, liveStream, mention
}

struct BrandMatch: Codable, Identifiable {
    let id: String
    let brandName: String
    let matchScore: Double
    let category: String
    let estimatedBudget: Double
}

// MARK: - Service

@MainActor
final class SponsorshipCRMService: ObservableObject {
    static let shared = SponsorshipCRMService()
    private init() {}

    @Published private(set) var campaigns: [SponsorshipCampaign] = []
    @Published private(set) var brandMatches: [BrandMatch] = []

    func loadCampaigns(creatorUid: String) async throws {
        guard AppConfig.Features.enableSponsorshipCRM else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("sponsorship_campaigns")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        campaigns = snap.documents.compactMap { doc in
            try? doc.data(as: SponsorshipCampaign.self)
        }
        #endif
    }

    func createCampaign(creatorUid: String, brandName: String, brief: String, budget: Double) async throws {
        guard AppConfig.Features.enableSponsorshipCRM else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("sponsorship_campaigns").document()
            .setData([
                "creatorUid": creatorUid,
                "brandName": brandName,
                "briefSummary": brief,
                "budgetUSD": budget,
                "status": SponsorshipCampaignStatus.proposed.rawValue,
                "deliverables": [],
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func updateDeliverable(campaignId: String, deliverableId: String, completed: Bool) async throws {
        guard AppConfig.Features.enableSponsorshipCRM else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("sponsorship_campaigns").document(campaignId)
        let doc = try await ref.getDocument()
        guard var deliverables = doc.data()?["deliverables"] as? [[String: Any]] else { return }
        if let idx = deliverables.firstIndex(where: { ($0["id"] as? String) == deliverableId }) {
            deliverables[idx]["completed"] = completed
            try await ref.updateData(["deliverables": deliverables])
        }
        #endif
    }

    func matchBrands(creatorUid: String) async throws {
        guard AppConfig.Features.enableSponsorshipCRM else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawMatch: Decodable { let brand_name: String; let score: Double; let category: String; let budget: Double }
        struct Raw: Decodable { let matches: [RawMatch]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMatcherAI,
            path: "/predict",
            body: Request(task: "match_brands", creatorUid: creatorUid)
        )
        brandMatches = (r.matches ?? []).map {
            BrandMatch(id: UUID().uuidString, brandName: $0.brand_name, matchScore: $0.score, category: $0.category, estimatedBudget: $0.budget)
        }
    }

    func generateReport(campaignId: String) async throws -> String {
        guard AppConfig.Features.enableSponsorshipCRM else { return "" }
        struct Request: Encodable { let task: String; let campaignId: String }
        struct Raw: Decodable { let report_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .sponsorshipMaximizer,
            path: "/predict",
            body: Request(task: "generate_report", campaignId: campaignId)
        )
        return r.report_url ?? ""
    }
}
