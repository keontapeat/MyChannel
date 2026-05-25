//
//  VisionProV2Service.swift
//  MyChannel
//
//  Phase 90: Vision Pro v2.
//  Co-watch rooms, spatial reactions, hand-tracked Creator Studio chrome.
//  Ships inside the iPad/iPhone binary via visionOS compatibility; a native
//  visionOS target is added separately for full immersive scenes.
//

import Foundation

struct VisionCoWatchRoom: Codable, Identifiable, Equatable {
    let id: String
    let hostUid: String
    let videoId: String
    let environment: VisionEnvironment
    let participantsLimit: Int
    let participantUids: [String]
    let createdAt: Date
}

enum VisionEnvironment: String, Codable, CaseIterable {
    case livingRoom
    case cinema
    case sports
    case concert
    case outerSpace
    case studioWhite
}

struct SpatialReaction: Codable, Identifiable, Equatable {
    let id: String
    let roomId: String
    let uid: String
    let emoji: String
    let position: SpatialPoint
    let sentAt: Date
}

struct SpatialPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

@MainActor
final class VisionProV2Service: ObservableObject {
    static let shared = VisionProV2Service()
    private init() {}

    @Published private(set) var activeRoom: VisionCoWatchRoom?
    @Published private(set) var incomingReactions: [SpatialReaction] = []

    // MARK: - Rooms

    func createRoom(hostUid: String, videoId: String, environment: VisionEnvironment) async throws -> VisionCoWatchRoom {
        guard AppConfig.Features.enableVisionProV2 else { throw VisionError.disabled }
        struct Request: Encodable {
            let task: String
            let hostUid: String
            let videoId: String
            let environment: String
        }
        struct Raw: Decodable {
            let id: String
            let participants_limit: Int?
            let created_at: Double?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .vrArAIv2,
            path: "/predict",
            body: Request(
                task: "create_room",
                hostUid: hostUid,
                videoId: videoId,
                environment: environment.rawValue
            )
        )
        let room = VisionCoWatchRoom(
            id: r.id,
            hostUid: hostUid,
            videoId: videoId,
            environment: environment,
            participantsLimit: r.participants_limit ?? 12,
            participantUids: [hostUid],
            createdAt: Date(timeIntervalSince1970: r.created_at ?? Date().timeIntervalSince1970)
        )
        activeRoom = room
        return room
    }

    func join(roomId: String, uid: String) async throws {
        guard AppConfig.Features.enableVisionProV2 else { throw VisionError.disabled }
        struct Request: Encodable {
            let task: String
            let roomId: String
            let uid: String
        }
        _ = try await CloudRunAgentRouter.post(
            .vrArAIv2,
            path: "/predict",
            body: Request(task: "join_room", roomId: roomId, uid: uid)
        ) as _Ack
    }

    // MARK: - Spatial reactions

    func sendReaction(_ reaction: SpatialReaction) async throws {
        guard AppConfig.Features.enableVisionProV2 else { return }
        struct Request: Encodable {
            let task: String
            let reaction: SpatialReaction
        }
        _ = try? await CloudRunAgentRouter.post(
            .vrArAIv2,
            path: "/predict",
            body: Request(task: "send_reaction", reaction: reaction)
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum VisionError: LocalizedError {
        case disabled
        var errorDescription: String? { "Vision Pro features are disabled." }
    }
}
