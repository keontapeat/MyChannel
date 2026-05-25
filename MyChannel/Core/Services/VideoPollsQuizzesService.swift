//
//  VideoPollsQuizzesService.swift
//  MyChannel
//
//  Phase 150: Video Polls & Quizzes.
//  In-video interactive polls, knowledge checks, result analytics.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct ServiceVideoPoll: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let question: String
    let options: [VideoQuizPollOption]
    let timestampSec: Double
    let durationSec: Double
    let totalVotes: Int
    let type: VideoQuizPollType
}

enum VideoQuizPollType: String, Codable { case poll, quiz }

struct VideoQuizPollOption: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let voteCount: Int
    let isCorrect: Bool?     // nil for polls, true/false for quizzes
}

struct PollVote: Codable {
    let pollId: String
    let optionId: String
    let uid: String
    let timestamp: Date
}

struct PollAnalytics: Codable, Identifiable {
    let id: String
    let pollId: String
    let participationRate: Double
    let correctRate: Double?
    let avgResponseTimeSec: Double
}

// MARK: - Service

@MainActor
final class VideoPollsQuizzesService: ObservableObject {
    static let shared = VideoPollsQuizzesService()
    private init() {}

    @Published private(set) var polls: [ServiceVideoPoll] = []
    @Published var activePoll: ServiceVideoPoll?
    @Published var hasVoted: Set<String> = []

    func loadPolls(videoId: String) async throws {
        guard AppConfig.Features.enableVideoPollsQuizzes else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("video_polls").whereField("videoId", isEqualTo: videoId)
            .order(by: "timestampSec").getDocuments()
        polls = snap.documents.compactMap { doc in
            let d = doc.data()
            let opts = (d["options"] as? [[String: Any]])?.map { o in
                VideoQuizPollOption(id: o["id"] as? String ?? UUID().uuidString,
                          text: o["text"] as? String ?? "",
                          voteCount: o["voteCount"] as? Int ?? 0,
                          isCorrect: o["isCorrect"] as? Bool)
            } ?? []
            return ServiceVideoPoll(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                question: d["question"] as? String ?? "",
                options: opts, timestampSec: d["timestampSec"] as? Double ?? 0,
                durationSec: d["durationSec"] as? Double ?? 15,
                totalVotes: d["totalVotes"] as? Int ?? 0,
                type: VideoQuizPollType(rawValue: d["type"] as? String ?? "poll") ?? .poll
            )
        }
        #endif
    }

    func checkActive(currentTime: Double) {
        guard AppConfig.Features.enableVideoPollsQuizzes else { return }
        activePoll = polls.first {
            currentTime >= $0.timestampSec && currentTime <= $0.timestampSec + $0.durationSec
            && !hasVoted.contains($0.id)
        }
    }

    func vote(pollId: String, optionId: String, uid: String) async throws {
        guard AppConfig.Features.enableVideoPollsQuizzes else { return }
        hasVoted.insert(pollId)
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("poll_votes").document().setData([
            "pollId": pollId, "optionId": optionId, "uid": uid,
            "timestamp": FieldValue.serverTimestamp()
        ])
        try await Firestore.firestore().collection("video_polls").document(pollId)
            .updateData(["totalVotes": FieldValue.increment(Int64(1))])
        #endif
    }

    func createPoll(videoId: String, question: String, options: [String], timestampSec: Double, type: VideoQuizPollType, correctOptionIndex: Int? = nil) async throws -> String {
        guard AppConfig.Features.enableVideoPollsQuizzes else { return "" }
        #if canImport(FirebaseFirestore)
        let opts = options.enumerated().map { idx, text in
            ["id": UUID().uuidString, "text": text, "voteCount": 0,
             "isCorrect": (type == .quiz && idx == correctOptionIndex) as Any] as [String: Any]
        }
        let ref = Firestore.firestore().collection("video_polls").document()
        try await ref.setData([
            "videoId": videoId, "question": question, "options": opts,
            "timestampSec": timestampSec, "durationSec": 15.0,
            "totalVotes": 0, "type": type.rawValue
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }
}
