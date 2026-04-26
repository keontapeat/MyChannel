//
//  PluginEcosystemV2Service.swift
//  MyChannel
//
//  Phase 196: Plugin Ecosystem v2.
//  Third-party plugin store, sandboxed execution, revenue sharing.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct Plugin: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let developerName: String
    let description: String
    let version: String
    let iconURL: URL?
    let category: String
    let installs: Int
    let rating: Double
    let revenueSharePercent: Double
}

struct InstalledPlugin: Codable, Identifiable {
    let id: String
    let pluginId: String
    let uid: String
    let installedAt: Date
    let isEnabled: Bool
    let permissions: [String]
}

// MARK: - Service

@MainActor
final class PluginEcosystemV2Service: ObservableObject {
    static let shared = PluginEcosystemV2Service()
    private init() {}

    @Published private(set) var storePlugins: [Plugin] = []
    @Published private(set) var installed: [InstalledPlugin] = []

    func loadStore(category: String? = nil) async throws {
        guard AppConfig.Features.enablePluginEcosystemV2 else { return }
        #if canImport(FirebaseFirestore)
        var query: Query = Firestore.firestore().collection("plugins")
        if let cat = category { query = query.whereField("category", isEqualTo: cat) }
        let snap = try await query.order(by: "installs", descending: true).limit(to: 50).getDocuments()
        storePlugins = snap.documents.compactMap { doc in
            let d = doc.data()
            return Plugin(id: doc.documentID, name: d["name"] as? String ?? "",
                         developerName: d["developerName"] as? String ?? "",
                         description: d["description"] as? String ?? "",
                         version: d["version"] as? String ?? "1.0",
                         iconURL: (d["iconURL"] as? String).flatMap(URL.init(string:)),
                         category: d["category"] as? String ?? "",
                         installs: d["installs"] as? Int ?? 0, rating: d["rating"] as? Double ?? 0,
                         revenueSharePercent: d["revenueSharePercent"] as? Double ?? 70)
        }
        #endif
    }

    func install(pluginId: String, uid: String) async throws {
        guard AppConfig.Features.enablePluginEcosystemV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("installed_plugins").document("\(uid)_\(pluginId)")
            .setData(["pluginId": pluginId, "uid": uid, "installedAt": FieldValue.serverTimestamp(),
                      "isEnabled": true, "permissions": []])
        try await Firestore.firestore().collection("plugins").document(pluginId)
            .updateData(["installs": FieldValue.increment(Int64(1))])
        #endif
    }

    func uninstall(pluginId: String, uid: String) async throws {
        guard AppConfig.Features.enablePluginEcosystemV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("installed_plugins").document("\(uid)_\(pluginId)").delete()
        #endif
        installed.removeAll { $0.pluginId == pluginId }
    }
}
