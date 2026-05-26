//
//  IPOReadinessService.swift
//  MyChannel
//
//  Phase 100: IPO-Ready Operations.
//  SOC 2 Type II evidence collection, investor KPI portal,
//  and SOX-grade financial audit trail. Ops-only; no consumer UI.
//

import Foundation

// MARK: - KPI snapshot (investor-facing)

struct IPOKPISnapshot: Codable {
    // Growth
    let mau: Int
    let dau: Int
    let d1Retention: Double         // 0..1
    let d7Retention: Double
    let d30Retention: Double

    // Monetization
    let arpu: Double                // avg revenue per user, USD
    let arppu: Double               // avg revenue per paying user, USD
    let paidConversionRate: Double
    let mrr: Decimal                // monthly recurring revenue, USD
    let ltv: Decimal                // blended LTV, USD

    // Creator flywheel
    let activeCreators: Int
    let videosPublishedLast30d: Int
    let avgWatchTimeMinutes: Double
    let totalWatchHours: Double

    // Infra
    let crashFreeSessionRate: Double
    let p95ApiLatencyMs: Double
    let uptimePercent: Double       // 30-day rolling

    // Safety
    let contentActionsLast30d: Int
    let appealOverturnRate: Double
    let trustedFlaggerResponseHours: Double

    let snapshotAt: Date
}

struct ComplianceEvidence: Codable, Identifiable {
    let id: String
    let framework: Framework
    let control: String
    let evidenceURL: URL
    let collectedAt: Date
    let expiresAt: Date?
    let status: Status

    enum Framework: String, Codable { case soc2, iso27001, gdpr, coppa, sox }
    enum Status: String, Codable { case collected, verified, expired }
}

@MainActor
final class IPOReadinessService: ObservableObject {
    static let shared = IPOReadinessService()
    private init() {}

    private let investorPortalBase = "https://investors.mychannel.live/v1"

    // MARK: - KPI snapshot

    func kpiSnapshot() async throws -> IPOKPISnapshot {
        guard AppConfig.Features.enableIPOReadiness else { throw IPOError.disabled }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable {
            let mau: Int?; let dau: Int?
            let d1: Double?; let d7: Double?; let d30: Double?
            let arpu: Double?; let arppu: Double?; let paid_cvr: Double?
            let mrr: Double?; let ltv: Double?
            let active_creators: Int?
            let videos_30d: Int?; let avg_watch_minutes: Double?; let total_watch_hours: Double?
            let crash_free: Double?; let p95_api_ms: Double?; let uptime: Double?
            let content_actions: Int?; let appeal_rate: Double?; let trusted_flagger_hours: Double?
            let snapshot_at: Double?
        }
        let r: Raw = try await callPortal("/kpis/snapshot", body: Request(task: "snapshot"))
        return IPOKPISnapshot(
            mau: r.mau ?? 0,
            dau: r.dau ?? 0,
            d1Retention: r.d1 ?? 0, d7Retention: r.d7 ?? 0, d30Retention: r.d30 ?? 0,
            arpu: r.arpu ?? 0, arppu: r.arppu ?? 0, paidConversionRate: r.paid_cvr ?? 0,
            mrr: Decimal(r.mrr ?? 0), ltv: Decimal(r.ltv ?? 0),
            activeCreators: r.active_creators ?? 0,
            videosPublishedLast30d: r.videos_30d ?? 0,
            avgWatchTimeMinutes: r.avg_watch_minutes ?? 0, totalWatchHours: r.total_watch_hours ?? 0,
            crashFreeSessionRate: r.crash_free ?? 0, p95ApiLatencyMs: r.p95_api_ms ?? 0, uptimePercent: r.uptime ?? 0,
            contentActionsLast30d: r.content_actions ?? 0, appealOverturnRate: r.appeal_rate ?? 0,
            trustedFlaggerResponseHours: r.trusted_flagger_hours ?? 0,
            snapshotAt: r.snapshot_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
        )
    }

    // MARK: - Compliance evidence

    func listEvidence(framework: ComplianceEvidence.Framework) async throws -> [ComplianceEvidence] {
        guard AppConfig.Features.enableIPOReadiness else { return [] }
        struct Request: Encodable { let framework: String }
        struct RawEv: Decodable {
            let id: String
            let control: String
            let evidence_url: String
            let collected_at: Double
            let expires_at: Double?
            let status: String
        }
        struct Raw: Decodable { let evidence: [RawEv]? }
        let r: Raw = try await callPortal("/compliance/evidence", body: Request(framework: framework.rawValue))
        return (r.evidence ?? []).compactMap { e in
            guard
                let url = URL(string: e.evidence_url),
                let status = ComplianceEvidence.Status(rawValue: e.status)
            else { return nil }
            return ComplianceEvidence(
                id: e.id, framework: framework, control: e.control,
                evidenceURL: url,
                collectedAt: Date(timeIntervalSince1970: e.collected_at),
                expiresAt: e.expires_at.map { Date(timeIntervalSince1970: $0) },
                status: status
            )
        }
    }

    // MARK: - Audit log

    /// Request a signed export of the immutable audit log for a date window. Returns a pre-signed GCS URL.
    func auditLogExport(from: Date, to: Date) async throws -> URL {
        guard AppConfig.Features.enableIPOReadiness else { throw IPOError.disabled }
        struct Request: Encodable { let from: Double; let to: Double }
        struct Raw: Decodable { let url: String? }
        let r: Raw = try await callPortal("/audit-log/export",
                                          body: Request(from: from.timeIntervalSince1970,
                                                        to: to.timeIntervalSince1970))
        guard let urlStr = r.url, let url = URL(string: urlStr) else { throw IPOError.noExport }
        return url
    }

    // MARK: - Transport

    private func callPortal<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: investorPortalBase + path) else { throw IPOError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        #if canImport(FirebaseAuth)
        if let token = try? await FirebaseAuth.Auth.auth().currentUser?.getIDToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        #endif
        let (data, resp) = try await URLSession.configured.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IPOError.http((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    enum IPOError: LocalizedError {
        case disabled, badURL, noExport, http(Int)
        var errorDescription: String? {
            switch self {
            case .disabled: return "IPO readiness features are disabled."
            case .badURL: return "Invalid portal URL."
            case .noExport: return "Audit log export unavailable."
            case .http(let c): return "Portal HTTP \(c)."
            }
        }
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
