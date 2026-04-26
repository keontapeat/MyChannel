//
//  AppealDisputeService.swift
//  MyChannel
//
//  Phase 183: Appeal & Dispute Resolution.
//  Creator appeals, community jury, automated review queue.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct Appeal: Codable, Identifiable {
    let id: String
    let creatorUid: String
    let contentId: String
    let contentType: String
    let reason: String
    let evidence: String
    let status: AppealStatus
    let juryVotes: Int
    let createdAt: Date
    let resolvedAt: Date?
}

enum AppealStatus: String, Codable { case submitted, inReview, juryVote, upheld, overturned, rejected }

struct JuryVote: Codable {
    let appealId: String
    let jurorUid: String
    let vote: String
    let reason: String
}

// MARK: - Service

@MainActor
final class AppealDisputeService: ObservableObject {
    static let shared = AppealDisputeService()
    private init() {}

    @Published private(set) var appeals: [Appeal] = []

    func submitAppeal(creatorUid: String, contentId: String, contentType: String, reason: String, evidence: String) async throws -> String {
        guard AppConfig.Features.enableAppealDispute else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("appeals").document()
        try await ref.setData([
            "creatorUid": creatorUid, "contentId": contentId, "contentType": contentType,
            "reason": reason, "evidence": evidence, "status": AppealStatus.submitted.rawValue,
            "juryVotes": 0, "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func loadAppeals(uid: String) async throws {
        guard AppConfig.Features.enableAppealDispute else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("appeals").whereField("creatorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true).getDocuments()
        appeals = snap.documents.compactMap { doc in
            let d = doc.data()
            return Appeal(
                id: doc.documentID, creatorUid: d["creatorUid"] as? String ?? "",
                contentId: d["contentId"] as? String ?? "", contentType: d["contentType"] as? String ?? "",
                reason: d["reason"] as? String ?? "", evidence: d["evidence"] as? String ?? "",
                status: AppealStatus(rawValue: d["status"] as? String ?? "") ?? .submitted,
                juryVotes: d["juryVotes"] as? Int ?? 0,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                resolvedAt: (d["resolvedAt"] as? Timestamp)?.dateValue()
            )
        }
        #endif
    }

    func castJuryVote(appealId: String, jurorUid: String, vote: String, reason: String) async throws {
        guard AppConfig.Features.enableAppealDispute else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("jury_votes").document().setData([
            "appealId": appealId, "jurorUid": jurorUid, "vote": vote, "reason": reason
        ])
        try await Firestore.firestore().collection("appeals").document(appealId)
            .updateData(["juryVotes": FieldValue.increment(Int64(1))])
        #endif
    }
}
