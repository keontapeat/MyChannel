//
//  DataLakeEngine.swift
//  MyChannel
//
//  Centralized data lake for structured + unstructured storage.
//  Ingest, catalog, query, and retire data with lineage tracking.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct DataLakeEntry: Codable, Identifiable {
    let id: String
    let path: String
    let schema: String
    let format: String
    let sizeBytes: Int64
    let recordCount: Int
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let retentionDays: Int
}

struct DataLakeQuery: Codable, Identifiable {
    let id: String
    let sql: String
    let status: QueryStatus
    let resultURL: String?
    let rowCount: Int?
    let executedAt: Date
    let durationMs: Double?
    enum QueryStatus: String, Codable { case queued, running, completed, failed }
}

@MainActor
final class DataLakeEngine: ObservableObject {
    static let shared = DataLakeEngine()
    private init() {}
    @Published private(set) var entries: [DataLakeEntry] = []
    @Published private(set) var recentQueries: [DataLakeQuery] = []

    func ingest(creatorId: String, path: String, schema: String, format: String, tags: [String]) async throws -> DataLakeEntry {
        struct Req: Encodable { let task: String; let creatorId: String; let path: String; let schema: String; let format: String; let tags: [String] }
        struct Raw: Decodable { let id: String; let size: Int64?; let records: Int?; let retention: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "datalake_ingest", creatorId: creatorId, path: path, schema: schema, format: format, tags: tags))
        let entry = DataLakeEntry(id: r.id, path: path, schema: schema, format: format,
            sizeBytes: r.size ?? 0, recordCount: r.records ?? 0, createdAt: Date(), updatedAt: Date(), tags: tags, retentionDays: r.retention ?? 365)
        entries.append(entry); return entry
    }

    func query(sql: String) async throws -> DataLakeQuery {
        struct Req: Encodable { let task: String; let sql: String }
        struct Raw: Decodable { let id: String; let status: String; let result_url: String?; let rows: Int?; let duration: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "datalake_query", sql: sql), timeout: 45)
        let q = DataLakeQuery(id: r.id, sql: sql, status: .init(rawValue: r.status) ?? .queued,
            resultURL: r.result_url, rowCount: r.rows, executedAt: Date(), durationMs: r.duration)
        recentQueries.insert(q, at: 0); return q
    }

    func catalog(creatorId: String) async throws {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawE: Decodable { let id: String; let path: String; let schema: String; let format: String; let size: Int64; let records: Int; let tags: [String]?; let retention: Int?; let updated: String? }
        struct Raw: Decodable { let entries: [RawE]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "datalake_catalog", creatorId: creatorId))
        entries = (r.entries ?? []).map {
            DataLakeEntry(id: $0.id, path: $0.path, schema: $0.schema, format: $0.format, sizeBytes: $0.size,
                recordCount: $0.records, createdAt: Date(),
                updatedAt: $0.updated.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                tags: $0.tags ?? [], retentionDays: $0.retention ?? 365)
        }
    }

    func retire(entryId: String) async throws {
        struct Req: Encodable { let task: String; let entryId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict", body: Req(task: "datalake_retire", entryId: entryId))
        entries.removeAll { $0.id == entryId }
    }
}
