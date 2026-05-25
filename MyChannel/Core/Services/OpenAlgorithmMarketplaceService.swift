//
//  OpenAlgorithmMarketplaceService.swift
//  MyChannel
//
//  Phase 139: Open Algorithm Marketplace.
//  Pluggable feed algorithms, creator-chosen ranking, transparency reports per algo.
//  Uses `ab-testing-ai` + `recommendations` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct FeedAlgorithm: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let developerName: String
    let description: String
    let version: String
    let category: AlgoCategory
    let popularity: Int
    let transparencyScore: Double  // 0–1
    let approved: Bool
    let createdAt: Date
}

enum AlgoCategory: String, Codable, CaseIterable {
    case chronological, engagement, discovery, educational, serendipity, community
}

struct AlgoTransparencyReport: Codable, Identifiable {
    let id: String
    let algorithmId: String
    let signalsUsed: [String]
    let boostFactors: [String: Double]
    let penaltyFactors: [String: Double]
    let biasAuditScore: Double
    let generatedAt: Date
}

struct AlgoSelection: Codable, Identifiable {
    let id: String
    let uid: String
    let algorithmId: String
    let selectedAt: Date
}

// MARK: - Service

@MainActor
final class OpenAlgorithmMarketplaceService: ObservableObject {
    static let shared = OpenAlgorithmMarketplaceService()
    private init() {}

    @Published private(set) var availableAlgorithms: [FeedAlgorithm] = []
    @Published private(set) var activeAlgoId: String?
    @Published private(set) var transparencyReport: AlgoTransparencyReport?

    func loadAlgorithms() async throws {
        guard AppConfig.Features.enableOpenAlgorithmMarketplace else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("feed_algorithms").whereField("approved", isEqualTo: true)
            .order(by: "popularity", descending: true).getDocuments()
        availableAlgorithms = snap.documents.compactMap { doc in
            let d = doc.data()
            return FeedAlgorithm(
                id: doc.documentID, name: d["name"] as? String ?? "",
                developerName: d["developerName"] as? String ?? "",
                description: d["description"] as? String ?? "",
                version: d["version"] as? String ?? "1.0",
                category: AlgoCategory(rawValue: d["category"] as? String ?? "") ?? .engagement,
                popularity: d["popularity"] as? Int ?? 0,
                transparencyScore: d["transparencyScore"] as? Double ?? 0,
                approved: true,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func selectAlgorithm(uid: String, algorithmId: String) async throws {
        guard AppConfig.Features.enableOpenAlgorithmMarketplace else { return }
        activeAlgoId = algorithmId
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("algo_selections").document(uid).setData([
            "uid": uid, "algorithmId": algorithmId, "selectedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func viewTransparency(algorithmId: String) async throws {
        guard AppConfig.Features.enableOpenAlgorithmMarketplace else { return }
        struct Request: Encodable { let task: String; let algorithmId: String }
        struct Raw: Decodable { let signals: [String]?; let boosts: [String: Double]?; let penalties: [String: Double]?; let bias_score: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .abTestingAI, path: "/predict",
            body: Request(task: "algo_transparency", algorithmId: algorithmId)
        )
        transparencyReport = AlgoTransparencyReport(
            id: UUID().uuidString, algorithmId: algorithmId,
            signalsUsed: r.signals ?? [], boostFactors: r.boosts ?? [:],
            penaltyFactors: r.penalties ?? [:], biasAuditScore: r.bias_score ?? 0,
            generatedAt: Date()
        )
    }

    func rankWithAlgo(algorithmId: String, userId: String, candidateVideoIds: [String]) async throws -> [String] {
        guard AppConfig.Features.enableOpenAlgorithmMarketplace else { return candidateVideoIds }
        struct Request: Encodable { let task: String; let algorithmId: String; let userId: String; let candidates: [String] }
        struct Raw: Decodable { let ranked: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "rank_with_algo", algorithmId: algorithmId, userId: userId, candidates: candidateVideoIds)
        )
        return r.ranked ?? candidateVideoIds
    }

    func submitAlgorithm(name: String, developerName: String, description: String, category: AlgoCategory) async throws -> String {
        guard AppConfig.Features.enableOpenAlgorithmMarketplace else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("feed_algorithms").document()
        try await ref.setData([
            "name": name, "developerName": developerName, "description": description,
            "version": "1.0", "category": category.rawValue, "popularity": 0,
            "transparencyScore": 0, "approved": false, "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }
}
