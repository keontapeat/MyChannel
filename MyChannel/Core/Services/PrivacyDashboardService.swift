//
//  PrivacyDashboardService.swift
//  MyChannel
//
//  Phase 187: Privacy Dashboard.
//  Data usage transparency, consent management, GDPR/CCPA tools.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct PrivacyConsent: Codable, Identifiable {
    let id: String
    let uid: String
    let category: String
    let granted: Bool
    let updatedAt: Date
}

struct DataUsageReport: Codable, Identifiable {
    let id: String
    let category: String
    let description: String
    let dataPoints: Int
    let retentionDays: Int
    let thirdPartyShared: Bool
}

struct PrivacyDataExportRequest: Codable, Identifiable {
    let id: String
    let uid: String
    let status: String
    let requestedAt: Date
    let completedAt: Date?
    let downloadURL: URL?
}

// MARK: - Service

@MainActor
final class PrivacyDashboardService: ObservableObject {
    static let shared = PrivacyDashboardService()
    private init() {}

    @Published private(set) var consents: [PrivacyConsent] = []
    @Published private(set) var dataUsage: [DataUsageReport] = []
    @Published private(set) var exportRequests: [PrivacyDataExportRequest] = []

    func loadConsents(uid: String) async throws {
        guard AppConfig.Features.enablePrivacyDashboard else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("privacy_consents").whereField("uid", isEqualTo: uid).getDocuments()
        consents = snap.documents.compactMap { doc in
            let d = doc.data()
            return PrivacyConsent(id: doc.documentID, uid: d["uid"] as? String ?? "",
                                 category: d["category"] as? String ?? "",
                                 granted: d["granted"] as? Bool ?? false,
                                 updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date())
        }
        #endif
    }

    func updateConsent(uid: String, category: String, granted: Bool) async throws {
        guard AppConfig.Features.enablePrivacyDashboard else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("privacy_consents").document("\(uid)_\(category)")
            .setData(["uid": uid, "category": category, "granted": granted,
                      "updatedAt": FieldValue.serverTimestamp()], merge: true)
        #endif
    }

    func requestDataExport(uid: String) async throws -> String {
        guard AppConfig.Features.enablePrivacyDashboard else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("data_export_requests").document()
        try await ref.setData(["uid": uid, "status": "pending", "requestedAt": FieldValue.serverTimestamp()])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func requestDataDeletion(uid: String) async throws {
        guard AppConfig.Features.enablePrivacyDashboard else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("data_deletion_requests").document()
            .setData(["uid": uid, "status": "pending", "requestedAt": FieldValue.serverTimestamp()])
        #endif
    }
}
