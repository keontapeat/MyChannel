//
//  ContentGraphService.swift
//  MyChannel
//
//  Phase 176: Content Graph Engine.
//  Video-to-video relationships, topic clusters, knowledge graph.
//  Uses `recommendations` Cloud Run.
//

import Foundation

// MARK: - Models

struct ContentNode: Codable, Identifiable, Equatable {
    let id: String          // videoId
    let title: String
    let cluster: String
    let topics: [String]
    let weight: Double
}

struct ContentEdge: Codable, Identifiable {
    let id: String
    let sourceVideoId: String
    let targetVideoId: String
    let relationship: EdgeRelationship
    let strength: Double
}

enum EdgeRelationship: String, Codable {
    case similar, sequel, response, reference, remix, compilation
}

struct TopicCluster: Codable, Identifiable {
    let id: String
    let name: String
    let videoCount: Int
    let avgEngagement: Double
    let trending: Bool
}

// MARK: - Service

@MainActor
final class ContentGraphService: ObservableObject {
    static let shared = ContentGraphService()
    private init() {}

    @Published private(set) var nodes: [ContentNode] = []
    @Published private(set) var edges: [ContentEdge] = []
    @Published private(set) var clusters: [TopicCluster] = []

    func buildGraph(videoId: String) async throws {
        guard AppConfig.Features.enableContentGraph else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawNode: Decodable { let id: String; let title: String; let cluster: String; let topics: [String]; let weight: Double }
        struct RawEdge: Decodable { let source: String; let target: String; let rel: String; let strength: Double }
        struct Raw: Decodable { let nodes: [RawNode]?; let edges: [RawEdge]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "content_graph", videoId: videoId), timeout: 30
        )
        nodes = (r.nodes ?? []).map { ContentNode(id: $0.id, title: $0.title, cluster: $0.cluster, topics: $0.topics, weight: $0.weight) }
        edges = (r.edges ?? []).map {
            ContentEdge(id: UUID().uuidString, sourceVideoId: $0.source, targetVideoId: $0.target,
                       relationship: EdgeRelationship(rawValue: $0.rel) ?? .similar, strength: $0.strength)
        }
    }

    func loadClusters() async throws {
        guard AppConfig.Features.enableContentGraph else { return }
        struct Request: Encodable { let task: String }
        struct RawCluster: Decodable { let name: String; let count: Int; let engagement: Double; let trending: Bool }
        struct Raw: Decodable { let clusters: [RawCluster]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "topic_clusters")
        )
        clusters = (r.clusters ?? []).map {
            TopicCluster(id: UUID().uuidString, name: $0.name, videoCount: $0.count,
                        avgEngagement: $0.engagement, trending: $0.trending)
        }
    }

    func relatedVideos(for videoId: String) -> [String] {
        edges.filter { $0.sourceVideoId == videoId }.sorted { $0.strength > $1.strength }.map(\.targetVideoId)
    }
}
