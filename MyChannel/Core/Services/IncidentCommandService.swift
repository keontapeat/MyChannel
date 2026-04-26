//
//  IncidentCommandService.swift
//  MyChannel
//
//  Phase 881: Real-Time Incident Command
//  Live incident tracking, severity classification, escalation routing,
//  war room coordination, runbook auto-launch, post-mortem generation
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class IncidentCommandService: ObservableObject {
    static let shared = IncidentCommandService()

    // MARK: - Domain Models

    struct Incident: Identifiable, Codable {
        let id: String
        let title: String
        let severity: IncidentSeverity
        let status: IncidentStatus
        let affectedServices: [String]
        let assignee: String?
        let createdAt: Date
        let updatedAt: Date
        let resolvedAt: Date?
        let timeline: [IncidentEvent]
        let runbookId: String?
        let warRoomId: String?
        let impactScore: Double
        let mttrMinutes: Int?
    }

    enum IncidentSeverity: String, Codable, CaseIterable {
        case critical = "CRITICAL"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
    }

    enum IncidentStatus: String, Codable {
        case detecting = "DETECTING"
        case triaging = "TRIAGING"
        case investigating = "INVESTIGATING"
        case mitigating = "MITIGATING"
        case resolving = "RESOLVING"
        case resolved = "RESOLVED"
        case postMortem = "POST_MORTEM"
    }

    struct IncidentEvent: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let eventType: String
        let description: String
        let author: String
    }

    struct EscalationPolicy: Identifiable, Codable {
        let id: String
        let severity: IncidentSeverity
        let notifyRoles: [String]
        let autoRunbook: String?
        let slaMinutes: Int
        let escalationChain: [String]
    }

    // MARK: - Published State

    @Published private(set) var activeIncidents: [Incident] = []
    @Published private(set) var recentIncidents: [Incident] = []
    @Published private(set) var escalationPolicies: [EscalationPolicy] = []
    @Published private(set) var isWarRoomActive = false
    @Published private(set) var activeWarRoomId: String?
    @Published private(set) var mttrAverage: Double = 0
    @Published private(set) var incidentCountToday: Int = 0
    @Published private(set) var criticalCount: Int = 0

    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task { await loadPolicies() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://incident-command-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableIncidentCommand else { return nil }
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

    // MARK: - Load & Listen

    func loadPolicies() async {
        let snap = try? await db.collection("escalationPolicies").getDocuments()
        escalationPolicies = snap?.documents.compactMap { doc in
            guard let severity = IncidentSeverity(rawValue: doc["severity"] as? String ?? ""),
                  let notifyRoles = doc["notifyRoles"] as? [String],
                  let sla = doc["slaMinutes"] as? Int else { return nil }
            return EscalationPolicy(
                id: doc.documentID,
                severity: severity,
                notifyRoles: notifyRoles,
                autoRunbook: doc["autoRunbook"] as? String,
                slaMinutes: sla,
                escalationChain: doc["escalationChain"] as? [String] ?? []
            )
        } ?? []
    }

    func startListening() {
        let listener = db.collection("incidents")
            .whereField("status", isNotEqualTo: "RESOLVED")
            .order(by: "updatedAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let incidents = snap?.documents.compactMap { self.parseIncident($0) } ?? []
                Task { @MainActor in
                    self.activeIncidents = incidents
                    self.criticalCount = incidents.filter { $0.severity == .critical }.count
                    self.incidentCountToday = incidents.filter { Calendar.current.isDateInToday($0.createdAt) }.count
                }
            }
        listeners.append(listener)
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Actions

    func createIncident(title: String, severity: IncidentSeverity, affectedServices: [String]) async {
        let id = UUID().uuidString
        let now = Date()
        let incident = Incident(
            id: id, title: title, severity: severity, status: .detecting,
            affectedServices: affectedServices, assignee: nil,
            createdAt: now, updatedAt: now, resolvedAt: nil,
            timeline: [IncidentEvent(id: UUID().uuidString, timestamp: now, eventType: "CREATED", description: "Incident detected", author: "system")],
            runbookId: nil, warRoomId: nil, impactScore: severityImpact(severity), mttrMinutes: nil
        )

        let data: [String: Any] = [
            "title": title, "severity": severity.rawValue, "status": "DETECTING",
            "affectedServices": affectedServices, "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now), "impactScore": severityImpact(severity)
        ]
        try? await db.collection("incidents").document(id).setData(data)

        // Auto-escalate based on policy
        if let policy = escalationPolicies.first(where: { $0.severity == severity }) {
            await applyEscalationPolicy(incidentId: id, policy: policy)
        }

        _ = await callCloudRun(endpoint: "create", body: data)
    }

    func updateIncidentStatus(_ incidentId: String, status: IncidentStatus) async {
        let update: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": status == .resolved ? Timestamp(date: Date()) : NSNull()
        ]
        try? await db.collection("incidents").document(incidentId).updateData(update)
        _ = await callCloudRun(endpoint: "update", body: ["incidentId": incidentId, "status": status.rawValue])
    }

    func addTimelineEvent(incidentId: String, eventType: String, description: String, author: String) async {
        let event = IncidentEvent(id: UUID().uuidString, timestamp: Date(), eventType: eventType, description: description, author: author)
        try? await db.collection("incidents").document(incidentId).updateData([
            "timeline": FieldValue.arrayUnion([[
                "id": event.id, "timestamp": Timestamp(date: event.timestamp),
                "eventType": eventType, "description": description, "author": author
            ]]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func openWarRoom(incidentId: String) async {
        let warRoomId = "war-\(UUID().uuidString.prefix(8))"
        try? await db.collection("incidents").document(incidentId).updateData([
            "warRoomId": warRoomId, "updatedAt": Timestamp(date: Date())
        ])
        isWarRoomActive = true
        activeWarRoomId = warRoomId
    }

    func generatePostMortem(incidentId: String) async -> String? {
        let result = await callCloudRun(endpoint: "postmortem", body: ["incidentId": incidentId])
        return result?["postMortem"] as? String
    }

    // MARK: - Helpers

    private func applyEscalationPolicy(incidentId: String, policy: EscalationPolicy) async {
        for role in policy.notifyRoles {
            try? await db.collection("notifications").addDocument(data: [
                "type": "incident_escalation", "incidentId": incidentId,
                "role": role, "createdAt": Timestamp(date: Date())
            ])
        }
        if let runbook = policy.autoRunbook {
            try? await db.collection("incidents").document(incidentId).updateData(["runbookId": runbook])
        }
    }

    private func severityImpact(_ severity: IncidentSeverity) -> Double {
        switch severity {
        case .critical: return 95.0
        case .high: return 75.0
        case .medium: return 45.0
        case .low: return 15.0
        }
    }

    private func parseIncident(_ doc: DocumentSnapshot) -> Incident? {
        let data = doc.data() ?? [:]
        guard let title = data["title"] as? String,
              let severity = IncidentSeverity(rawValue: data["severity"] as? String ?? ""),
              let status = IncidentStatus(rawValue: data["status"] as? String ?? "") else { return nil }
        let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let resolved = (data["resolvedAt"] as? Timestamp)?.dateValue()
        let events = (data["timeline"] as? [[String: Any]])?.compactMap { ev -> IncidentEvent? in
            IncidentEvent(
                id: ev["id"] as? String ?? UUID().uuidString,
                timestamp: (ev["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                eventType: ev["eventType"] as? String ?? "",
                description: ev["description"] as? String ?? "",
                author: ev["author"] as? String ?? "system"
            )
        } ?? []
        return Incident(
            id: doc.documentID, title: title, severity: severity, status: status,
            affectedServices: data["affectedServices"] as? [String] ?? [],
            assignee: data["assignee"] as? String,
            createdAt: created, updatedAt: updated, resolvedAt: resolved,
            timeline: events, runbookId: data["runbookId"] as? String,
            warRoomId: data["warRoomId"] as? String,
            impactScore: data["impactScore"] as? Double ?? 0,
            mttrMinutes: data["mttrMinutes"] as? Int
        )
    }
}
