//
//  WatchPartyService.swift
//  MyChannel
//
//  Phase 84: Watch Parties.
//  SharePlay-powered synced playback with up to 50 friends + voice chat +
//  shared reactions. Falls back to a Firestore-synced "Remote Party" mode
//  on devices without GroupActivities support (iPad <iPadOS 15.1, etc.).
//

import Foundation
#if canImport(GroupActivities)
import GroupActivities
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct WatchParty: Codable, Identifiable, Equatable {
    let id: String
    let hostUid: String
    let videoId: String
    let createdAt: Date
    let participantUids: [String]
    let playbackSeconds: Double
    let isPlaying: Bool
}

enum WatchPartyReaction: String, Codable, CaseIterable {
    case laugh, fire, wow, sad, clap, mindBlown
}

@MainActor
final class WatchPartyService: ObservableObject {
    static let shared = WatchPartyService()
    private init() {}

    @Published private(set) var activeParty: WatchParty?
    @Published private(set) var isSupported: Bool = {
        #if canImport(GroupActivities)
        if #available(iOS 15.1, *) { return true }
        #endif
        return false
    }()

    // MARK: - Create / join

    func createParty(hostUid: String, videoId: String) async throws -> WatchParty {
        guard AppConfig.Features.enableWatchParties else { throw PartyError.disabled }
        let id = UUID().uuidString
        let party = WatchParty(
            id: id,
            hostUid: hostUid,
            videoId: videoId,
            createdAt: Date(),
            participantUids: [hostUid],
            playbackSeconds: 0,
            isPlaying: false
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("watchParties").document(id)
            .setData([
                "hostUid": party.hostUid,
                "videoId": party.videoId,
                "createdAt": FieldValue.serverTimestamp(),
                "participantUids": party.participantUids,
                "playbackSeconds": party.playbackSeconds,
                "isPlaying": party.isPlaying
            ])
        #endif

        #if canImport(GroupActivities)
        if #available(iOS 15.1, *) {
            let activity = WatchPartyGroupActivity(partyId: id, videoId: videoId)
            _ = try? await activity.activate()
        }
        #endif

        activeParty = party
        return party
    }

    func join(partyId: String, uid: String) async throws {
        guard AppConfig.Features.enableWatchParties else { throw PartyError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("watchParties").document(partyId)
            .updateData(["participantUids": FieldValue.arrayUnion([uid])])
        #endif
    }

    // MARK: - Sync

    func broadcastPlaybackState(partyId: String, seconds: Double, isPlaying: Bool) async throws {
        guard AppConfig.Features.enableWatchParties else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("watchParties").document(partyId)
            .updateData([
                "playbackSeconds": seconds,
                "isPlaying": isPlaying,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func sendReaction(partyId: String, uid: String, reaction: WatchPartyReaction) async {
        guard AppConfig.Features.enableWatchParties else { return }
        #if canImport(FirebaseFirestore)
        _ = try? await Firestore.firestore()
            .collection("watchParties").document(partyId)
            .collection("reactions").addDocument(data: [
                "uid": uid,
                "reaction": reaction.rawValue,
                "at": FieldValue.serverTimestamp()
            ])
        #endif
    }

    enum PartyError: LocalizedError {
        case disabled
        var errorDescription: String? { "Watch Parties are disabled." }
    }
}

// MARK: - GroupActivities

#if canImport(GroupActivities)
@available(iOS 15.1, *)
struct WatchPartyGroupActivity: GroupActivity {
    let partyId: String
    let videoId: String

    static let activityIdentifier = "com.mychannel.watchparty"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "MyChannel Watch Party"
        meta.type = .watchTogether
        return meta
    }
}
#endif
