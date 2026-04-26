//
//  DataExportV2Service.swift
//  MyChannel
//
//  GDPR data export: user data packaging, download URLs,
//  retention policies. Uses `mychannel-auth` Cloud Run.
//

import Foundation

struct DataExportV2Job: Codable, Identifiable {
    let id: String
    let userId: String
    let status: ExportStatus
    let format: String
    let requestedAt: Date
    let completedAt: Date?
    let downloadURL: String?
    let expiresAt: Date?
    let sizeBytes: Int64?
    enum ExportStatus: String, Codable { case pending, processing, ready, expired, failed }
}

@MainActor
final class DataExportV2Service: ObservableObject {
    static let shared = DataExportV2Service()
    private init() {}
    @Published private(set) var exports: [DataExportV2Job] = []

    func requestExport(userId: String, format: String = "json") async throws -> DataExportV2Job {
        struct Req: Encodable { let task: String; let userId: String; let format: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "request_data_export", userId: userId, format: format), timeout: 30)
        let req = DataExportV2Job(id: r.id, userId: userId, status: .pending, format: format, requestedAt: Date(), completedAt: nil, downloadURL: nil, expiresAt: nil, sizeBytes: nil)
        exports.append(req); return req
    }

    func checkStatus(exportId: String) async throws -> DataExportV2Job? {
        struct Req: Encodable { let task: String; let exportId: String }
        struct Raw: Decodable { let status: String; let url: String?; let expires: String?; let size: Int64? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "check_export_status", exportId: exportId))
        if let idx = exports.firstIndex(where: { $0.id == exportId }) {
            let old = exports[idx]
            exports[idx] = DataExportV2Job(id: old.id, userId: old.userId, status: .init(rawValue: r.status) ?? old.status,
                format: old.format, requestedAt: old.requestedAt, completedAt: r.status == "ready" ? Date() : nil,
                downloadURL: r.url, expiresAt: r.expires.flatMap { ISO8601DateFormatter().date(from: $0) }, sizeBytes: r.size)
            return exports[idx]
        }
        return nil
    }

    func deleteExport(exportId: String) async throws {
        struct Req: Encodable { let task: String; let exportId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelAuth, path: "/predict",
            body: Req(task: "delete_export", exportId: exportId))
        exports.removeAll { $0.id == exportId }
    }
}
