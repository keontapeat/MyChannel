//
//  PartnerIntegrationsService.swift
//  MyChannel
//
//  Phase 104: Partner Integrations Hub.
//  Shopify/Discord/Twitch connectors, OAuth unification,
//  one-click channel sync.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct PartnerConnection: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let platform: PartnerPlatform
    let externalAccountId: String
    let displayName: String
    let connected: Bool
    let syncEnabled: Bool
    let lastSyncedAt: Date?
    let connectedAt: Date
}

enum PartnerPlatform: String, Codable, CaseIterable {
    case shopify, discord, twitch, instagram, tiktok, twitter, patreon
}

struct SyncResult: Codable {
    let connectionId: String
    let itemsSynced: Int
    let errors: [String]
    let syncedAt: Date
}

// MARK: - Service

@MainActor
final class PartnerIntegrationsService: ObservableObject {
    static let shared = PartnerIntegrationsService()
    private init() {}

    @Published private(set) var connections: [PartnerConnection] = []

    func loadConnections(creatorUid: String) async throws {
        guard AppConfig.Features.enablePartnerIntegrations else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("partner_connections")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .getDocuments()
        connections = snap.documents.compactMap { doc in
            let d = doc.data()
            return PartnerConnection(
                id: doc.documentID,
                creatorUid: d["creatorUid"] as? String ?? "",
                platform: PartnerPlatform(rawValue: d["platform"] as? String ?? "") ?? .discord,
                externalAccountId: d["externalAccountId"] as? String ?? "",
                displayName: d["displayName"] as? String ?? "",
                connected: d["connected"] as? Bool ?? false,
                syncEnabled: d["syncEnabled"] as? Bool ?? false,
                lastSyncedAt: (d["lastSyncedAt"] as? Timestamp)?.dateValue(),
                connectedAt: (d["connectedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func connect(platform: PartnerPlatform, creatorUid: String, externalAccountId: String, displayName: String) async throws {
        guard AppConfig.Features.enablePartnerIntegrations else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("partner_connections").document()
        try await ref.setData([
            "creatorUid": creatorUid,
            "platform": platform.rawValue,
            "externalAccountId": externalAccountId,
            "displayName": displayName,
            "connected": true,
            "syncEnabled": true,
            "connectedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func disconnect(connectionId: String) async throws {
        guard AppConfig.Features.enablePartnerIntegrations else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("partner_connections").document(connectionId)
            .updateData(["connected": false, "syncEnabled": false])
        #endif
    }

    func syncChannel(connectionId: String) async throws -> SyncResult {
        guard AppConfig.Features.enablePartnerIntegrations else {
            return SyncResult(connectionId: connectionId, itemsSynced: 0, errors: [], syncedAt: Date())
        }
        struct Request: Encodable { let task: String; let connectionId: String }
        struct Raw: Decodable { let items_synced: Int?; let errors: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .affiliateOptimizer,
            path: "/predict",
            body: Request(task: "sync_channel", connectionId: connectionId)
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("partner_connections").document(connectionId)
            .updateData(["lastSyncedAt": FieldValue.serverTimestamp()])
        #endif
        return SyncResult(
            connectionId: connectionId,
            itemsSynced: r.items_synced ?? 0,
            errors: r.errors ?? [],
            syncedAt: Date()
        )
    }
}
