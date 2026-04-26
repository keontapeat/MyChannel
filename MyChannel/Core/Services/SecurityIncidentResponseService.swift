//
//  SecurityIncidentResponseService.swift
//  MyChannel
//
//  Phase 275: Platform Security Incident Response
//  Manages security incidents, threat detection, response workflows
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class SecurityIncidentResponseService: ObservableObject {
    static let shared = SecurityIncidentResponseService()
    
    @Published private(set) var activeIncidents: [SecurityIncident] = []
    @Published private(set) var resolvedIncidents: [SecurityIncident] = []
    @Published private(set) var threatLevel: String = "low"
    @Published private(set) var blockedThreats: Int = 0
    
    struct SecurityIncident: Identifiable, Codable {
        let id: String
        let incidentType: String
        let severity: String
        let description: String
        let detectedAt: Date
        let status: String
        let affectedUsers: Int
        let resolvedAt: Date?
        let resolution: String?
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshIncidents() }
        }
        Task { await refreshIncidents() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshIncidents() async {
        guard AppConfig.Features.enableSecurityOpsV2 else { return }
        
        struct Req: Encodable { let task: String }
        struct RawInc: Decodable { let id: String; let incidentType: String; let severity: String; let description: String; let detectedAt: String; let status: String; let affectedUsers: Int; let resolvedAt: String?; let resolution: String? }
        struct Raw: Decodable { let activeIncidents: [RawInc]?; let resolvedIncidents: [RawInc]?; let threatLevel: String?; let blockedThreats: Int? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.aiSecurityFortress, path: "/predict",
                body: Req(task: "get_security_incidents"), timeout: 20)
            
            let decoder = ISO8601DateFormatter()
            
            activeIncidents = (r.activeIncidents ?? []).map {
                SecurityIncident(
                    id: $0.id,
                    incidentType: $0.incidentType,
                    severity: $0.severity,
                    description: $0.description,
                    detectedAt: decoder.date(from: $0.detectedAt) ?? Date(),
                    status: $0.status,
                    affectedUsers: $0.affectedUsers,
                    resolvedAt: $0.resolvedAt != nil ? decoder.date(from: $0.resolvedAt!) : nil,
                    resolution: $0.resolution
                )
            }.sorted { $0.severity == "critical" && $1.severity != "critical" }
            
            resolvedIncidents = (r.resolvedIncidents ?? []).map {
                SecurityIncident(
                    id: $0.id,
                    incidentType: $0.incidentType,
                    severity: $0.severity,
                    description: $0.description,
                    detectedAt: decoder.date(from: $0.detectedAt) ?? Date(),
                    status: $0.status,
                    affectedUsers: $0.affectedUsers,
                    resolvedAt: $0.resolvedAt != nil ? decoder.date(from: $0.resolvedAt!) : nil,
                    resolution: $0.resolution
                )
            }
            
            threatLevel = r.threatLevel ?? "low"
            blockedThreats = r.blockedThreats ?? 0
            
        } catch {
            print("⚠️ [SecurityIncidentResponse] Error: \(error)")
        }
    }
    
    func resolveIncident(incidentId: String, resolution: String) async throws {
        struct Req: Encodable { let task: String; let incidentId: String; let resolution: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.aiSecurityFortress, path: "/predict",
            body: Req(task: "resolve_incident", incidentId: incidentId, resolution: resolution), timeout: 20)
        guard r.success == true else { throw NSError(domain: "SecurityIncident", code: -1, userInfo: nil) }
        await refreshIncidents()
    }
}
