//
//  RealTimeUserJourneysService.swift
//  MyChannel
//
//  Real-time User Journeys - Live session replay and user path tracking
//

import Foundation
import Combine

@MainActor
class RealTimeUserJourneysService: ObservableObject {
    static let shared = RealTimeUserJourneysService()
    
    @Published private(set) var activeSessions: [UserSession] = []
    @Published private(set) var sessionPaths: [SessionPath] = []
    
    struct UserSession: Identifiable, Codable {
        let id: String
        let userId: String
        let currentScreen: String
        let sessionDuration: Double
        let screensVisited: [String]
        let actions: [SessionAction]
        let startedAt: Date
    }
    
    struct SessionAction: Codable {
        let type: String
        let screen: String
        let timestamp: Date
        let details: String?
    }
    
    struct SessionPath: Identifiable, Codable {
        let id: String
        let path: [String]
        let frequency: Int
        let avgCompletionRate: Double
        let commonDropoffPoint: String?
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshSessions() }
        }
        Task { await refreshSessions() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshSessions() async {
        guard AppConfig.Features.enableStudioRealTimeAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawAction: Decodable { let type: String; let screen: String; let timestamp: String; let details: String? }
        struct RawSession: Decodable { let id: String; let userId: String; let currentScreen: String; let sessionDuration: Double; let screensVisited: [String]; let actions: [RawAction]; let startedAt: String }
        struct RawPath: Decodable { let id: String; let path: [String]; let frequency: Int; let avgCompletionRate: Double; let commonDropoffPoint: String? }
        struct Raw: Decodable { let activeSessions: [RawSession]?; let sessionPaths: [RawPath]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_user_journeys"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            activeSessions = (r.activeSessions ?? []).map {
                UserSession(
                    id: $0.id,
                    userId: $0.userId,
                    currentScreen: $0.currentScreen,
                    sessionDuration: $0.sessionDuration,
                    screensVisited: $0.screensVisited,
                    actions: $0.actions.map {
                        SessionAction(
                            type: $0.type,
                            screen: $0.screen,
                            timestamp: decoder.date(from: $0.timestamp) ?? Date(),
                            details: $0.details
                        )
                    },
                    startedAt: decoder.date(from: $0.startedAt) ?? Date()
                )
            }
            
            sessionPaths = (r.sessionPaths ?? []).map {
                SessionPath(
                    id: $0.id,
                    path: $0.path,
                    frequency: $0.frequency,
                    avgCompletionRate: $0.avgCompletionRate,
                    commonDropoffPoint: $0.commonDropoffPoint
                )
            }.sorted { $0.frequency > $1.frequency }
            
        } catch {
            print("⚠️ [RealTimeUserJourneys] Error: \(error)")
        }
    }
    
    func replaySession(sessionId: String) async throws -> UserSession {
        struct Req: Encodable { let task: String; let sessionId: String }
        struct RawAction: Decodable { let type: String; let screen: String; let timestamp: String; let details: String? }
        struct RawSession: Decodable { let id: String; let userId: String; let currentScreen: String; let sessionDuration: Double; let screensVisited: [String]; let actions: [RawAction]; let startedAt: String }
        struct Raw: Decodable { let session: RawSession? }
        
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "replay_session", sessionId: sessionId), timeout: 30)
        
        guard let raw = r.session else { throw NSError(domain: "UserJourneys", code: -1, userInfo: nil) }
        
        let decoder = ISO8601DateFormatter()
        return UserSession(
            id: raw.id,
            userId: raw.userId,
            currentScreen: raw.currentScreen,
            sessionDuration: raw.sessionDuration,
            screensVisited: raw.screensVisited,
            actions: raw.actions.map {
                SessionAction(
                    type: $0.type,
                    screen: $0.screen,
                    timestamp: decoder.date(from: $0.timestamp) ?? Date(),
                    details: $0.details
                )
            },
            startedAt: decoder.date(from: raw.startedAt) ?? Date()
        )
    }
}
