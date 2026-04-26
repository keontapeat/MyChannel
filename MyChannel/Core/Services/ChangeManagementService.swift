//
//  ChangeManagementService.swift
//  MyChannel
//
//  Change Management System - Track deployments, rollbacks, impact analysis
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class ChangeManagementService: ObservableObject {
    static let shared = ChangeManagementService()
    
    @Published private(set) var deployments: [Deployment] = []
    @Published private(set) var pendingChanges: [ChangeRequest] = []
    @Published private(set) var changeHistory: [ChangeHistory] = []
    
    struct Deployment: Identifiable, Codable {
        let id: String
        let version: String
        let environment: String
        let deployedAt: Date
        let deployedBy: String
        let status: String
        let rollbackVersion: String?
        let impact: DeploymentImpact
    }
    
    struct DeploymentImpact: Codable {
        let usersAffected: Int
        let downtimeMinutes: Int
        let issuesDetected: Int
        let performanceImpact: String
    }
    
    struct ChangeRequest: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let type: String
        let priority: String
        let requestedBy: String
        let requestedAt: Date
        let approvedBy: String?
        let approvedAt: Date?
        let status: String
        let scheduledFor: Date?
    }
    
    struct ChangeHistory: Identifiable, Codable {
        let id: String
        let changeId: String
        let title: String
        let action: String
        let performedBy: String
        let performedAt: Date
        let details: String
    }
    
    private init() {
        Task { await loadDeployments() }
        Task { await loadPendingChanges() }
        Task { await loadChangeHistory() }
    }
    
    func loadDeployments() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("deployments")
            .order(by: "deployedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        deployments = snapshot?.documents.compactMap { doc -> Deployment? in
            let data = doc.data()
            guard let version = data["version"] as? String,
                  let environment = data["environment"] as? String,
                  let deployedAt = (data["deployedAt"] as? Timestamp)?.dateValue(),
                  let deployedBy = data["deployedBy"] as? String,
                  let status = data["status"] as? String,
                  let impactData = data["impact"] as? [String: Any] else { return nil }
            
            let impact = DeploymentImpact(
                usersAffected: impactData["usersAffected"] as? Int ?? 0,
                downtimeMinutes: impactData["downtimeMinutes"] as? Int ?? 0,
                issuesDetected: impactData["issuesDetected"] as? Int ?? 0,
                performanceImpact: impactData["performanceImpact"] as? String ?? "none"
            )
            
            return Deployment(
                id: doc.documentID,
                version: version,
                environment: environment,
                deployedAt: deployedAt,
                deployedBy: deployedBy,
                status: status,
                rollbackVersion: data["rollbackVersion"] as? String,
                impact: impact
            )
        } ?? []
        #endif
    }
    
    func loadPendingChanges() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("changeRequests")
            .whereField("status", isEqualTo: "pending")
            .order(by: "requestedAt", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        pendingChanges = snapshot?.documents.compactMap { doc -> ChangeRequest? in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let description = data["description"] as? String,
                  let type = data["type"] as? String,
                  let priority = data["priority"] as? String,
                  let requestedBy = data["requestedBy"] as? String,
                  let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue(),
                  let status = data["status"] as? String else { return nil }
            
            return ChangeRequest(
                id: doc.documentID,
                title: title,
                description: description,
                type: type,
                priority: priority,
                requestedBy: requestedBy,
                requestedAt: requestedAt,
                approvedBy: data["approvedBy"] as? String,
                approvedAt: (data["approvedAt"] as? Timestamp)?.dateValue(),
                status: status,
                scheduledFor: (data["scheduledFor"] as? Timestamp)?.dateValue()
            )
        } ?? []
        #endif
    }
    
    func loadChangeHistory() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("changeHistory")
            .order(by: "performedAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        changeHistory = snapshot?.documents.compactMap { doc -> ChangeHistory? in
            let data = doc.data()
            guard let changeId = data["changeId"] as? String,
                  let title = data["title"] as? String,
                  let action = data["action"] as? String,
                  let performedBy = data["performedBy"] as? String,
                  let performedAt = (data["performedAt"] as? Timestamp)?.dateValue(),
                  let details = data["details"] as? String else { return nil }
            
            return ChangeHistory(
                id: doc.documentID,
                changeId: changeId,
                title: title,
                action: action,
                performedBy: performedBy,
                performedAt: performedAt,
                details: details
            )
        } ?? []
        #endif
    }
    
    func createChangeRequest(title: String, description: String, type: String, priority: String, requestedBy: String, scheduledFor: Date?) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("changeRequests").document()
        
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "type": type,
            "priority": priority,
            "requestedBy": requestedBy,
            "requestedAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        if let scheduled = scheduledFor {
            data["scheduledFor"] = scheduled
        }
        
        try await docRef.setData(data)
        await loadPendingChanges()
        return docRef.documentID
        #else
        throw NSError(domain: "ChangeManagement", code: -1, userInfo: nil)
        #endif
    }
    
    func approveChange(changeId: String, approvedBy: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("changeRequests").document(changeId).updateData([
            "approvedBy": approvedBy,
            "approvedAt": FieldValue.serverTimestamp(),
            "status": "approved"
        ])
        await loadPendingChanges()
        #endif
    }
    
    func recordDeployment(version: String, environment: String, deployedBy: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("deployments").document()
        
        try await docRef.setData([
            "version": version,
            "environment": environment,
            "deployedAt": FieldValue.serverTimestamp(),
            "deployedBy": deployedBy,
            "status": "deploying",
            "impact": [
                "usersAffected": 0,
                "downtimeMinutes": 0,
                "issuesDetected": 0,
                "performanceImpact": "none"
            ]
        ])
        await loadDeployments()
        return docRef.documentID
        #else
        throw NSError(domain: "ChangeManagement", code: -1, userInfo: nil)
        #endif
    }
    
    func rollbackDeployment(deploymentId: String, rollbackVersion: String, performedBy: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("deployments").document(deploymentId).updateData([
            "rollbackVersion": rollbackVersion,
            "status": "rolled_back"
        ])
        
        try await db.collection("changeHistory").addDocument(data: [
            "changeId": deploymentId,
            "title": "Rollback to \(rollbackVersion)",
            "action": "rollback",
            "performedBy": performedBy,
            "performedAt": FieldValue.serverTimestamp(),
            "details": "Deployment rolled back to version \(rollbackVersion)"
        ])
        
        await loadDeployments()
        await loadChangeHistory()
        #endif
    }
}
