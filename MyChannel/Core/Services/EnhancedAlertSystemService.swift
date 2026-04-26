//
//  EnhancedAlertSystemService.swift
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
class EnhancedAlertSystemService: ObservableObject {
    static let shared = EnhancedAlertSystemService()
    
    @Published private(set) var activeAlerts: [SystemAlert] = []
    @Published private(set) var alertHistory: [SystemAlert] = []
    @Published private(set) var onCallUser: String?
    @Published private(set) var onCallRotation: [OnCallSchedule] = []
    
    struct SystemAlert: Identifiable, Codable {
        let id: String
        let type: String
        let severity: String
        let title: String
        let message: String
        let triggeredAt: Date
        let acknowledged: Bool
        let acknowledgedBy: String?
        let acknowledgedAt: Date?
        let escalated: Bool
        let source: String
    }
    
    struct OnCallSchedule: Identifiable, Codable {
        let id: String
        let userId: String
        let userName: String
        let startDate: Date
        let endDate: Date
        let isActive: Bool
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
        
        let onCallDoc = try? await db.collection("onCallSchedule").document("current").getDocument()
        onCallUser = onCallDoc?.data()?["userId"] as? String
        
        let rotationSnapshot = try? await db.collection("onCallSchedule")
            .order(by: "startDate", descending: true)
            .limit(to: 10)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        onCallRotation = (rotationSnapshot?.documents ?? []).compactMap { doc -> OnCallSchedule? in
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let userName = data["userName"] as? String,
                  let startDateStr = data["startDate"] as? String,
                  let endDateStr = data["endDate"] as? String else { return nil }
            
            return OnCallSchedule(
                id: doc.documentID,
                userId: userId,
                userName: userName,
                startDate: decoder.date(from: startDateStr) ?? Date(),
                endDate: decoder.date(from: endDateStr) ?? Date(),
                isActive: data["isActive"] as? Bool ?? false
            )
        }
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
    
    func setOnCallSchedule(userId: String, userName: String, startDate: Date, endDate: Date) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let encoder = ISO8601DateFormatter()
        
        try await db.collection("onCallSchedule").document(UUID().uuidString).setData([
            "userId": userId,
            "userName": userName,
            "startDate": encoder.string(from: startDate),
            "endDate": encoder.string(from: endDate),
            "isActive": true
        ])
        await refreshAlerts()
        #endif
    }
}
