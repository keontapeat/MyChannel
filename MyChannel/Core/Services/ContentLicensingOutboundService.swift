//
//  ContentLicensingOutboundService.swift
//  MyChannel
//
//  Phase 130: Content Licensing Outbound.
//  Syndicate originals to external platforms, DRM packaging, revenue tracking.
//  Uses `legal-compliance-ai` + `copyright-claims-ai`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct LicensingDeal: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let creatorUid: String
    let licensee: String             // e.g. "Netflix", "Roku"
    let territories: [String]
    let exclusivity: Exclusivity
    let termMonths: Int
    let revenueSharePercent: Double
    let drmPackaged: Bool
    let status: DealStatus
    let createdAt: Date
}

enum Exclusivity: String, Codable { case exclusive, nonExclusive }
enum DealStatus: String, Codable { case draft, pending, active, expired, terminated }

struct DRMPackage: Codable, Identifiable {
    let id: String
    let videoId: String
    let format: DRMFormat
    let packageURL: URL?
    let expiresAt: Date?
}

enum DRMFormat: String, Codable { case fairplay, widevine, playready }

struct LicensingRevenue: Codable, Identifiable {
    let id: String
    let dealId: String
    let period: String
    let revenueUSD: Double
    let viewsOnPlatform: Int
}

// MARK: - Service

@MainActor
final class ContentLicensingOutboundService: ObservableObject {
    static let shared = ContentLicensingOutboundService()
    private init() {}

    @Published private(set) var deals: [LicensingDeal] = []
    @Published private(set) var revenueHistory: [LicensingRevenue] = []

    func loadDeals(creatorUid: String) async throws {
        guard AppConfig.Features.enableContentLicensingOutbound else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("licensing_deals").whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true).getDocuments()
        deals = snap.documents.compactMap { doc in
            try? doc.data(as: LicensingDeal.self)
        }
        #endif
    }

    func createDeal(videoId: String, creatorUid: String, licensee: String, territories: [String], exclusivity: Exclusivity, termMonths: Int, revenueShare: Double) async throws -> String {
        guard AppConfig.Features.enableContentLicensingOutbound else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("licensing_deals").document()
        try await ref.setData([
            "videoId": videoId, "creatorUid": creatorUid, "licensee": licensee,
            "territories": territories, "exclusivity": exclusivity.rawValue,
            "termMonths": termMonths, "revenueSharePercent": revenueShare,
            "drmPackaged": false, "status": DealStatus.draft.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func packageDRM(videoId: String, format: DRMFormat) async throws -> DRMPackage {
        guard AppConfig.Features.enableContentLicensingOutbound else {
            return DRMPackage(id: "", videoId: videoId, format: format, packageURL: nil, expiresAt: nil)
        }
        struct Request: Encodable { let task: String; let videoId: String; let format: String }
        struct Raw: Decodable { let package_id: String?; let url: String?; let expires: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .legalCompliance, path: "/predict",
            body: Request(task: "package_drm", videoId: videoId, format: format.rawValue), timeout: 60
        )
        return DRMPackage(
            id: r.package_id ?? UUID().uuidString, videoId: videoId, format: format,
            packageURL: r.url.flatMap(URL.init(string:)),
            expiresAt: r.expires.map { Date(timeIntervalSince1970: $0) }
        )
    }

    func loadRevenue(dealId: String) async throws {
        guard AppConfig.Features.enableContentLicensingOutbound else { return }
        struct Request: Encodable { let task: String; let dealId: String }
        struct RawRev: Decodable { let period: String; let revenue: Double; let views: Int }
        struct Raw: Decodable { let revenue: [RawRev]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorEarningsOptimizer, path: "/predict",
            body: Request(task: "licensing_revenue", dealId: dealId)
        )
        revenueHistory = (r.revenue ?? []).map {
            LicensingRevenue(id: UUID().uuidString, dealId: dealId, period: $0.period, revenueUSD: $0.revenue, viewsOnPlatform: $0.views)
        }
    }
}
