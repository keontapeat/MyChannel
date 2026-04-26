//
//  CustomReportBuilderService.swift
//  MyChannel
//
//  Custom Report Builder - Drag-drop reports, scheduled exports
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class CustomReportBuilderService: ObservableObject {
    static let shared = CustomReportBuilderService()
    
    @Published private(set) var savedReports: [CustomReport] = []
    @Published private(set) var scheduledExports: [ScheduledExport] = []
    
    struct CustomReport: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let metrics: [ReportMetric]
        let filters: [ReportFilter]
        let visualization: String
        let createdBy: String
        let createdAt: Date
        let lastModified: Date
    }
    
    struct ReportMetric: Codable {
        let id: String
        let name: String
        let source: String
        let aggregation: String
    }
    
    struct ReportFilter: Codable {
        let field: String
        let `operator`: String
        let value: String
    }
    
    struct ScheduledExport: Identifiable, Codable {
        let id: String
        let reportId: String
        let reportName: String
        let schedule: String
        let format: String
        let recipients: [String]
        let nextRun: Date
        let isActive: Bool
    }
    
    private init() {
        Task { await loadSavedReports() }
        Task { await loadScheduledExports() }
    }
    
    func loadSavedReports() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("customReports")
            .order(by: "lastModified", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        savedReports = snapshot?.documents.compactMap { doc -> CustomReport? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let description = data["description"] as? String,
                  let metricsData = data["metrics"] as? [[String: Any]],
                  let filtersData = data["filters"] as? [[String: Any]],
                  let visualization = data["visualization"] as? String,
                  let createdBy = data["createdBy"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                  let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() else { return nil }
            
            let metrics = metricsData.compactMap { m -> ReportMetric? in
                guard let id = m["id"] as? String,
                      let name = m["name"] as? String,
                      let source = m["source"] as? String,
                      let aggregation = m["aggregation"] as? String else { return nil }
                return ReportMetric(id: id, name: name, source: source, aggregation: aggregation)
            }
            
            let filters = filtersData.compactMap { f -> ReportFilter? in
                guard let field = f["field"] as? String,
                      let op = f["operator"] as? String,
                      let value = f["value"] as? String else { return nil }
                return ReportFilter(field: field, `operator`: op, value: value)
            }
            
            return CustomReport(
                id: doc.documentID,
                name: name,
                description: description,
                metrics: metrics,
                filters: filters,
                visualization: visualization,
                createdBy: createdBy,
                createdAt: createdAt,
                lastModified: lastModified
            )
        } ?? []
        #endif
    }
    
    func loadScheduledExports() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("scheduledExports")
            .whereField("isActive", isEqualTo: true)
            .order(by: "nextRun", descending: false)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        scheduledExports = snapshot?.documents.compactMap { doc -> ScheduledExport? in
            let data = doc.data()
            guard let reportId = data["reportId"] as? String,
                  let reportName = data["reportName"] as? String,
                  let schedule = data["schedule"] as? String,
                  let format = data["format"] as? String,
                  let recipients = data["recipients"] as? [String],
                  let nextRun = (data["nextRun"] as? Timestamp)?.dateValue() else { return nil }
            
            return ScheduledExport(
                id: doc.documentID,
                reportId: reportId,
                reportName: reportName,
                schedule: schedule,
                format: format,
                recipients: recipients,
                nextRun: nextRun,
                isActive: data["isActive"] as? Bool ?? true
            )
        } ?? []
        #endif
    }
    
    func saveReport(name: String, description: String, metrics: [ReportMetric], filters: [ReportFilter], visualization: String, createdBy: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("customReports").document()
        
        let metricsDict = metrics.map { [
            "id": $0.id,
            "name": $0.name,
            "source": $0.source,
            "aggregation": $0.aggregation
        ]}
        
        let filtersDict = filters.map { [
            "field": $0.field,
            "operator": $0.`operator`,
            "value": $0.value
        ]}
        
        try await docRef.setData([
            "name": name,
            "description": description,
            "metrics": metricsDict,
            "filters": filtersDict,
            "visualization": visualization,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "lastModified": FieldValue.serverTimestamp()
        ])
        await loadSavedReports()
        return docRef.documentID
        #else
        throw NSError(domain: "CustomReportBuilder", code: -1, userInfo: nil)
        #endif
    }
    
    func scheduleExport(reportId: String, reportName: String, schedule: String, format: String, recipients: [String]) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("scheduledExports").document()
        
        let nextRun = calculateNextRun(schedule: schedule)
        
        try await docRef.setData([
            "reportId": reportId,
            "reportName": reportName,
            "schedule": schedule,
            "format": format,
            "recipients": recipients,
            "nextRun": nextRun,
            "isActive": true
        ])
        await loadScheduledExports()
        #endif
    }
    
    private func calculateNextRun(schedule: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch schedule {
        case "daily":
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case "weekly":
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case "monthly":
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        default:
            return now
        }
    }
}
