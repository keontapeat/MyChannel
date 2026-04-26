//
//  IncidentResponsePlaybookService.swift
//  MyChannel
//
//  Incident Response Playbooks - Automated runbooks for common incidents
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class IncidentResponsePlaybookService: ObservableObject {
    static let shared = IncidentResponsePlaybookService()
    
    @Published private(set) var playbooks: [IncidentPlaybook] = []
    @Published private(set) var activePlaybookRuns: [PlaybookRun] = []
    
    struct IncidentPlaybook: Identifiable, Codable {
        let id: String
        let name: String
        let incidentType: String
        let severity: String
        let steps: [PlaybookStep]
        let estimatedDuration: Int
        let lastRun: Date?
        let successRate: Double
    }
    
    struct PlaybookStep: Codable {
        let id: String
        let order: Int
        let title: String
        let description: String
        let type: String
        let automationScript: String?
        let expectedDuration: Int
    }
    
    struct PlaybookRun: Identifiable, Codable {
        let id: String
        let playbookId: String
        let playbookName: String
        let startedAt: Date
        let completedAt: Date?
        let currentStep: Int
        let status: String
        let triggeredBy: String
    }
    
    private init() {
        Task { await loadPlaybooks() }
        Task { await loadActiveRuns() }
    }
    
    func loadPlaybooks() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("incidentPlaybooks").getDocuments()
        
        let decoder = ISO8601DateFormatter()
        playbooks = snapshot?.documents.compactMap { doc -> IncidentPlaybook? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let incidentType = data["incidentType"] as? String,
                  let severity = data["severity"] as? String,
                  let stepsData = data["steps"] as? [[String: Any]],
                  let estimatedDuration = data["estimatedDuration"] as? Int else { return nil }
            
            let steps = stepsData.compactMap { s -> PlaybookStep? in
                guard let id = s["id"] as? String,
                      let order = s["order"] as? Int,
                      let title = s["title"] as? String,
                      let description = s["description"] as? String,
                      let type = s["type"] as? String,
                      let expectedDuration = s["expectedDuration"] as? Int else { return nil }
                return PlaybookStep(
                    id: id,
                    order: order,
                    title: title,
                    description: description,
                    type: type,
                    automationScript: s["automationScript"] as? String,
                    expectedDuration: expectedDuration
                )
            }.sorted { $0.order < $1.order }
            
            return IncidentPlaybook(
                id: doc.documentID,
                name: name,
                incidentType: incidentType,
                severity: severity,
                steps: steps,
                estimatedDuration: estimatedDuration,
                lastRun: (data["lastRun"] as? Timestamp)?.dateValue(),
                successRate: data["successRate"] as? Double ?? 1.0
            )
        } ?? []
        #endif
    }
    
    func loadActiveRuns() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("playbookRuns")
            .whereField("status", in: ["in_progress", "paused"])
            .order(by: "startedAt", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        activePlaybookRuns = snapshot?.documents.compactMap { doc -> PlaybookRun? in
            let data = doc.data()
            guard let playbookId = data["playbookId"] as? String,
                  let playbookName = data["playbookName"] as? String,
                  let startedAt = (data["startedAt"] as? Timestamp)?.dateValue(),
                  let currentStep = data["currentStep"] as? Int,
                  let status = data["status"] as? String,
                  let triggeredBy = data["triggeredBy"] as? String else { return nil }
            
            return PlaybookRun(
                id: doc.documentID,
                playbookId: playbookId,
                playbookName: playbookName,
                startedAt: startedAt,
                completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
                currentStep: currentStep,
                status: status,
                triggeredBy: triggeredBy
            )
        } ?? []
        #endif
    }
    
    func runPlaybook(playbookId: String, triggeredBy: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let playbook = playbooks.first { $0.id == playbookId }
        guard let playbook = playbook else { throw NSError(domain: "Playbook", code: -1, userInfo: nil) }
        
        let runRef = db.collection("playbookRuns").document()
        try await runRef.setData([
            "playbookId": playbookId,
            "playbookName": playbook.name,
            "startedAt": FieldValue.serverTimestamp(),
            "currentStep": 0,
            "status": "in_progress",
            "triggeredBy": triggeredBy
        ])
        
        await loadActiveRuns()
        return runRef.documentID
        #else
        throw NSError(domain: "Playbook", code: -1, userInfo: nil)
        #endif
    }
    
    func advancePlaybookRun(runId: String, stepIndex: Int) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("playbookRuns").document(runId).updateData([
            "currentStep": stepIndex
        ])
        await loadActiveRuns()
        #endif
    }
    
    func completePlaybookRun(runId: String, success: Bool) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("playbookRuns").document(runId).updateData([
            "status": success ? "completed" : "failed",
            "completedAt": FieldValue.serverTimestamp()
        ])
        await loadActiveRuns()
        #endif
    }
}
