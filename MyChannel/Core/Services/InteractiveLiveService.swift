//
//  InteractiveLiveService.swift
//  MyChannel
//
//  Phase 85: Interactive Live — polls, predictions, trivia overlays.
//  Creators push an overlay during a live stream; viewers answer in-app;
//  results stream back in real-time. Awards XP + leaderboards.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum InteractiveOverlayKind: String, Codable, CaseIterable {
    case poll
    case prediction
    case trivia
    case emojiRain       // tap-to-react burst
}

struct InteractiveOverlay: Codable, Identifiable, Equatable {
    let id: String
    let streamId: String
    let creatorUid: String
    let kind: InteractiveOverlayKind
    let question: String
    let options: [String]
    let correctIndex: Int?         // trivia only
    let startedAt: Date
    let endsAt: Date
    let xpReward: Int
    let isActive: Bool
}

struct InteractiveResult: Codable, Equatable {
    let overlayId: String
    let counts: [Int]              // count per option index
    let totalVotes: Int
    let topAnswerIndex: Int?
}

@MainActor
final class InteractiveLiveService: ObservableObject {
    static let shared = InteractiveLiveService()
    private init() {}

    @Published private(set) var currentOverlay: InteractiveOverlay?
    @Published private(set) var latestResult: InteractiveResult?

    // MARK: - Creator-side

    func startOverlay(_ overlay: InteractiveOverlay) async throws {
        guard AppConfig.Features.enableInteractiveLive else { throw ILError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("liveStreams").document(overlay.streamId)
            .collection("overlays").document(overlay.id)
            .setData([
                "creatorUid": overlay.creatorUid,
                "kind": overlay.kind.rawValue,
                "question": overlay.question,
                "options": overlay.options,
                "correctIndex": overlay.correctIndex as Any,
                "startedAt": overlay.startedAt,
                "endsAt": overlay.endsAt,
                "xpReward": overlay.xpReward,
                "isActive": true
            ])
        #endif
        currentOverlay = overlay
    }

    func closeOverlay(streamId: String, overlayId: String) async throws {
        guard AppConfig.Features.enableInteractiveLive else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("liveStreams").document(streamId)
            .collection("overlays").document(overlayId)
            .updateData(["isActive": false])
        #endif
        currentOverlay = nil
    }

    // MARK: - Viewer-side

    func submitAnswer(streamId: String, overlayId: String, uid: String, optionIndex: Int) async throws {
        guard AppConfig.Features.enableInteractiveLive else { throw ILError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("liveStreams").document(streamId)
            .collection("overlays").document(overlayId)
            .collection("answers").document(uid)
            .setData([
                "optionIndex": optionIndex,
                "at": FieldValue.serverTimestamp()
            ])
        #endif

        // Let the live-stream optimizer factor in audience engagement.
        struct Request: Encodable {
            let task: String
            let streamId: String
            let overlayId: String
            let uid: String
        }
        _ = try? await CloudRunAgentRouter.post(
            .liveStreamOptimizer,
            path: "/predict",
            body: Request(task: "track_answer", streamId: streamId, overlayId: overlayId, uid: uid)
        ) as _Ack
    }

    // MARK: - Results tally

    func fetchResult(streamId: String, overlayId: String, optionsCount: Int) async throws -> InteractiveResult {
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("liveStreams").document(streamId)
            .collection("overlays").document(overlayId)
            .collection("answers").getDocuments()

        var counts = Array(repeating: 0, count: optionsCount)
        for doc in snap.documents {
            if let idx = doc.data()["optionIndex"] as? Int, counts.indices.contains(idx) {
                counts[idx] += 1
            }
        }
        let total = counts.reduce(0, +)
        let top = counts.enumerated().max(by: { $0.element < $1.element })?.offset
        let result = InteractiveResult(overlayId: overlayId, counts: counts, totalVotes: total, topAnswerIndex: top)
        latestResult = result
        return result
        #else
        return InteractiveResult(overlayId: overlayId, counts: [], totalVotes: 0, topAnswerIndex: nil)
        #endif
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum ILError: LocalizedError {
        case disabled
        var errorDescription: String? { "Interactive Live is disabled." }
    }
}
