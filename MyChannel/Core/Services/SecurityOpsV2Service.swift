//
//  SecurityOpsV2Service.swift
//  MyChannel
//
//  Phase 190: Security Operations Center v2.
//  Threat intel, incident response, automated remediation.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct SecurityIncident: Codable, Identifiable {
    let id: String
    let type: String
    let severity: SecurityIncidentSeverity
    let description: String
    let affectedUsers: Int
    let status: String
    let detectedAt: Date
    let resolvedAt: Date?
    let autoRemediated: Bool
}

enum SecurityIncidentSeverity: String, Codable { case low, medium, high, critical }

struct ThreatIntel: Codable, Identifiable {
    let id: String
    let source: String
    let threatType: String
    let indicators: [String]
    let confidence: Double
    let reportedAt: Date
}

// MARK: - Service

@MainActor
final class SecurityOpsV2Service: ObservableObject {
    static let shared = SecurityOpsV2Service()
    private init() {}

    @Published private(set) var incidents: [SecurityIncident] = []
    @Published private(set) var threats: [ThreatIntel] = []

    func loadIncidents() async throws {
        guard AppConfig.Features.enableSecurityOpsV2 else { return }
        struct Request: Encodable { let task: String }
        struct RawInc: Decodable { let type: String; let severity: String; let desc: String; let users: Int; let status: String; let auto: Bool }
        struct Raw: Decodable { let incidents: [RawInc]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "security_incidents")
        )
        incidents = (r.incidents ?? []).map {
            SecurityIncident(id: UUID().uuidString, type: $0.type,
                           severity: SecurityIncidentSeverity(rawValue: $0.severity) ?? .medium,
                           description: $0.desc, affectedUsers: $0.users, status: $0.status,
                           detectedAt: Date(), resolvedAt: nil, autoRemediated: $0.auto)
        }
    }

    func loadThreats() async throws {
        guard AppConfig.Features.enableSecurityOpsV2 else { return }
        struct Request: Encodable { let task: String }
        struct RawThreat: Decodable { let source: String; let type: String; let indicators: [String]; let confidence: Double }
        struct Raw: Decodable { let threats: [RawThreat]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "threat_intel")
        )
        threats = (r.threats ?? []).map {
            ThreatIntel(id: UUID().uuidString, source: $0.source, threatType: $0.type,
                       indicators: $0.indicators, confidence: $0.confidence, reportedAt: Date())
        }
    }

    func remediate(incidentId: String) async throws {
        guard AppConfig.Features.enableSecurityOpsV2 else { return }
        if let idx = incidents.firstIndex(where: { $0.id == incidentId }) {
            let old = incidents[idx]
            incidents[idx] = SecurityIncident(id: old.id, type: old.type, severity: old.severity,
                                            description: old.description, affectedUsers: old.affectedUsers,
                                            status: "resolved", detectedAt: old.detectedAt,
                                            resolvedAt: Date(), autoRemediated: true)
        }
    }
}
