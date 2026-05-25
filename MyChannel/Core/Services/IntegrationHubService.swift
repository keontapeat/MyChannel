//
//  IntegrationHubService.swift
//  MyChannel
//
//  Integration Hub - Connect Slack, PagerDuty, external tools
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class IntegrationHubService: ObservableObject {
    static let shared = IntegrationHubService()
    
    @Published private(set) var integrations: [Integration] = []
    @Published private(set) var webhookLogs: [WebhookLog] = []
    
    struct Integration: Identifiable, Codable {
        let id: String
        let name: String
        let type: String // slack, pagerduty, discord, teams, webhook
        let config: IntegrationConfig
        let isActive: Bool
        let lastTriggered: Date?
        let successRate: Double
    }
    
    struct IntegrationConfig: Codable {
        let webhookURL: String?
        let apiKey: String?
        let channel: String?
        let events: [String]
    }
    
    struct WebhookLog: Identifiable, Codable {
        let id: String
        let integrationId: String
        let integrationName: String
        let eventType: String
        let payload: String
        let statusCode: Int?
        let response: String?
        let triggeredAt: Date
        let success: Bool
    }
    
    private init() {
        Task { await loadIntegrations() }
        Task { await loadWebhookLogs() }
    }
    
    func loadIntegrations() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("integrations").getDocuments()
        
        let decoder = ISO8601DateFormatter()
        integrations = snapshot?.documents.compactMap { doc -> Integration? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let type = data["type"] as? String,
                  let configData = data["config"] as? [String: Any],
                  let events = configData["events"] as? [String] else { return nil }
            
            let config = IntegrationConfig(
                webhookURL: configData["webhookURL"] as? String,
                apiKey: configData["apiKey"] as? String,
                channel: configData["channel"] as? String,
                events: events
            )
            
            return Integration(
                id: doc.documentID,
                name: name,
                type: type,
                config: config,
                isActive: data["isActive"] as? Bool ?? false,
                lastTriggered: (data["lastTriggered"] as? Timestamp)?.dateValue(),
                successRate: data["successRate"] as? Double ?? 1.0
            )
        } ?? []
        #endif
    }
    
    func loadWebhookLogs() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("webhookLogs")
            .order(by: "triggeredAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        webhookLogs = snapshot?.documents.compactMap { doc -> WebhookLog? in
            let data = doc.data()
            guard let integrationId = data["integrationId"] as? String,
                  let integrationName = data["integrationName"] as? String,
                  let eventType = data["eventType"] as? String,
                  let payload = data["payload"] as? String,
                  let triggeredAt = (data["triggeredAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return WebhookLog(
                id: doc.documentID,
                integrationId: integrationId,
                integrationName: integrationName,
                eventType: eventType,
                payload: payload,
                statusCode: data["statusCode"] as? Int,
                response: data["response"] as? String,
                triggeredAt: triggeredAt,
                success: data["success"] as? Bool ?? false
            )
        } ?? []
        #endif
    }
    
    func addIntegration(name: String, type: String, webhookURL: String?, apiKey: String?, channel: String?, events: [String]) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("integrations").document()
        
        let config: [String: Any] = [
            "webhookURL": webhookURL ?? "",
            "apiKey": apiKey ?? "",
            "channel": channel ?? "",
            "events": events
        ]
        
        try await docRef.setData([
            "name": name,
            "type": type,
            "config": config,
            "isActive": true,
            "successRate": 1.0
        ])
        await loadIntegrations()
        return docRef.documentID
        #else
        throw NSError(domain: "IntegrationHub", code: -1, userInfo: nil)
        #endif
    }
    
    func triggerWebhook(integrationId: String, eventType: String, payload: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Log the webhook attempt
        let logRef = db.collection("webhookLogs").document()
        try await logRef.setData([
            "integrationId": integrationId,
            "integrationName": "Unknown",
            "eventType": eventType,
            "payload": payload,
            "triggeredAt": FieldValue.serverTimestamp(),
            "success": false
        ])
        
        // Update integration last triggered
        try await db.collection("integrations").document(integrationId).updateData([
            "lastTriggered": FieldValue.serverTimestamp()
        ])
        
        await loadWebhookLogs()
        await loadIntegrations()
        #endif
    }
    
    func toggleIntegration(integrationId: String, isActive: Bool) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("integrations").document(integrationId).updateData([
            "isActive": isActive
        ])
        await loadIntegrations()
        #endif
    }
}
