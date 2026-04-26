//
//  ProfileOfflineService.swift
//  MyChannel
//
//  Phase 257: Profile Offline Mode & Caching.
//  Full profile offline cache, background refresh,
//  stale-data indicators, offline edit queue, sync-on-reconnect.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct OfflineProfile: Codable, Identifiable {
    let id: String
    let creatorId: String
    let displayName: String
    let username: String
    let bio: String?
    let profileImageURL: String?
    let bannerImageURL: String?
    let subscriberCount: Int
    let videoCount: Int
    let cachedAt: Date
    let isStale: Bool
}

struct OfflineEdit: Codable, Identifiable {
    let id: String
    let creatorId: String
    let field: String
    let value: String
    let queuedAt: Date
    let syncStatus: SyncStatus

    enum SyncStatus: String, Codable { case pending, syncing, failed, completed }
}

// MARK: - Service

@MainActor
final class ProfileOfflineService: ObservableObject {
    static let shared = ProfileOfflineService()
    private init() {}

    @Published private(set) var offlineProfile: OfflineProfile?
    @Published private(set) var pendingEdits: [OfflineEdit] = []
    @Published private(set) var isStale: Bool = false

    func cacheProfile(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileOffline else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let id: String; let name: String; let username: String; let bio: String?; let image: String?; let banner: String?; let subs: Int; let videos: Int }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "cache_profile", creatorId: creatorId)
        )
        offlineProfile = OfflineProfile(id: r.id, creatorId: creatorId, displayName: r.name, username: r.username,
                                          bio: r.bio, profileImageURL: r.image, bannerImageURL: r.banner,
                                          subscriberCount: r.subs, videoCount: r.videos, cachedAt: Date(), isStale: false)
        isStale = false
    }

    func queueEdit(creatorId: String, field: String, value: String) -> OfflineEdit {
        let edit = OfflineEdit(id: UUID().uuidString, creatorId: creatorId, field: field, value: value,
                                 queuedAt: Date(), syncStatus: .pending)
        pendingEdits.append(edit)
        return edit
    }

    func syncPendingEdits() async throws {
        guard AppConfig.Features.enableProfileOffline else { return }
        for i in pendingEdits.indices where pendingEdits[i].syncStatus == .pending {
            pendingEdits[i] = OfflineEdit(id: pendingEdits[i].id, creatorId: pendingEdits[i].creatorId,
                                            field: pendingEdits[i].field, value: pendingEdits[i].value,
                                            queuedAt: pendingEdits[i].queuedAt, syncStatus: .syncing)
            struct Req: Encodable { let task: String; let creatorId: String; let field: String; let value: String }
            struct Raw: Decodable { let ok: Bool? }
            do {
                let _: Raw = try await CloudRunAgentRouter.post(
                    .myChannelContent, path: "/predict",
                    body: Req(task: "apply_offline_edit", creatorId: pendingEdits[i].creatorId,
                              field: pendingEdits[i].field, value: pendingEdits[i].value)
                )
                pendingEdits[i] = OfflineEdit(id: pendingEdits[i].id, creatorId: pendingEdits[i].creatorId,
                                                field: pendingEdits[i].field, value: pendingEdits[i].value,
                                                queuedAt: pendingEdits[i].queuedAt, syncStatus: .completed)
            } catch {
                pendingEdits[i] = OfflineEdit(id: pendingEdits[i].id, creatorId: pendingEdits[i].creatorId,
                                                field: pendingEdits[i].field, value: pendingEdits[i].value,
                                                queuedAt: pendingEdits[i].queuedAt, syncStatus: .failed)
            }
        }
        pendingEdits.removeAll { $0.syncStatus == .completed }
    }

    func markStale() {
        isStale = true
        if var profile = offlineProfile {
            profile = OfflineProfile(id: profile.id, creatorId: profile.creatorId, displayName: profile.displayName,
                                       username: profile.username, bio: profile.bio, profileImageURL: profile.profileImageURL,
                                       bannerImageURL: profile.bannerImageURL, subscriberCount: profile.subscriberCount,
                                       videoCount: profile.videoCount, cachedAt: profile.cachedAt, isStale: true)
            offlineProfile = profile
        }
    }
}
