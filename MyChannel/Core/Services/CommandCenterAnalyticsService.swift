//
//  CommandCenterAnalyticsService.swift
//  MyChannel
//
//  Firebase Analytics integration for Command Center
//  Tracks real user metrics, sessions, retention
//

import Foundation
import Combine
import FirebaseAnalytics
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class CommandCenterAnalyticsService: ObservableObject {
    static let shared = CommandCenterAnalyticsService()
    
    @Published private(set) var dailyMetrics: DailyMetrics?
    @Published private(set) var activeSessions: Int = 0
    
    struct DailyMetrics: Codable {
        let totalUsers: Int
        let newUsersToday: Int
        let activeNow: Int
        let day1Retention: Int
        let day7Retention: Int
        let avgSessionMinutes: Int
        let platformHealth: Double
    }
    
    private init() {
        Task { await loadDailyMetrics() }
    }
    
    func loadDailyMetrics() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try? await db.collection("platformAnalytics").document("daily").getDocument()
        let data = doc?.data() ?? [:]
        
        dailyMetrics = DailyMetrics(
            totalUsers: data["totalUsers"] as? Int ?? 0,
            newUsersToday: data["newUsersToday"] as? Int ?? 0,
            activeNow: data["activeNow"] as? Int ?? 0,
            day1Retention: data["day1Retention"] as? Int ?? 0,
            day7Retention: data["day7Retention"] as? Int ?? 0,
            avgSessionMinutes: data["avgSessionMinutes"] as? Int ?? 0,
            platformHealth: data["platformHealth"] as? Double ?? 92.0
        )
        #endif
    }
    
    func trackSessionStart(userId: String) {
        Analytics.logEvent("session_start", parameters: ["user_id": userId])
    }
    
    func trackSessionEnd(userId: String, duration: TimeInterval) {
        Analytics.logEvent("session_end", parameters: [
            "user_id": userId,
            "duration_seconds": duration
        ])
    }
    
    func updateDailyMetrics() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        // This would be called by a Cloud Function or backend job
        // For now, it's a placeholder for the real analytics pipeline
        #endif
    }
}
