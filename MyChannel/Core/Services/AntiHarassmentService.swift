//
//  AntiHarassmentService.swift
//  MyChannel
//
//  Anti-harassment: toxic comment detection, harassment pattern analysis,
//  user protection actions, automated moderation. Uses `trust-safety-ai` Cloud Run.
//

import Foundation

struct HarassmentDetection: Codable, Identifiable {
    let id: String
    let contentId: String
    let userId: String
    let targetType: String
    let severity: HarassmentSeverity
    let categories: [String]
    let confidence: Double
    let actionTaken: String
    let detectedAt: Date
    enum HarassmentSeverity: String, Codable { case low, medium, high, critical }
}

struct UserProtection: Codable, Identifiable {
    let id: String
    let userId: String
    let protectionType: ProtectionType
    let reason: String
    let createdAt: Date
    let expiresAt: Date?
    enum ProtectionType: String, Codable { case commentShield, dmFilter, followRestriction, fullShield }
}

@MainActor
final class AntiHarassmentService: ObservableObject {
    static let shared = AntiHarassmentService()
    private init() {}
    @Published private(set) var detections: [HarassmentDetection] = []
    @Published private(set) var protections: [UserProtection] = []

    func analyzeContent(contentId: String, text: String, authorId: String) async throws -> HarassmentDetection? {
        struct Req: Encodable { let task: String; let contentId: String; let text: String; let authorId: String }
        struct Raw: Decodable { let id: String; let severity: String?; let categories: [String]?; let confidence: Double?; let action: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "analyze_harassment", contentId: contentId, text: text, authorId: authorId))
        guard r.confidence ?? 0 > 0.5 else { return nil }
        let det = HarassmentDetection(id: r.id, contentId: contentId, userId: authorId, targetType: "comment",
            severity: .init(rawValue: r.severity ?? "low") ?? .low, categories: r.categories ?? [], confidence: r.confidence ?? 0,
            actionTaken: r.action ?? "none", detectedAt: Date())
        detections.append(det); return det
    }

    func enableProtection(userId: String, type: UserProtection.ProtectionType, reason: String, durationHours: Int? = nil) async throws {
        struct Req: Encodable { let task: String; let userId: String; let type: String; let reason: String; let hours: Int? }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "enable_protection", userId: userId, type: type.rawValue, reason: reason, hours: durationHours))
        let prot = UserProtection(id: UUID().uuidString, userId: userId, protectionType: type, reason: reason,
            createdAt: Date(), expiresAt: durationHours.map { Date().addingTimeInterval(Double($0) * 3600) })
        protections.append(prot)
    }

    func reportHarassment(reporterId: String, targetId: String, contentId: String, description: String) async throws {
        struct Req: Encodable { let task: String; let reporter: String; let target: String; let contentId: String; let description: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "report_harassment", reporter: reporterId, target: targetId, contentId: contentId, description: description))
    }
}
