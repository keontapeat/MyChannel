//
//  DataResidencyService.swift
//  MyChannel
//
//  Phase 117: Data Residency & Sovereign Modes.
//  Per-region storage controls (EU/UK/US/APAC), compliance routing.
//  Uses `database-optimizer` + `regional-content-ai` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct ResidencyPolicy: Codable, Identifiable, Equatable {
    let id: String
    let region: DataRegion
    let storageLocation: String        // GCS multi-region e.g. "eu"
    let firestoreLocation: String      // e.g. "eur3"
    let requiresDataLocality: Bool
    let gdprApplicable: Bool
    let retentionDays: Int
}

enum DataRegion: String, Codable, CaseIterable {
    case us, eu, uk, apac, mena, latam
}

struct DataLocationAudit: Codable, Identifiable {
    let id: String
    let userId: String
    let dataType: String
    let currentRegion: DataRegion
    let compliant: Bool
    let auditedAt: Date
}

struct RoutingDecision: Codable {
    let targetRegion: DataRegion
    let storageEndpoint: String
    let firestoreProject: String
    let reason: String
}

// MARK: - Service

@MainActor
final class DataResidencyService: ObservableObject {
    static let shared = DataResidencyService()
    private init() {}

    @Published private(set) var policies: [ResidencyPolicy] = []
    @Published private(set) var auditResults: [DataLocationAudit] = []

    func loadPolicies() async throws {
        guard AppConfig.Features.enableDataResidency else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("data_residency_policies")
            .getDocuments()
        policies = snap.documents.compactMap { doc in
            let d = doc.data()
            return ResidencyPolicy(
                id: doc.documentID,
                region: DataRegion(rawValue: d["region"] as? String ?? "") ?? .us,
                storageLocation: d["storageLocation"] as? String ?? "us",
                firestoreLocation: d["firestoreLocation"] as? String ?? "nam5",
                requiresDataLocality: d["requiresDataLocality"] as? Bool ?? false,
                gdprApplicable: d["gdprApplicable"] as? Bool ?? false,
                retentionDays: d["retentionDays"] as? Int ?? 365
            )
        }
        #endif
    }

    func routeData(userCountryCode: String) async throws -> RoutingDecision {
        guard AppConfig.Features.enableDataResidency else {
            return RoutingDecision(targetRegion: .us, storageEndpoint: "gs://mychannel-ca26d.appspot.com", firestoreProject: "mychannel-ca26d", reason: "default")
        }
        struct Request: Encodable { let task: String; let country: String }
        struct Raw: Decodable { let region: String?; let storage: String?; let firestore: String?; let reason: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .regionalContent,
            path: "/predict",
            body: Request(task: "route_data", country: userCountryCode)
        )
        return RoutingDecision(
            targetRegion: DataRegion(rawValue: r.region ?? "us") ?? .us,
            storageEndpoint: r.storage ?? "",
            firestoreProject: r.firestore ?? "mychannel-ca26d",
            reason: r.reason ?? ""
        )
    }

    func applyResidencyPolicy(region: DataRegion, storageLocation: String, firestoreLocation: String, gdpr: Bool) async throws {
        guard AppConfig.Features.enableDataResidency else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("data_residency_policies").document(region.rawValue)
            .setData([
                "region": region.rawValue,
                "storageLocation": storageLocation,
                "firestoreLocation": firestoreLocation,
                "requiresDataLocality": true,
                "gdprApplicable": gdpr,
                "retentionDays": gdpr ? 730 : 365
            ], merge: true)
        #endif
    }

    func auditDataLocation(userId: String) async throws {
        guard AppConfig.Features.enableDataResidency else { return }
        struct Request: Encodable { let task: String; let userId: String }
        struct RawAudit: Decodable { let data_type: String; let region: String; let compliant: Bool }
        struct Raw: Decodable { let audits: [RawAudit]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .databaseOptimizer,
            path: "/predict",
            body: Request(task: "audit_location", userId: userId)
        )
        auditResults = (r.audits ?? []).map {
            DataLocationAudit(id: UUID().uuidString, userId: userId, dataType: $0.data_type, currentRegion: DataRegion(rawValue: $0.region) ?? .us, compliant: $0.compliant, auditedAt: Date())
        }
    }
}
