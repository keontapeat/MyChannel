//
//  ComplianceGovernanceService.swift
//  MyChannel
//
//  Phase 895: Compliance & Governance Dashboard
//  Policy violations, appeal outcomes, transparency reports, regulatory compliance
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ComplianceGovernanceService: ObservableObject {
    static let shared = ComplianceGovernanceService()

    // MARK: - Domain Models

    struct PolicyViolation: Identifiable, Codable {
        let id: String
        let policy: String
        let violationType: String
        let contentId: String
        let contentType: String
        let severity: String
        let detectedAt: Date
        let status: String
        let action: String
    }

    struct AppealOutcome: Identifiable, Codable {
        let id: String
        let appealType: String
        let originalDecision: String
        let appealDecision: String
        let overturned: Bool
        let processingTimeHours: Double
        let timestamp: Date
    }

    struct TransparencyReportData: Identifiable, Codable {
        let id: String
        let period: String
        let contentRemoved: Int
        let contentAgeGated: Int
        let accountsSuspended: Int
        let governmentRequests: Int
        let copyrightClaims: Int
        let appealRate: Double
        let overturnRate: Double
    }

    struct RegulatoryCompliance: Identifiable, Codable {
        let id: String
        let regulation: String
        let complianceScore: Double
        let gaps: [String]
        let nextAuditDate: Date?
        let status: String
    }

    struct AuditReadiness: Codable {
        let overallScore: Double
        let soc2Readiness: Double
        let gdprReadiness: Double
        let coppaReadiness: Double
        let dsaReadiness: Double
        let ccpaReadiness: Double
    }

    // MARK: - Published State

    @Published private(set) var policyViolations: [PolicyViolation] = []
    @Published private(set) var appealOutcomes: [AppealOutcome] = []
    @Published private(set) var transparencyData: [TransparencyReportData] = []
    @Published private(set) var regulatoryCompliance: [RegulatoryCompliance] = []
    @Published private(set) var auditReadiness: AuditReadiness?
    @Published private(set) var governanceHealth: Double = 100
    @Published private(set) var dataSubjectRequests: Int = 0
    @Published private(set) var complianceScorecard: [String: Double] = [:]

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://compliance-command-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableComplianceGovernance else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableComplianceGovernance else { return }

        // Load policy violations
        let violationSnap = try? await db.collection("policyViolations")
            .order(by: "detectedAt", descending: true)
            .limit(to: 30)
            .getDocuments()
        policyViolations = violationSnap?.documents.compactMap { doc in
            let d = doc.data()
            return PolicyViolation(
                id: doc.documentID,
                policy: d["policy"] as? String ?? "",
                violationType: d["violationType"] as? String ?? "",
                contentId: d["contentId"] as? String ?? "",
                contentType: d["contentType"] as? String ?? "",
                severity: d["severity"] as? String ?? "LOW",
                detectedAt: (d["detectedAt"] as? Timestamp)?.dateValue() ?? Date(),
                status: d["status"] as? String ?? "pending",
                action: d["action"] as? String ?? ""
            )
        } ?? []

        // Load appeal outcomes
        let appealSnap = try? await db.collection("appealOutcomes")
            .order(by: "timestamp", descending: true)
            .limit(to: 30)
            .getDocuments()
        appealOutcomes = appealSnap?.documents.compactMap { doc in
            let d = doc.data()
            return AppealOutcome(
                id: doc.documentID,
                appealType: d["appealType"] as? String ?? "",
                originalDecision: d["originalDecision"] as? String ?? "",
                appealDecision: d["appealDecision"] as? String ?? "",
                overturned: d["overturned"] as? Bool ?? false,
                processingTimeHours: d["processingTimeHours"] as? Double ?? 0,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        } ?? []

        // Cloud Run for deeper analytics
        if let result = await callCloudRun(endpoint: "dashboard") {
            if let transp = result["transparencyData"] as? [[String: Any]] {
                transparencyData = transp.compactMap { d in
                    TransparencyReportData(
                        id: UUID().uuidString,
                        period: d["period"] as? String ?? "",
                        contentRemoved: d["contentRemoved"] as? Int ?? 0,
                        contentAgeGated: d["contentAgeGated"] as? Int ?? 0,
                        accountsSuspended: d["accountsSuspended"] as? Int ?? 0,
                        governmentRequests: d["governmentRequests"] as? Int ?? 0,
                        copyrightClaims: d["copyrightClaims"] as? Int ?? 0,
                        appealRate: d["appealRate"] as? Double ?? 0,
                        overturnRate: d["overturnRate"] as? Double ?? 0
                    )
                }
            }
            if let reg = result["regulatoryCompliance"] as? [[String: Any]] {
                regulatoryCompliance = reg.compactMap { d in
                    RegulatoryCompliance(
                        id: UUID().uuidString,
                        regulation: d["regulation"] as? String ?? "",
                        complianceScore: d["complianceScore"] as? Double ?? 0,
                        gaps: d["gaps"] as? [String] ?? [],
                        nextAuditDate: (d["nextAuditDate"] as? Timestamp)?.dateValue(),
                        status: d["status"] as? String ?? "unknown"
                    )
                }
            }
            governanceHealth = result["governanceHealth"] as? Double ?? 100
            dataSubjectRequests = result["dataSubjectRequests"] as? Int ?? 0
            complianceScorecard = result["complianceScorecard"] as? [String: Double] ?? [:]

            auditReadiness = AuditReadiness(
                overallScore: result["auditReadinessOverall"] as? Double ?? 0,
                soc2Readiness: result["soc2Readiness"] as? Double ?? 0,
                gdprReadiness: result["gdprReadiness"] as? Double ?? 0,
                coppaReadiness: result["coppaReadiness"] as? Double ?? 0,
                dsaReadiness: result["dsaReadiness"] as? Double ?? 0,
                ccpaReadiness: result["ccpaReadiness"] as? Double ?? 0
            )
        }
    }
}
