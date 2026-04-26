//
//  TimestampedCommentsService.swift
//  MyChannel
//
//  Phase 146: Timestamped Comments.
//  Comments pinned to video timestamps, floating comment bubbles, seek-to-comment.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct TimestampedComment: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let authorUid: String
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let timestampSec: Double
    let likeCount: Int
    let createdAt: Date
}

struct CommentCluster: Identifiable {
    let id: String
    let timestampSec: Double
    let count: Int
    let topComment: TimestampedComment
}

// MARK: - Service

@MainActor
final class TimestampedCommentsService: ObservableObject {
    static let shared = TimestampedCommentsService()
    private init() {}

    @Published private(set) var comments: [TimestampedComment] = []
    @Published private(set) var clusters: [CommentCluster] = []
    @Published var visibleBubbles: [TimestampedComment] = []

    func loadComments(videoId: String) async throws {
        guard AppConfig.Features.enableTimestampedComments else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("timestamped_comments")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "timestampSec")
            .getDocuments()
        comments = snap.documents.compactMap { doc in
            let d = doc.data()
            return TimestampedComment(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                authorUid: d["authorUid"] as? String ?? "",
                authorName: d["authorName"] as? String ?? "",
                authorAvatarURL: (d["authorAvatarURL"] as? String).flatMap(URL.init(string:)),
                body: d["body"] as? String ?? "",
                timestampSec: d["timestampSec"] as? Double ?? 0,
                likeCount: d["likeCount"] as? Int ?? 0,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        buildClusters()
        #endif
    }

    func postComment(videoId: String, authorUid: String, authorName: String, body: String, timestampSec: Double) async throws {
        guard AppConfig.Features.enableTimestampedComments else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("timestamped_comments").document().setData([
            "videoId": videoId, "authorUid": authorUid, "authorName": authorName,
            "body": body, "timestampSec": timestampSec, "likeCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func updateVisibleBubbles(currentTime: Double, windowSec: Double = 3.0) {
        guard AppConfig.Features.enableTimestampedComments else { return }
        visibleBubbles = comments.filter {
            $0.timestampSec >= currentTime - 0.5 && $0.timestampSec <= currentTime + windowSec
        }
    }

    func commentsAt(timestampSec: Double, toleranceSec: Double = 2.0) -> [TimestampedComment] {
        comments.filter { abs($0.timestampSec - timestampSec) <= toleranceSec }
    }

    private func buildClusters() {
        var result: [CommentCluster] = []
        let bucketSize = 5.0
        let grouped = Dictionary(grouping: comments) { Int($0.timestampSec / bucketSize) }
        for (bucket, group) in grouped.sorted(by: { $0.key < $1.key }) {
            guard let top = group.max(by: { $0.likeCount < $1.likeCount }) else { continue }
            result.append(CommentCluster(
                id: "\(bucket)", timestampSec: Double(bucket) * bucketSize,
                count: group.count, topComment: top
            ))
        }
        clusters = result
    }
}
