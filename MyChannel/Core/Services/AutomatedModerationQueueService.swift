//
//  AutomatedModerationQueueService.swift
//  MyChannel
//
//  Phase 264: Automated Moderation Queue Prioritization
//  AI-powered prioritization of moderation tasks based on severity, urgency, impact
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class AutomatedModerationQueueService: ObservableObject {
    static let shared = AutomatedModerationQueueService()
    
    @Published private(set) var priorityQueue: [ModerationTask] = []
    @Published private(set) var autoResolved: Int = 0
    @Published private(set) var escalated: Int = 0
    @Published private(set) var avgResolutionTime: Double = 0
    
    struct ModerationTask: Identifiable, Codable {
        let id: String
        let contentType: String
        let contentId: String
        let severity: String
        let priorityScore: Double
        let category: String
        let flaggedAt: Date
        let reporterId: String?
        let aiConfidence: Double
        let userImpact: Int
        let requiresHumanReview: Bool
        let autoActionSuggested: String?
        
        var urgency: String {
            priorityScore >= 0.9 ? "Critical" : priorityScore >= 0.7 ? "High" : priorityScore >= 0.5 ? "Medium" : "Low"
        }
    }
    
    private init() {
        Task { await loadQueue() }
    }
    
    func loadQueue() async {
        guard AppConfig.Features.enableModerationGovernance else { return }
        
        struct Req: Encodable { let task: String }
        struct RawTask: Decodable { let id: String; let contentType: String; let contentId: String; let severity: String; let priorityScore: Double; let category: String; let flaggedAt: String; let reporterId: String?; let aiConfidence: Double; let userImpact: Int; let requiresHumanReview: Bool; let autoActionSuggested: String? }
        struct Raw: Decodable { let priorityQueue: [RawTask]?; let autoResolved: Int?; let escalated: Int?; let avgResolutionTime: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.contentModeration, path: "/predict",
                body: Req(task: "get_moderation_queue"), timeout: 20)
            
            let decoder = ISO8601DateFormatter()
            
            priorityQueue = (r.priorityQueue ?? []).map {
                ModerationTask(
                    id: $0.id,
                    contentType: $0.contentType,
                    contentId: $0.contentId,
                    severity: $0.severity,
                    priorityScore: $0.priorityScore,
                    category: $0.category,
                    flaggedAt: decoder.date(from: $0.flaggedAt) ?? Date(),
                    reporterId: $0.reporterId,
                    aiConfidence: $0.aiConfidence,
                    userImpact: $0.userImpact,
                    requiresHumanReview: $0.requiresHumanReview,
                    autoActionSuggested: $0.autoActionSuggested
                )
            }.sorted { $0.priorityScore > $1.priorityScore }
            
            autoResolved = r.autoResolved ?? 0
            escalated = r.escalated ?? 0
            avgResolutionTime = r.avgResolutionTime ?? 0
            
        } catch {
            print("⚠️ [AutomatedModerationQueue] Error: \(error)")
        }
    }
    
    func approveAutoAction(taskId: String) async throws {
        struct Req: Encodable { let task: String; let taskId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.contentModeration, path: "/predict",
            body: Req(task: "approve_auto_action", taskId: taskId), timeout: 15)
        guard r.success == true else { throw NSError(domain: "ModerationQueue", code: -1, userInfo: nil) }
        await loadQueue()
    }
    
    func escalateTask(taskId: String, reason: String) async throws {
        struct Req: Encodable { let task: String; let taskId: String; let reason: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.contentModeration, path: "/predict",
            body: Req(task: "escalate_task", taskId: taskId, reason: reason), timeout: 15)
        guard r.success == true else { throw NSError(domain: "ModerationQueue", code: -1, userInfo: nil) }
        await loadQueue()
    }
}
