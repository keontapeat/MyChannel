//
//  ViewerMissionsService.swift
//  MyChannel
//
//  Phase 232: Viewer Missions & Quests.
//  Streaks, watch goals, discovery quests, creator challenges,
//  anti-farming protections.
//  Uses `engagement-booster-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ViewerMission: Codable, Identifiable {
    let id: String
    let userId: String
    let type: MissionType
    let title: String
    let description: String
    let target: Int
    let progress: Int
    let reward: String
    let expiresAt: Date?
    let isComplete: Bool
    let claimedAt: Date?

    enum MissionType: String, Codable {
        case streak, watchGoal, discovery, creatorChallenge
    }
}

struct ViewerStreak: Codable, Identifiable {
    let id: String
    let userId: String
    let currentDays: Int
    let longestDays: Int
    let lastActiveDate: String
    let isFrozen: Bool
}

struct FarmingCheck: Codable {
    let isLegitimate: Bool
    let riskScore: Double
    let flags: [String]
}

// MARK: - Service

@MainActor
final class ViewerMissionsService: ObservableObject {
    static let shared = ViewerMissionsService()
    private init() {}

    @Published private(set) var missions: [ViewerMission] = []
    @Published private(set) var streak: ViewerStreak?
    @Published var isLoading: Bool = false

    func fetchMissions(userId: String) async throws {
        guard AppConfig.Features.enableViewerMissions else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawMis: Decodable { let id: String; let type: String; let title: String; let desc: String; let target: Int; let progress: Int; let reward: String; let expires: String?; let complete: Bool; let claimed: String? }
        struct Raw: Decodable { let missions: [RawMis]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "fetch_missions", userId: userId)
        )
        missions = (r.missions ?? []).map {
            ViewerMission(id: $0.id, userId: userId, type: .init(rawValue: $0.type) ?? .watchGoal,
                          title: $0.title, description: $0.desc, target: $0.target, progress: $0.progress,
                          reward: $0.reward, expiresAt: $0.expires.flatMap { ISO8601DateFormatter().date(from: $0) },
                          isComplete: $0.complete, claimedAt: $0.claimed.flatMap { ISO8601DateFormatter().date(from: $0) })
        }
    }

    func fetchStreak(userId: String) async throws {
        guard AppConfig.Features.enableViewerMissions else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let id: String; let current: Int; let longest: Int; let last: String; let frozen: Bool }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "fetch_streak", userId: userId)
        )
        streak = ViewerStreak(id: r.id, userId: userId, currentDays: r.current, longestDays: r.longest,
                               lastActiveDate: r.last, isFrozen: r.frozen)
    }

    func progressMission(missionId: String, increment: Int = 1) async throws {
        guard AppConfig.Features.enableViewerMissions else { return }
        struct Req: Encodable { let task: String; let missionId: String; let increment: Int }
        struct Raw: Decodable { let progress: Int?; let complete: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "progress_mission", missionId: missionId, increment: increment)
        )
        if let idx = missions.firstIndex(where: { $0.id == missionId }) {
            let old = missions[idx]
            missions[idx] = ViewerMission(id: old.id, userId: old.userId, type: old.type, title: old.title,
                                           description: old.description, target: old.target,
                                           progress: r.progress ?? old.progress + increment,
                                           reward: old.reward, expiresAt: old.expiresAt,
                                           isComplete: r.complete ?? old.isComplete, claimedAt: old.claimedAt)
        }
    }

    func checkFarming(userId: String, action: String) async throws -> FarmingCheck {
        guard AppConfig.Features.enableViewerMissions else {
            return FarmingCheck(isLegitimate: true, riskScore: 0, flags: [])
        }
        struct Req: Encodable { let task: String; let userId: String; let action: String }
        struct Raw: Decodable { let legitimate: Bool?; let risk: Double?; let flags: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "check_farming", userId: userId, action: action)
        )
        return FarmingCheck(isLegitimate: r.legitimate ?? true, riskScore: r.risk ?? 0, flags: r.flags ?? [])
    }
}
