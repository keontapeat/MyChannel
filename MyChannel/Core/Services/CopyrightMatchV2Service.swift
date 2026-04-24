//
//  CopyrightMatchV2Service.swift
//  MyChannel
//
//  Phase 74: Copyright Match v2.
//  Audio + video fingerprinting + the existing `ContentIDService` pipeline,
//  with a claim/dispute flow and revenue-hold escrow backed by the
//  `copyright-claims-ai` Cloud Run agent.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum CopyrightMatchType: String, Codable {
    case audioChromaprint      // Chromaprint audio fingerprint
    case videoPhash            // perceptual video hash
    case exactCopy             // bitwise duplicate
    case derivative            // remix detection
}

enum CopyrightClaimStatus: String, Codable {
    case pending
    case active
    case disputed
    case released
    case takedown
}

struct CopyrightMatch: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let matchedAssetId: String       // partner catalog id
    let rightsHolderId: String
    let matchType: CopyrightMatchType
    let confidence: Double           // 0..1
    let startSeconds: Double
    let endSeconds: Double
    let createdAt: Date
}

struct CopyrightClaim: Codable, Identifiable, Equatable {
    let id: String
    let match: CopyrightMatch
    let status: CopyrightClaimStatus
    /// USD held in escrow while the claim is active / disputed.
    let heldRevenueUSD: Decimal
    let policy: String               // "monetize_claimant" / "block" / "track_only"
    let createdAt: Date
    let updatedAt: Date
}

struct CopyrightDispute: Codable, Identifiable {
    let id: String
    let claimId: String
    let creatorUid: String
    let reason: String
    let evidenceURLs: [URL]
    let createdAt: Date
}

@MainActor
final class CopyrightMatchV2Service: ObservableObject {
    static let shared = CopyrightMatchV2Service()
    private init() {}

    // MARK: - Scan

    /// Kick off a fingerprint scan right after transcoding finishes.
    func scan(videoId: String, audioURL: URL?, videoURL: URL) async throws -> [CopyrightMatch] {
        guard AppConfig.Features.enableCopyrightMatchV2 else { return [] }
        struct Request: Encodable {
            let task: String
            let videoId: String
            let audioURL: String?
            let videoURL: String
        }
        struct RawMatch: Decodable {
            let id: String
            let matched_asset_id: String
            let rights_holder_id: String
            let match_type: String
            let confidence: Double
            let start_seconds: Double
            let end_seconds: Double
        }
        struct Raw: Decodable { let matches: [RawMatch]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .copyrightDetectorAI,
            path: "/predict",
            body: Request(
                task: "scan",
                videoId: videoId,
                audioURL: audioURL?.absoluteString,
                videoURL: videoURL.absoluteString
            ),
            timeout: 60
        )
        return (r.matches ?? []).map {
            CopyrightMatch(
                id: $0.id,
                videoId: videoId,
                matchedAssetId: $0.matched_asset_id,
                rightsHolderId: $0.rights_holder_id,
                matchType: CopyrightMatchType(rawValue: $0.match_type) ?? .audioChromaprint,
                confidence: $0.confidence,
                startSeconds: $0.start_seconds,
                endSeconds: $0.end_seconds,
                createdAt: Date()
            )
        }
    }

    // MARK: - Claims

    func listClaims(videoId: String) async throws -> [CopyrightClaim] {
        guard AppConfig.Features.enableCopyrightMatchV2 else { return [] }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("videos").document(videoId)
            .collection("copyrightClaims").getDocuments()
        return snap.documents.compactMap { doc -> CopyrightClaim? in
            let d = doc.data()
            guard
                let statusRaw = d["status"] as? String,
                let status = CopyrightClaimStatus(rawValue: statusRaw),
                let matchData = d["match"] as? [String: Any],
                let matchId = matchData["id"] as? String
            else { return nil }

            let match = CopyrightMatch(
                id: matchId,
                videoId: videoId,
                matchedAssetId: matchData["matchedAssetId"] as? String ?? "",
                rightsHolderId: matchData["rightsHolderId"] as? String ?? "",
                matchType: CopyrightMatchType(rawValue: matchData["matchType"] as? String ?? "audioChromaprint") ?? .audioChromaprint,
                confidence: matchData["confidence"] as? Double ?? 0,
                startSeconds: matchData["startSeconds"] as? Double ?? 0,
                endSeconds: matchData["endSeconds"] as? Double ?? 0,
                createdAt: (matchData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
            let held = d["heldRevenueUSD"] as? Double ?? 0
            return CopyrightClaim(
                id: doc.documentID,
                match: match,
                status: status,
                heldRevenueUSD: Decimal(held),
                policy: d["policy"] as? String ?? "track_only",
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #else
        return []
        #endif
    }

    // MARK: - Dispute

    func dispute(_ dispute: CopyrightDispute) async throws {
        guard AppConfig.Features.enableCopyrightMatchV2 else { throw CopyError.disabled }
        struct Request: Encodable {
            let task: String
            let claimId: String
            let creatorUid: String
            let reason: String
            let evidenceURLs: [String]
        }
        _ = try await CloudRunAgentRouter.post(
            .copyrightClaims,
            path: "/predict",
            body: Request(
                task: "dispute",
                claimId: dispute.claimId,
                creatorUid: dispute.creatorUid,
                reason: dispute.reason,
                evidenceURLs: dispute.evidenceURLs.map { $0.absoluteString }
            )
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum CopyError: LocalizedError {
        case disabled
        var errorDescription: String? { "Copyright Match v2 is disabled." }
    }
}
