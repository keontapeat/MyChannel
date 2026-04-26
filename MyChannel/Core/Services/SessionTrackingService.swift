//
//  SessionTrackingService.swift
//  MyChannel
//
//  Real-time session tracking for active users
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class SessionTrackingService: ObservableObject {
    static let shared = SessionTrackingService()
    
    @Published private(set) var activeSessions: [ActiveSession] = []
    @Published private(set) var activeUserCount: Int = 0
    
    struct ActiveSession: Identifiable, Codable {
        let id: String
        let userId: String
        let startedAt: Date
        let lastActivity: Date
        let deviceType: String
        let location: String?
    }
    
    private var timer: Timer?
    
    private init() {
        startTracking()
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.refreshSessions() }
        }
        Task { await refreshSessions() }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshSessions() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let cutoff = Date().addingTimeInterval(-300) // 5 minutes
        
        let snapshot = try? await db.collection("activeSessions")
            .whereField("lastActivity", isGreaterThan: cutoff)
            .getDocuments()
        
        activeSessions = snapshot?.documents.compactMap { doc -> ActiveSession? in
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let startedAt = (data["startedAt"] as? Timestamp)?.dateValue(),
                  let lastActivity = (data["lastActivity"] as? Timestamp)?.dateValue() else { return nil }
            
            return ActiveSession(
                id: doc.documentID,
                userId: userId,
                startedAt: startedAt,
                lastActivity: lastActivity,
                deviceType: data["deviceType"] as? String ?? "unknown",
                location: data["location"] as? String
            )
        } ?? []
        
        activeUserCount = activeSessions.count
        #endif
    }
    
    func updateSessionActivity(userId: String, deviceType: String, location: String?) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let sessionId = "\(userId)_\(deviceType)"
        
        try? await db.collection("activeSessions").document(sessionId).setData([
            "userId": userId,
            "startedAt": FieldValue.serverTimestamp(),
            "lastActivity": FieldValue.serverTimestamp(),
            "deviceType": deviceType,
            "location": location ?? "unknown"
        ], merge: true)
        #endif
    }
}
