//
//  ProfileSyncService.swift
//  MyChannel
//
//  Phase 258: Profile Cross-Device Sync.
//  Real-time profile state sync, conflict resolution,
//  device-aware layout adaptation, continuity handoff, watch-to-phone follow.
//  Uses `mychannel-auth` + `mychannel-events` Cloud Run.
//

import Foundation

// MARK: - Models

struct SyncState: Codable {
    let creatorId: String
    let deviceId: String
    let lastSyncAt: Date
    let version: Int
    let pendingChanges: Int
}

struct ProfileSyncConflict: Codable, Identifiable {
    let id: String
    let field: String
    let localValue: String
    let remoteValue: String
    let remoteDevice: String
    let detectedAt: Date
    let resolution: Resolution

    enum Resolution: String, Codable { case local, remote, manual }
}

struct ProfileSyncDeviceSession: Codable, Identifiable {
    let id: String
    let deviceId: String
    let deviceType: String
    let lastActive: Date
    let isActive: Bool
}

// MARK: - Service

@MainActor
final class ProfileSyncService: ObservableObject {
    static let shared = ProfileSyncService()
    private init() {}

    @Published private(set) var syncState: SyncState?
    @Published private(set) var conflicts: [ProfileSyncConflict] = []
    @Published private(set) var devices: [ProfileSyncDeviceSession] = []
    @Published var isSyncing: Bool = false

    func fetchSyncState(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileSync else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawDev: Decodable { let id: String; let type: String; let last_active: String?; let active: Bool }
        struct Raw: Decodable { let device_id: String?; let last_sync: String?; let version: Int?; let pending: Int?; let devices: [RawDev]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "fetch_sync_state", creatorId: creatorId)
        )
        syncState = SyncState(creatorId: creatorId, deviceId: r.device_id ?? "",
                                lastSyncAt: r.last_sync.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                                version: r.version ?? 0, pendingChanges: r.pending ?? 0)
        devices = (r.devices ?? []).map {
            ProfileSyncDeviceSession(id: $0.id, deviceId: $0.id, deviceType: $0.type,
                                     lastActive: $0.last_active.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(), isActive: $0.active)
        }
    }

    func pushChanges(creatorId: String, changes: [String: String]) async throws {
        guard AppConfig.Features.enableProfileSync else { return }
        isSyncing = true
        defer { isSyncing = false }
        struct Req: Encodable { let task: String; let creatorId: String; let changes: [String: String] }
        struct RawConflict: Decodable { let id: String; let field: String; let local: String; let remote: String; let device: String }
        struct Raw: Decodable { let version: Int?; let conflicts: [RawConflict]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "push_profile_changes", creatorId: creatorId, changes: changes)
        )
        conflicts = (r.conflicts ?? []).map {
            ProfileSyncConflict(id: $0.id, field: $0.field, localValue: $0.local, remoteValue: $0.remote,
                                remoteDevice: $0.device, detectedAt: Date(), resolution: .manual)
        }
        if var state = syncState {
            state = SyncState(creatorId: state.creatorId, deviceId: state.deviceId,
                                lastSyncAt: Date(), version: r.version ?? state.version + 1, pendingChanges: 0)
            syncState = state
        }
    }

    func resolveConflict(conflictId: String, resolution: ProfileSyncConflict.Resolution) async throws {
        guard AppConfig.Features.enableProfileSync else { return }
        struct Req: Encodable { let task: String; let conflictId: String; let resolution: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Req(task: "resolve_sync_conflict", conflictId: conflictId, resolution: resolution.rawValue)
        )
        conflicts.removeAll { $0.id == conflictId }
    }

    func handoffTo(creatorId: String, targetDeviceId: String) async throws {
        guard AppConfig.Features.enableProfileSync else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let targetDevice: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents, path: "/predict",
            body: Req(task: "handoff_profile", creatorId: creatorId, targetDevice: targetDeviceId)
        )
    }
}
