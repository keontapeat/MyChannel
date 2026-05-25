//
//  DataLineageEngine.swift
//  MyChannel
//
//  Data lineage tracking: origin, transformations, dependencies.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct LineageNode: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let upstream: [String]
    let downstream: [String]
    let lastModified: Date
}

struct LineageGraph: Codable {
    let nodes: [LineageNode]
    let edges: [LineageEdge]
    struct LineageEdge: Codable { let from: String; let to: String; let transform: String }
}

@MainActor
final class DataLineageEngine: ObservableObject {
    static let shared = DataLineageEngine()
    private init() {}
    @Published private(set) var graph: LineageGraph?

    func fetchLineage(datasetId: String) async throws {
        struct Req: Encodable { let task: String; let datasetId: String }
        struct RawN: Decodable { let id: String; let name: String; let type: String; let upstream: [String]; let downstream: [String]; let modified: String? }
        struct RawE: Decodable { let from: String; let to: String; let transform: String }
        struct Raw: Decodable { let nodes: [RawN]?; let edges: [RawE]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_lineage", datasetId: datasetId))
        graph = LineageGraph(
            nodes: (r.nodes ?? []).map { LineageNode(id: $0.id, name: $0.name, type: $0.type, upstream: $0.upstream, downstream: $0.downstream,
                lastModified: $0.modified.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()) },
            edges: (r.edges ?? []).map { LineageGraph.LineageEdge(from: $0.from, to: $0.to, transform: $0.transform) })
    }

    func trackTransform(inputId: String, outputId: String, transform: String) async throws {
        struct Req: Encodable { let task: String; let inputId: String; let outputId: String; let transform: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "track_transform", inputId: inputId, outputId: outputId, transform: transform))
    }

    func impactAnalysis(datasetId: String) async throws -> [String] {
        struct Req: Encodable { let task: String; let datasetId: String }
        struct Raw: Decodable { let affected: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "lineage_impact_analysis", datasetId: datasetId))
        return r.affected ?? []
    }
}
