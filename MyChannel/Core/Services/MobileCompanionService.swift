//
//  MobileCompanionService.swift
//  MyChannel
//
//  Mobile Companion App - On-the-go monitoring
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MobileCompanionService: ObservableObject {
    static let shared = MobileCompanionService()
    
    @Published private(set) var isCompanionEnabled = false
    @Published private(set) var companionDeviceId: String?
    @Published private(set) var pushNotificationsEnabled = false
    @Published private(set) var criticalAlertsOnly = false
    
    struct CompanionConfig: Codable {
        let deviceId: String
        let deviceName: String
        let platform: String
        let enabledFeatures: [String]
        let notificationPreferences: NotificationPreferences
    }
    
    struct NotificationPreferences: Codable {
        let criticalAlerts: Bool
        let dailySummary: Bool
        let thresholdBreaches: Bool
        let quietHoursStart: String?
        let quietHoursEnd: String?
    }
    
    private init() {
        loadCompanionConfig()
    }
    
    func loadCompanionConfig() {
        #if canImport(FirebaseFirestore)
        // Load from UserDefaults or Firestore
        #endif
    }
    
    func enableCompanion(deviceId: String, deviceName: String, platform: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        try await db.collection("companionDevices").document(deviceId).setData([
            "deviceId": deviceId,
            "deviceName": deviceName,
            "platform": platform,
            "enabledAt": FieldValue.serverTimestamp(),
            "notificationPreferences": [
                "criticalAlerts": true,
                "dailySummary": true,
                "thresholdBreaches": true
            ]
        ] as [String: Any])
        
        isCompanionEnabled = true
        companionDeviceId = deviceId
        #endif
    }
    
    func disableCompanion() async throws {
        #if canImport(FirebaseFirestore)
        guard let deviceId = companionDeviceId else { return }

        let db = Firestore.firestore()
        try await db.collection("companionDevices").document(deviceId).updateData([
            "enabled": false,
            "disabledAt": FieldValue.serverTimestamp()
        ] as [String: Any])
        
        isCompanionEnabled = false
        companionDeviceId = nil
        #endif
    }
    
    func updateNotificationPreferences(criticalOnly: Bool, dailySummary: Bool, quietHours: Bool) async throws {
        #if canImport(FirebaseFirestore)
        guard let deviceId = companionDeviceId else { return }

        let db = Firestore.firestore()
        try await db.collection("companionDevices").document(deviceId).updateData([
            "notificationPreferences.criticalAlerts": criticalOnly,
            "notificationPreferences.dailySummary": dailySummary,
            "notificationPreferences.quietHours": quietHours
        ] as [String: Any])
        
        criticalAlertsOnly = criticalOnly
        pushNotificationsEnabled = dailySummary
        #endif
    }
    
    func sendPushNotification(deviceId: String, title: String, message: String, severity: String) async {
        // Send push notification via FCM
        print("📱 Sending push to \(deviceId): \(title) - \(message)")
    }
}
