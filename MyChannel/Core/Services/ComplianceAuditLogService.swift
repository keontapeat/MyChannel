//
//  ComplianceAuditLogService.swift
//  MyChannel
//
//  Compliance & Audit Log - Action logging, compliance reports, data export
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class ComplianceAuditLogService: ObservableObject {
    static let shared = ComplianceAuditLogService()
    
    @Published private(set) var auditLogs: [AuditLogEntry] = []
    @Published private(set) var complianceReports: [ComplianceReport] = []
    
    struct AuditLogEntry: Identifiable, Codable {
        let id: String
        let userId: String
        let userEmail: String?
        let action: String
        let resource: String
        let details: String
        let ipAddress: String?
        let userAgent: String?
        let timestamp: Date
        let severity: String
    }
    
    struct ComplianceReport: Identifiable, Codable {
        let id: String
        let reportType: String
        let period: String
        let generatedAt: Date
        let findings: [ComplianceFinding]
        let overallStatus: String
    }
    
    struct ComplianceFinding: Codable {
        let category: String
        let description: String
        let severity: String
        let resolved: Bool
    }
    
    private init() {
        Task { await loadAuditLogs() }
        Task { await loadComplianceReports() }
    }
    
    func loadAuditLogs() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("auditLogs")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        auditLogs = snapshot?.documents.compactMap { doc -> AuditLogEntry? in
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let action = data["action"] as? String,
                  let resource = data["resource"] as? String,
                  let details = data["details"] as? String,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else { return nil }
            
            return AuditLogEntry(
                id: doc.documentID,
                userId: userId,
                userEmail: data["userEmail"] as? String,
                action: action,
                resource: resource,
                details: details,
                ipAddress: data["ipAddress"] as? String,
                userAgent: data["userAgent"] as? String,
                timestamp: timestamp,
                severity: data["severity"] as? String ?? "info"
            )
        } ?? []
        #endif
    }
    
    func loadComplianceReports() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("complianceReports")
            .order(by: "generatedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        complianceReports = snapshot?.documents.compactMap { doc -> ComplianceReport? in
            let data = doc.data()
            guard let reportType = data["reportType"] as? String,
                  let period = data["period"] as? String,
                  let generatedAt = (data["generatedAt"] as? Timestamp)?.dateValue(),
                  let findingsData = data["findings"] as? [[String: Any]] else { return nil }
            
            let findings = findingsData.compactMap { f -> ComplianceFinding? in
                guard let category = f["category"] as? String,
                      let description = f["description"] as? String,
                      let severity = f["severity"] as? String else { return nil }
                return ComplianceFinding(
                    category: category,
                    description: description,
                    severity: severity,
                    resolved: f["resolved"] as? Bool ?? false
                )
            }
            
            return ComplianceReport(
                id: doc.documentID,
                reportType: reportType,
                period: period,
                generatedAt: generatedAt,
                findings: findings,
                overallStatus: data["overallStatus"] as? String ?? "pending"
            )
        } ?? []
        #endif
    }
    
    func logAction(userId: String, userEmail: String?, action: String, resource: String, details: String, ipAddress: String?, userAgent: String?, severity: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("auditLogs").document()
        
        try? await docRef.setData([
            "userId": userId,
            "userEmail": userEmail ?? "",
            "action": action,
            "resource": resource,
            "details": details,
            "ipAddress": ipAddress ?? "",
            "userAgent": userAgent ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "severity": severity
        ])
        await loadAuditLogs()
        #endif
    }
    
    func generateComplianceReport(reportType: String, period: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("complianceReports").document()
        
        try await docRef.setData([
            "reportType": reportType,
            "period": period,
            "generatedAt": FieldValue.serverTimestamp(),
            "findings": [],
            "overallStatus": "in_progress"
        ])
        await loadComplianceReports()
        #endif
    }
    
    func exportAuditLogs(startDate: Date, endDate: Date) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("auditLogs")
            .whereField("timestamp", isGreaterThanOrEqualTo: startDate)
            .whereField("timestamp", isLessThanOrEqualTo: endDate)
            .getDocuments()
        
        let logs = snapshot.documents.compactMap { doc -> [String: Any]? in
            doc.data()
        }
        
        let data = try JSONSerialization.data(withJSONObject: logs, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? ""
        #else
        return ""
        #endif
    }
}
