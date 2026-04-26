//
//  InteractiveVideoService.swift
//  MyChannel
//
//  Phase 131: Interactive Video (Branching Narratives).
//  Choice overlays, branching paths, analytics per branch, creator editor.
//  Uses `super-ai-team` for branch generation.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct InteractiveProject: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let title: String
    let rootNodeId: String
    let nodeCount: Int
    let totalPlays: Int
    let createdAt: Date
}

struct BranchNode: Codable, Identifiable, Equatable {
    let id: String
    let projectId: String
    let videoSegmentURL: URL?
    let startSec: Double
    let endSec: Double
    let choices: [BranchChoice]
}

struct BranchChoice: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let targetNodeId: String
    let position: ChoicePosition
}

enum ChoicePosition: String, Codable { case topLeft, topRight, bottomLeft, bottomRight, center }

struct BranchAnalytics: Codable, Identifiable {
    let id: String        // nodeId
    let nodeId: String
    let views: Int
    let choiceDistribution: [String: Int]   // choiceId → count
    let avgWatchPercent: Double
}

// MARK: - Service

@MainActor
final class InteractiveVideoService: ObservableObject {
    static let shared = InteractiveVideoService()
    private init() {}

    @Published private(set) var project: InteractiveProject?
    @Published private(set) var nodes: [BranchNode] = []
    @Published private(set) var analytics: [BranchAnalytics] = []

    func loadProject(projectId: String) async throws {
        guard AppConfig.Features.enableInteractiveVideo else { return }
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore().collection("interactive_projects").document(projectId).getDocument()
        guard let d = doc.data() else { return }
        project = InteractiveProject(
            id: doc.documentID, creatorUid: d["creatorUid"] as? String ?? "",
            title: d["title"] as? String ?? "", rootNodeId: d["rootNodeId"] as? String ?? "",
            nodeCount: d["nodeCount"] as? Int ?? 0, totalPlays: d["totalPlays"] as? Int ?? 0,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        #endif
    }

    func createProject(creatorUid: String, title: String) async throws -> String {
        guard AppConfig.Features.enableInteractiveVideo else { return "" }
        #if canImport(FirebaseFirestore)
        let rootNode = Firestore.firestore().collection("branch_nodes").document()
        let ref = Firestore.firestore().collection("interactive_projects").document()
        try await ref.setData([
            "creatorUid": creatorUid, "title": title, "rootNodeId": rootNode.documentID,
            "nodeCount": 1, "totalPlays": 0, "createdAt": FieldValue.serverTimestamp()
        ])
        try await rootNode.setData([
            "projectId": ref.documentID, "startSec": 0, "endSec": 0, "choices": []
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func addNode(projectId: String, videoSegmentURL: String, startSec: Double, endSec: Double, choices: [BranchChoice]) async throws -> String {
        guard AppConfig.Features.enableInteractiveVideo else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("branch_nodes").document()
        try await ref.setData([
            "projectId": projectId, "videoSegmentURL": videoSegmentURL,
            "startSec": startSec, "endSec": endSec,
            "choices": choices.map { ["id": $0.id, "label": $0.label, "targetNodeId": $0.targetNodeId, "position": $0.position.rawValue] }
        ])
        try await Firestore.firestore().collection("interactive_projects").document(projectId)
            .updateData(["nodeCount": FieldValue.increment(Int64(1))])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func recordChoice(nodeId: String, choiceId: String) async throws {
        guard AppConfig.Features.enableInteractiveVideo else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("branch_analytics").document(nodeId)
            .setData(["choiceDistribution.\(choiceId)": FieldValue.increment(Int64(1)),
                      "views": FieldValue.increment(Int64(1))], merge: true)
        #endif
    }

    func generateBranches(videoId: String) async throws -> [BranchChoice] {
        guard AppConfig.Features.enableInteractiveVideo else { return [] }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawChoice: Decodable { let label: String; let position: String }
        struct Raw: Decodable { let choices: [RawChoice]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "generate_branches", videoId: videoId)
        )
        return (r.choices ?? []).map {
            BranchChoice(id: UUID().uuidString, label: $0.label, targetNodeId: "",
                        position: ChoicePosition(rawValue: $0.position) ?? .center)
        }
    }
}
