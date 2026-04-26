//
//  SafetyOperationsCenterService.swift
//  MyChannel
//
//  Phase 118: Safety Operations Center.
//  Incident command console, abuse spike detection, SLA-driven response
//  runbooks. Uses `crisis-detection-ai` + `trust-safety-ai`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct SafetyIncident: Codable, Identifiable, Equatable {
    let id: String
    let type: IncidentType
    let severity: SafetyIncidentSeverity
    let title: String
    let description: String
    let affectedContentIds: [String]
    let status: IncidentStatus
    let assignedToUid: String?
    let runbookId: String?
    let slaDeadline: Date?
    let createdAt: Date
    let resolvedAt: Date?
}

enum IncidentType: String, Codable, CaseIterable {
    case abuseSpike, hateSpeech, csam, copyright, harassment, spam, fraud, platformAttack
}

enum SafetyIncidentSeverity: String, Codable { case p0, p1, p2, p3 }
enum IncidentStatus: String, Codable { case open, triaged, investigating, mitigated, resolved }

struct AbuseSpike: Codable {
    let type: IncidentType
    let magnitude: Double
    let startedAt: Date
    let affectedRegions: [String]
}

struct SafetyRunbook: Codable, Identifiable {
    let id: String
    let incidentType: IncidentType
    let steps: [String]
    let slaMinutes: Int
}

// MARK: - Service

@MainActor
final class SafetyOperationsCenterService: ObservableObject {
    static let shared = SafetyOperationsCenterService()
    private init() {}

    @Published private(set) var activeIncidents: [SafetyIncident] = []
    @Published private(set) var detectedSpikes: [AbuseSpike] = []
    @Published private(set) var runbooks: [SafetyRunbook] = []

    func loadActiveIncidents() async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("safety_incidents")
            .whereField("status", in: ["open", "triaged", "investigating", "mitigated"])
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        activeIncidents = snap.documents.compactMap { doc in
            try? doc.data(as: SafetyIncident.self)
        }
        #endif
    }

    func detectAbuseSpike() async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        struct Request: Encodable { let task: String }
        struct RawSpike: Decodable { let type: String; let magnitude: Double; let regions: [String]? }
        struct Raw: Decodable { let spikes: [RawSpike]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .crisisDetection,
            path: "/predict",
            body: Request(task: "detect_abuse_spike")
        )
        detectedSpikes = (r.spikes ?? []).map {
            AbuseSpike(type: IncidentType(rawValue: $0.type) ?? .abuseSpike, magnitude: $0.magnitude, startedAt: Date(), affectedRegions: $0.regions ?? [])
        }
    }

    func createIncident(type: IncidentType, severity: SafetyIncidentSeverity, title: String, description: String, contentIds: [String]) async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("safety_incidents").document()
            .setData([
                "type": type.rawValue,
                "severity": severity.rawValue,
                "title": title,
                "description": description,
                "affectedContentIds": contentIds,
                "status": IncidentStatus.open.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func assignRunbook(incidentId: String, runbookId: String) async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("safety_incidents").document(incidentId)
            .updateData(["runbookId": runbookId, "status": IncidentStatus.triaged.rawValue])
        #endif
    }

    func resolveIncident(incidentId: String) async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("safety_incidents").document(incidentId)
            .updateData([
                "status": IncidentStatus.resolved.rawValue,
                "resolvedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func loadRunbooks() async throws {
        guard AppConfig.Features.enableSafetyOpsCenter else { return }
        struct Request: Encodable { let task: String }
        struct RawBook: Decodable { let id: String; let type: String; let steps: [String]; let sla_min: Int }
        struct Raw: Decodable { let runbooks: [RawBook]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI,
            path: "/predict",
            body: Request(task: "list_runbooks")
        )
        runbooks = (r.runbooks ?? []).map {
            SafetyRunbook(id: $0.id, incidentType: IncidentType(rawValue: $0.type) ?? .abuseSpike, steps: $0.steps, slaMinutes: $0.sla_min)
        }
    }
}
