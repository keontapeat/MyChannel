//
//  SLAMonitoringService.swift
//  MyChannel
//
//  SLA Monitoring Dashboard - Track SLAs with breach alerts
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class SLAMonitoringService: ObservableObject {
    static let shared = SLAMonitoringService()
    
    @Published private(set) var sLAs: [ServiceLevelAgreement] = []
    @Published private(set) var sLAMetrics: [SLAMetric] = []
    @Published private(set) var breaches: [SLABreach] = []
    
    struct ServiceLevelAgreement: Identifiable, Codable {
        let id: String
        let name: String
        let service: String
        let targetMetric: String
        let targetValue: Double
        let unit: String
        let currentPerformance: Double
        let status: String
        let lastBreach: Date?
    }
    
    struct SLAMetric: Identifiable, Codable {
        let id: String
        let slaId: String
        let slaName: String
        let metricName: String
        let currentValue: Double
        let targetValue: Double
        let percentage: Double
        let trend: String
    }
    
    struct SLABreach: Identifiable, Codable {
        let id: String
        let slaId: String
        let slaName: String
        let breachType: String
        let actualValue: Double
        let targetValue: Double
        let breachDuration: TimeInterval
        let startedAt: Date
        let resolvedAt: Date?
        let severity: String
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refreshMetrics() }
        }
        Task { await refreshMetrics() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshMetrics() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let slaSnapshot = try? await db.collection("serviceLevelAgreements").getDocuments()
        
        sLAs = slaSnapshot?.documents.compactMap { doc -> ServiceLevelAgreement? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let service = data["service"] as? String,
                  let targetMetric = data["targetMetric"] as? String,
                  let targetValue = data["targetValue"] as? Double,
                  let unit = data["unit"] as? String,
                  let currentPerformance = data["currentPerformance"] as? Double else { return nil }
            
            let percentage = (currentPerformance / targetValue) * 100
            let status = percentage >= 90 ? "healthy" : percentage >= 75 ? "warning" : "breached"
            
            return ServiceLevelAgreement(
                id: doc.documentID,
                name: name,
                service: service,
                targetMetric: targetMetric,
                targetValue: targetValue,
                unit: unit,
                currentPerformance: currentPerformance,
                status: status,
                lastBreach: (data["lastBreach"] as? Timestamp)?.dateValue()
            )
        } ?? []
        
        let breachSnapshot = try? await db.collection("sLABreaches")
            .order(by: "startedAt", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        breaches = breachSnapshot?.documents.compactMap { doc -> SLABreach? in
            let data = doc.data()
            guard data["resolvedAt"] == nil else { return nil }
            guard let slaId = data["slaId"] as? String,
                  let slaName = data["slaName"] as? String,
                  let breachType = data["breachType"] as? String,
                  let actualValue = data["actualValue"] as? Double,
                  let targetValue = data["targetValue"] as? Double,
                  let startedAt = (data["startedAt"] as? Timestamp)?.dateValue(),
                  let severity = data["severity"] as? String else { return nil }
            
            let breachDuration = Date().timeIntervalSince(startedAt)
            
            return SLABreach(
                id: doc.documentID,
                slaId: slaId,
                slaName: slaName,
                breachType: breachType,
                actualValue: actualValue,
                targetValue: targetValue,
                breachDuration: breachDuration,
                startedAt: startedAt,
                resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
                severity: severity
            )
        } ?? []
        
        sLAMetrics = sLAs.compactMap { sla -> SLAMetric? in
            let percentage = (sla.currentPerformance / sla.targetValue) * 100
            return SLAMetric(
                id: UUID().uuidString,
                slaId: sla.id,
                slaName: sla.name,
                metricName: sla.targetMetric,
                currentValue: sla.currentPerformance,
                targetValue: sla.targetValue,
                percentage: percentage,
                trend: "stable"
            )
        }
        
        // Alert on critical breaches
        for breach in breaches.filter({ $0.severity == "critical" }) {
            try? await EnhancedAlertSystemService.shared.createAlert(
                type: "sla_breach",
                severity: "critical",
                title: "SLA Breach: \(breach.slaName)",
                message: "\(breach.breachType) - \(breach.actualValue) vs target \(breach.targetValue)",
                source: "sla_monitoring"
            )
        }
        #endif
    }
    
    func resolveBreach(breachId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("sLABreaches").document(breachId).updateData([
            "resolvedAt": FieldValue.serverTimestamp()
        ])
        await refreshMetrics()
        #endif
    }
}
