//
//  ProfilePrivacyService.swift
//  MyChannel
//
//  Phase 256: Profile Privacy & Visibility Controls.
//  Granular visibility per section, follower-only content gates,
//  block/mute management, data export, right-to-forget.
//  Uses `mychannel-auth` + `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfilePrivacySettings: Codable {
    let creatorId: String
    let sectionVisibility: [String: VisibilityLevel]
    let allowDMs: Bool
    let showOnlineStatus: Bool
    let showWatchHistory: Bool
    let showSubscriptions: Bool

    enum VisibilityLevel: String, Codable { case everyone, followers, membersOnly, `private` }
}

struct ProfileBlockedUser: Codable, Identifiable {
    let id: String
    let blockedUserId: String
    let blockedByUsername: String
    let reason: String?
    let blockedAt: Date
}

struct DataExportRequest: Codable, Identifiable {
    let id: String
    let creatorId: String
    let status: ExportStatus
    let requestedAt: Date
    let downloadURL: String?
    let expiresAt: Date?

    enum ExportStatus: String, Codable { case pending, processing, ready, expired }
}

// MARK: - Service

@MainActor
final class ProfilePrivacyService: ObservableObject {
    static let shared = ProfilePrivacyService()
    private init() {}

    @Published private(set) var settings: ProfilePrivacySettings?
    @Published private(set) var blockedUsers: [ProfileBlockedUser] = []

    func fetchPrivacySettings(creatorId: String) async throws {
        guard AppConfig.Features.enableProfilePrivacy else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawVis: Decodable { let section: String; let level: String }
        struct Raw: Decodable { let visibility: [RawVis]?; let allow_dms: Bool?; let online: Bool?; let history: Bool?; let subs: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "fetch_privacy_settings", creatorId: creatorId)
        )
        var visMap: [String: ProfilePrivacySettings.VisibilityLevel] = [:]
        for v in (r.visibility ?? []) {
            visMap[v.section] = .init(rawValue: v.level) ?? .everyone
        }
        settings = ProfilePrivacySettings(creatorId: creatorId, sectionVisibility: visMap,
                                            allowDMs: r.allow_dms ?? true, showOnlineStatus: r.online ?? true,
                                            showWatchHistory: r.history ?? false, showSubscriptions: r.subs ?? false)
    }

    func updatePrivacySettings(creatorId: String, section: String, level: ProfilePrivacySettings.VisibilityLevel) async throws {
        guard AppConfig.Features.enableProfilePrivacy else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let section: String; let level: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "update_privacy", creatorId: creatorId, section: section, level: level.rawValue)
        )
        if let current = settings {
            var visibility = current.sectionVisibility
            visibility[section] = level
            settings = ProfilePrivacySettings(creatorId: current.creatorId, sectionVisibility: visibility,
                                              allowDMs: current.allowDMs, showOnlineStatus: current.showOnlineStatus,
                                              showWatchHistory: current.showWatchHistory, showSubscriptions: current.showSubscriptions)
        }
    }

    func blockUser(creatorId: String, blockedUserId: String, reason: String?) async throws {
        guard AppConfig.Features.enableProfilePrivacy else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let blockedId: String; let reason: String? }
        struct Raw: Decodable { let id: String; let username: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Req(task: "block_user", creatorId: creatorId, blockedId: blockedUserId, reason: reason)
        )
        let blocked = ProfileBlockedUser(id: r.id, blockedUserId: blockedUserId, blockedByUsername: r.username, reason: reason, blockedAt: Date())
        blockedUsers.append(blocked)
    }

    func requestDataExport(creatorId: String) async throws -> DataExportRequest {
        guard AppConfig.Features.enableProfilePrivacy else {
            return DataExportRequest(id: "", creatorId: creatorId, status: .pending, requestedAt: Date(), downloadURL: nil, expiresAt: nil)
        }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let id: String; let status: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "request_data_export", creatorId: creatorId), timeout: 30
        )
        return DataExportRequest(id: r.id, creatorId: creatorId, status: .init(rawValue: r.status) ?? .pending,
                                   requestedAt: Date(), downloadURL: nil, expiresAt: nil)
    }

    func requestDeletion(creatorId: String) async throws {
        guard AppConfig.Features.enableProfilePrivacy else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "request_account_deletion", creatorId: creatorId), timeout: 30
        )
    }
}
