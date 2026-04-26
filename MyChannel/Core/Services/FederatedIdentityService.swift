//
//  FederatedIdentityService.swift
//  MyChannel
//
//  Phase 137: Federated Identity & Portability.
//  W3C DID credentials, data export/import, cross-platform profile portability.
//  Uses `mychannel-auth` Cloud Run for identity operations.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct DecentralizedIdentity: Codable, Identifiable, Equatable {
    let id: String
    let uid: String
    let didURI: String          // e.g. "did:web:mychannel.live:u:abc123"
    let publicKeyJWK: String
    let verificationMethod: String
    let createdAt: Date
}

struct DataExportJob: Codable, Identifiable {
    let id: String
    let uid: String
    let format: ExportDataFormat
    let status: DataJobStatus
    let downloadURL: URL?
    let fileSizeMB: Double?
    let requestedAt: Date
    let completedAt: Date?
}

enum ExportDataFormat: String, Codable { case json, csv, activityPub }
enum DataJobStatus: String, Codable { case queued, processing, ready, expired, failed }

struct DataImportJob: Codable, Identifiable {
    let id: String
    let uid: String
    let sourcePlatform: String
    let status: DataJobStatus
    let itemsImported: Int
    let requestedAt: Date
}

struct PortabilityProfile: Codable {
    let displayName: String
    let bio: String
    let avatarURL: URL?
    let subscriberCount: Int
    let videoCount: Int
    let platforms: [String]
}

// MARK: - Service

@MainActor
final class FederatedIdentityService: ObservableObject {
    static let shared = FederatedIdentityService()
    private init() {}

    @Published private(set) var identity: DecentralizedIdentity?
    @Published private(set) var exportJob: DataExportJob?
    @Published private(set) var importJob: DataImportJob?

    func createDID(uid: String) async throws {
        guard AppConfig.Features.enableFederatedIdentity else { return }
        struct Request: Encodable { let task: String; let uid: String }
        struct Raw: Decodable { let did_uri: String?; let public_key: String?; let verification: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Request(task: "create_did", uid: uid)
        )
        identity = DecentralizedIdentity(
            id: UUID().uuidString, uid: uid,
            didURI: r.did_uri ?? "did:web:mychannel.live:u:\(uid)",
            publicKeyJWK: r.public_key ?? "",
            verificationMethod: r.verification ?? "Ed25519VerificationKey2020",
            createdAt: Date()
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("decentralized_ids").document(uid).setData([
            "didURI": identity?.didURI ?? "", "publicKeyJWK": identity?.publicKeyJWK ?? "",
            "verificationMethod": identity?.verificationMethod ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func requestDataExport(uid: String, format: ExportDataFormat) async throws -> String {
        guard AppConfig.Features.enableFederatedIdentity else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("data_exports").document()
        try await ref.setData([
            "uid": uid, "format": format.rawValue, "status": DataJobStatus.queued.rawValue,
            "requestedAt": FieldValue.serverTimestamp()
        ])
        exportJob = DataExportJob(
            id: ref.documentID, uid: uid, format: format, status: .queued,
            downloadURL: nil, fileSizeMB: nil, requestedAt: Date(), completedAt: nil
        )
        return ref.documentID
        #else
        return ""
        #endif
    }

    func importFromPlatform(uid: String, platform: String, importFileURL: URL) async throws -> String {
        guard AppConfig.Features.enableFederatedIdentity else { return "" }
        struct Request: Encodable { let task: String; let uid: String; let platform: String; let fileURL: String }
        struct Raw: Decodable { let job_id: String?; let items: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Request(task: "import_data", uid: uid, platform: platform, fileURL: importFileURL.absoluteString),
            timeout: 120
        )
        let jobId = r.job_id ?? UUID().uuidString
        importJob = DataImportJob(
            id: jobId, uid: uid, sourcePlatform: platform,
            status: .processing, itemsImported: r.items ?? 0, requestedAt: Date()
        )
        return jobId
    }

    func resolveProfile(didURI: String) async throws -> PortabilityProfile? {
        guard AppConfig.Features.enableFederatedIdentity else { return nil }
        struct Request: Encodable { let task: String; let didURI: String }
        struct Raw: Decodable { let name: String?; let bio: String?; let avatar: String?; let subs: Int?; let videos: Int?; let platforms: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Request(task: "resolve_did", didURI: didURI)
        )
        return PortabilityProfile(
            displayName: r.name ?? "", bio: r.bio ?? "",
            avatarURL: r.avatar.flatMap(URL.init(string:)),
            subscriberCount: r.subs ?? 0, videoCount: r.videos ?? 0,
            platforms: r.platforms ?? []
        )
    }
}
