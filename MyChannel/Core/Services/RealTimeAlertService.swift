//
//  RealTimeAlertService.swift
//  MyChannel
//
//  Real-time Alert System - Push notifications, severity levels, escalation
//

import Foundation
import Combine
import UserNotifications
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class RealTimeAlertService: ObservableObject {
    static let shared = RealTimeAlertService()
    
    @Published private(set) var activeAlerts: [SystemAlert] = []
    @Published private(set) var alertHistory: [SystemAlert] = []
    @Published private(set) var onCallUser: String?
    
    struct SystemAlert: Identifiable, Codable {
        let id: String
        let type: String
        let severity: String // critical, high, medium, low
        let title: String
        let message: String
        let triggeredAt: Date
        let acknowledged: Bool
        let acknowledgedBy: String?
        let acknowledgedAt: Date?
        let escalated: Bool
        let source: String
    }
    
    private var timer: Timer?
    
    private init() {
        requestNotificationPermission()
        startMonitoring()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshAlerts() }
        }
        Task { await refreshAlerts() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshAlerts() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let activeSnapshot = try? await db.collection("systemAlerts")
            .whereField("acknowledged", isEqualTo: false)
            .order(by: "triggeredAt", descending: true)
            .getDocuments()
        
        activeAlerts = activeSnapshot?.documents.compactMap { doc -> SystemAlert? in
            let data = doc.data()
            guard let type = data["type"] as? String,
                  let severity = data["severity"] as? String,
                  let title = data["title"] as? String,
                  let message = data["message"] as? String,
                  let triggeredAt = (data["triggeredAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return SystemAlert(
                id: doc.documentID,
                type: type,
                severity: severity,
                title: title,
                message: message,
                triggeredAt: triggeredAt,
                acknowledged: data["acknowledged"] as? Bool ?? false,
                acknowledgedBy: data["acknowledgedBy"] as? String,
                acknowledgedAt: (data["acknowledgedAt"] as? Timestamp)?.dateValue(),
                escalated: data["escalated"] as? Bool ?? false,
                source: data["source"] as? String ?? "system"
            )
        } ?? []
        
        // Send push notifications for new critical alerts
        for alert in activeAlerts.filter({ $0.severity == "critical" }) {
            await sendPushNotification(alert: alert)
        }
        
        // Load on-call user
        let onCallDoc = try? await db.collection("onCallSchedule").document("current").getDocument()
        onCallUser = onCallDoc?.data()?["userId"] as? String
        #endif
    }
    
    func acknowledgeAlert(alertId: String, userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("systemAlerts").document(alertId).updateData([
            "acknowledged": true,
            "acknowledgedBy": userId,
            "acknowledgedAt": FieldValue.serverTimestamp()
        ])
        await refreshAlerts()
        #endif
    }
    
    func escalateAlert(alertId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("systemAlerts").document(alertId).updateData([
            "escalated": true,
            "escalatedAt": FieldValue.serverTimestamp()
        ])
        await refreshAlerts()
        #endif
    }
    
    func createAlert(type: String, severity: String, title: String, message: String, source: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("systemAlerts").document()
        
        try await docRef.setData([
            "type": type,
            "severity": severity,
            "title": title,
            "message": message,
            "triggeredAt": FieldValue.serverTimestamp(),
            "acknowledged": false,
            "escalated": false,
            "source": source
        ])
        await refreshAlerts()
        #endif
    }
    
    private func sendPushNotification(alert: SystemAlert) async {
        let content = UNMutableNotificationContent()
        content.title = "🚨 \(alert.title)"
        content.body = alert.message
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
