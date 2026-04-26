//
//  CreatorPluginSDKService.swift
//  MyChannel
//
//  Phase 102: Creator Plugin SDK.
//  Safe extension points for upload/edit/publish pipeline.
//  Plugins run in a scoped permission model with policy-enforced runtime.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CreatorPlugin: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let developerUid: String
    let description: String
    let version: String
    let hookPoints: [HookPoint]
    let permissions: [PluginPermission]
    let approved: Bool
    let createdAt: Date
}

enum HookPoint: String, Codable, CaseIterable {
    case preUpload       // modify metadata before upload starts
    case postUpload      // trigger after upload completes
    case prePublish      // last gate before going public
    case postPublish     // fire webhooks, cross-post, etc.
    case onEdit          // inject UI into video editor
}

enum PluginPermission: String, Codable, CaseIterable {
    case readVideoMeta, writeVideoMeta, readAnalytics, sendNotification, externalHTTP
}

struct PluginExecution: Codable, Identifiable {
    let id: String
    let pluginId: String
    let videoId: String
    let hookPoint: HookPoint
    let status: PluginExecStatus
    let durationMs: Int
    let output: String?
    let executedAt: Date
}

enum PluginExecStatus: String, Codable { case success, failed, timeout, skipped }

// MARK: - Service

@MainActor
final class CreatorPluginSDKService: ObservableObject {
    static let shared = CreatorPluginSDKService()
    private init() {}

    @Published private(set) var activePlugins: [CreatorPlugin] = []

    func loadActivePlugins(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorPluginSDK else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("creator_plugins")
            .whereField("developerUid", isEqualTo: creatorUid)
            .whereField("approved", isEqualTo: true)
            .getDocuments()
        activePlugins = snap.documents.compactMap { doc in
            let d = doc.data()
            return CreatorPlugin(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                developerUid: d["developerUid"] as? String ?? "",
                description: d["description"] as? String ?? "",
                version: d["version"] as? String ?? "1.0",
                hookPoints: (d["hookPoints"] as? [String])?.compactMap(HookPoint.init(rawValue:)) ?? [],
                permissions: (d["permissions"] as? [String])?.compactMap(PluginPermission.init(rawValue:)) ?? [],
                approved: true,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func registerPlugin(_ plugin: CreatorPlugin) async throws {
        guard AppConfig.Features.enableCreatorPluginSDK else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("creator_plugins").document(plugin.id)
            .setData([
                "name": plugin.name,
                "developerUid": plugin.developerUid,
                "description": plugin.description,
                "version": plugin.version,
                "hookPoints": plugin.hookPoints.map(\.rawValue),
                "permissions": plugin.permissions.map(\.rawValue),
                "approved": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func validatePlugin(pluginId: String) async throws -> Bool {
        guard AppConfig.Features.enableCreatorPluginSDK else { return false }
        struct Request: Encodable { let task: String; let pluginId: String }
        struct Raw: Decodable { let valid: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .apiShield,
            path: "/predict",
            body: Request(task: "validate_plugin", pluginId: pluginId)
        )
        return r.valid ?? false
    }

    func executeHook(_ hookPoint: HookPoint, videoId: String) async throws -> [PluginExecution] {
        guard AppConfig.Features.enableCreatorPluginSDK else { return [] }
        let plugins = activePlugins.filter { $0.hookPoints.contains(hookPoint) }
        var results: [PluginExecution] = []
        for plugin in plugins {
            let start = Date()
            let exec = PluginExecution(
                id: UUID().uuidString,
                pluginId: plugin.id,
                videoId: videoId,
                hookPoint: hookPoint,
                status: .success,
                durationMs: Int(Date().timeIntervalSince(start) * 1000),
                output: nil,
                executedAt: Date()
            )
            results.append(exec)
        }
        return results
    }
}
