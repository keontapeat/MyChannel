//
//  WhiteLabelDistributionService.swift
//  MyChannel
//
//  Phase 110: White-Label Distribution.
//  Embeddable branded portals, SSO federation, enterprise analytics exports.
//  Uses `global-expansion-ai` and `cdn-optimizer` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct WhiteLabelPortal: Codable, Identifiable, Equatable {
    let id: String
    let enterpriseUid: String
    let portalName: String
    let customDomain: String?
    let brandColor: String        // hex e.g. "#FF5500"
    let logoURL: URL?
    let ssoProvider: SSOProvider?
    let active: Bool
    let createdAt: Date
}

enum SSOProvider: String, Codable, CaseIterable {
    case saml, oidc, google, microsoft, okta
}

struct AnalyticsExport: Codable, Identifiable {
    let id: String
    let portalId: String
    let format: AnalyticsExportFormat
    let downloadURL: URL?
    let generatedAt: Date
}

enum AnalyticsExportFormat: String, Codable { case csv, json, parquet }

// MARK: - Service

@MainActor
final class WhiteLabelDistributionService: ObservableObject {
    static let shared = WhiteLabelDistributionService()
    private init() {}

    @Published private(set) var portals: [WhiteLabelPortal] = []
    @Published private(set) var exports: [AnalyticsExport] = []

    func loadPortals(enterpriseUid: String) async throws {
        guard AppConfig.Features.enableWhiteLabelDistribution else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("white_label_portals")
            .whereField("enterpriseUid", isEqualTo: enterpriseUid)
            .getDocuments()
        portals = snap.documents.compactMap { doc in
            let d = doc.data()
            return WhiteLabelPortal(
                id: doc.documentID,
                enterpriseUid: d["enterpriseUid"] as? String ?? "",
                portalName: d["portalName"] as? String ?? "",
                customDomain: d["customDomain"] as? String,
                brandColor: d["brandColor"] as? String ?? "#000000",
                logoURL: (d["logoURL"] as? String).flatMap(URL.init(string:)),
                ssoProvider: (d["ssoProvider"] as? String).flatMap(SSOProvider.init(rawValue:)),
                active: d["active"] as? Bool ?? true,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func provisionPortal(enterpriseUid: String, name: String, brandColor: String, domain: String?) async throws -> String {
        guard AppConfig.Features.enableWhiteLabelDistribution else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("white_label_portals").document()
        try await ref.setData([
            "enterpriseUid": enterpriseUid,
            "portalName": name,
            "brandColor": brandColor,
            "customDomain": domain as Any,
            "active": true,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func configureSSO(portalId: String, provider: SSOProvider) async throws {
        guard AppConfig.Features.enableWhiteLabelDistribution else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("white_label_portals").document(portalId)
            .updateData(["ssoProvider": provider.rawValue])
        #endif
    }

    func exportAnalytics(portalId: String, format: AnalyticsExportFormat) async throws -> URL? {
        guard AppConfig.Features.enableWhiteLabelDistribution else { return nil }
        struct Request: Encodable { let task: String; let portalId: String; let format: String }
        struct Raw: Decodable { let download_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .globalExpansion,
            path: "/predict",
            body: Request(task: "export_analytics", portalId: portalId, format: format.rawValue)
        )
        return r.download_url.flatMap(URL.init(string:))
    }
}
