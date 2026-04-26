//
//  CreatorSupportQueueService.swift
//  MyChannel
//
//  Creator Support Queue - Ticket management, priority tiers, response tracking
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class CreatorSupportQueueService: ObservableObject {
    static let shared = CreatorSupportQueueService()
    
    @Published private(set) var openTickets: [SupportTicket] = []
    @Published private(set) var closedTickets: [SupportTicket] = []
    @Published private(set) var avgResponseTime: Double = 0
    
    struct SupportTicket: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let creatorTier: String
        let category: String
        let subject: String
        let description: String
        let priority: String
        let status: String
        let createdAt: Date
        let assignedTo: String?
        let firstResponseAt: Date?
        let resolvedAt: Date?
        let slaBreach: Bool
    }
    
    private init() {
        Task { await loadTickets() }
    }
    
    func loadTickets() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let openSnapshot = try? await db.collection("creatorSupportTickets")
            .whereField("status", isNotEqualTo: "closed")
            .order(by: "priority", descending: true)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        let closedSnapshot = try? await db.collection("creatorSupportTickets")
            .whereField("status", isEqualTo: "closed")
            .order(by: "resolvedAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        
        openTickets = (openSnapshot?.documents ?? []).compactMap { doc -> SupportTicket? in
            let data = doc.data()
            guard let creatorId = data["creatorId"] as? String,
                  let creatorName = data["creatorName"] as? String,
                  let creatorTier = data["creatorTier"] as? String,
                  let category = data["category"] as? String,
                  let subject = data["subject"] as? String,
                  let description = data["description"] as? String,
                  let priority = data["priority"] as? String,
                  let status = data["status"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return SupportTicket(
                id: doc.documentID,
                creatorId: creatorId,
                creatorName: creatorName,
                creatorTier: creatorTier,
                category: category,
                subject: subject,
                description: description,
                priority: priority,
                status: status,
                createdAt: createdAt,
                assignedTo: data["assignedTo"] as? String,
                firstResponseAt: (data["firstResponseAt"] as? Timestamp)?.dateValue(),
                resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
                slaBreach: data["slaBreach"] as? Bool ?? false
            )
        }.sorted { ticket1, ticket2 in
            let priorityOrder = ["critical", "high", "medium", "low"]
            let p1 = priorityOrder.firstIndex(of: ticket1.priority) ?? 999
            let p2 = priorityOrder.firstIndex(of: ticket2.priority) ?? 999
            if p1 != p2 { return p1 < p2 }
            return ticket1.createdAt < ticket2.createdAt
        }
        
        closedTickets = (closedSnapshot?.documents ?? []).compactMap { doc -> SupportTicket? in
            let data = doc.data()
            guard let creatorId = data["creatorId"] as? String,
                  let creatorName = data["creatorName"] as? String,
                  let creatorTier = data["creatorTier"] as? String,
                  let category = data["category"] as? String,
                  let subject = data["subject"] as? String,
                  let description = data["description"] as? String,
                  let priority = data["priority"] as? String,
                  let status = data["status"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return SupportTicket(
                id: doc.documentID,
                creatorId: creatorId,
                creatorName: creatorName,
                creatorTier: creatorTier,
                category: category,
                subject: subject,
                description: description,
                priority: priority,
                status: status,
                createdAt: createdAt,
                assignedTo: data["assignedTo"] as? String,
                firstResponseAt: (data["firstResponseAt"] as? Timestamp)?.dateValue(),
                resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
                slaBreach: data["slaBreach"] as? Bool ?? false
            )
        }
        
        // Calculate avg response time
        let responseTimes = closedTickets.compactMap { ticket -> Double? in
            guard let firstResponse = ticket.firstResponseAt else { return nil }
            return firstResponse.timeIntervalSince(ticket.createdAt)
        }
        avgResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        #endif
    }
    
    func createTicket(creatorId: String, creatorName: String, creatorTier: String, category: String, subject: String, description: String, priority: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("creatorSupportTickets").document()
        
        try await docRef.setData([
            "creatorId": creatorId,
            "creatorName": creatorName,
            "creatorTier": creatorTier,
            "category": category,
            "subject": subject,
            "description": description,
            "priority": priority,
            "status": "open",
            "createdAt": FieldValue.serverTimestamp(),
            "slaBreach": false
        ])
        await loadTickets()
        #endif
    }
    
    func assignTicket(ticketId: String, assigneeId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("creatorSupportTickets").document(ticketId).updateData([
            "assignedTo": assigneeId,
            "status": "assigned"
        ])
        await loadTickets()
        #endif
    }
    
    func respondToTicket(ticketId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("creatorSupportTickets").document(ticketId).updateData([
            "firstResponseAt": FieldValue.serverTimestamp(),
            "status": "in_progress"
        ])
        await loadTickets()
        #endif
    }
    
    func resolveTicket(ticketId: String, resolution: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("creatorSupportTickets").document(ticketId).updateData([
            "status": "closed",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolution": resolution
        ])
        await loadTickets()
        #endif
    }
}
