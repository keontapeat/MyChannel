//
//  ElasticsearchService.swift
//  MyChannel
//
//  Elasticsearch integration for full-text search, aggregations,
//  and index management. Uses `mychannel-content` Cloud Run.
//

import Foundation

struct ESIndex: Codable, Identifiable {
    let id: String
    let name: String
    let documentCount: Int
    let sizeBytes: Int64
    let health: String
    let status: String
}

struct ESSearchResult: Codable {
    let totalHits: Int
    let documents: [ESDocument]
    let aggregations: [String: AggregationBucket]
    struct ESDocument: Codable, Identifiable { let id: String; let score: Double; let source: [String: String] }
    struct AggregationBucket: Codable { let buckets: [BucketEntry] }
    struct BucketEntry: Codable { let key: String; let count: Int }
}

@MainActor
final class ElasticsearchService: ObservableObject {
    static let shared = ElasticsearchService()
    private init() {}
    @Published private(set) var indices: [ESIndex] = []
    @Published private(set) var lastResult: ESSearchResult?

    func listIndices() async throws {
        struct Req: Encodable { let task: String }
        struct RawI: Decodable { let id: String; let name: String; let docs: Int; let size: Int64; let health: String; let status: String }
        struct Raw: Decodable { let indices: [RawI]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict", body: Req(task: "es_list_indices"))
        indices = (r.indices ?? []).map { ESIndex(id: $0.id, name: $0.name, documentCount: $0.docs, sizeBytes: $0.size, health: $0.health, status: $0.status) }
    }

    func search(index: String, query: String, from: Int = 0, size: Int = 20) async throws -> ESSearchResult {
        struct Req: Encodable { let task: String; let index: String; let query: String; let from: Int; let size: Int }
        struct RawDoc: Decodable { let id: String; let score: Double; let source: [String: String]? }
        struct Raw: Decodable { let total: Int?; let documents: [RawDoc]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "es_search", index: index, query: query, from: from, size: size), timeout: 15)
        let result = ESSearchResult(totalHits: r.total ?? 0,
            documents: (r.documents ?? []).map { ESSearchResult.ESDocument(id: $0.id, score: $0.score, source: $0.source ?? [:]) },
            aggregations: [:])
        lastResult = result; return result
    }

    func indexDocument(index: String, docId: String, body: [String: String]) async throws {
        struct Req: Encodable { let task: String; let index: String; let docId: String; let body: [String: String] }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "es_index_document", index: index, docId: docId, body: body))
    }

    func deleteIndex(indexName: String) async throws {
        struct Req: Encodable { let task: String; let index: String }
        struct Raw: Decodable { let acknowledged: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "es_delete_index", index: indexName))
        indices.removeAll { $0.name == indexName }
    }
}
