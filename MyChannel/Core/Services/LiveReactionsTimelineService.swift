//
//  LiveReactionsTimelineService.swift
//  MyChannel
//
//  Phase 147: Live Reactions Timeline.
//  Emoji reactions mapped to timestamps, reaction heatmap on scrubber.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct VideoReaction: Codable, Identifiable {
    let id: String
    let videoId: String
    let uid: String
    let emoji: String
    let timestampSec: Double
    let createdAt: Date
}

struct ReactionBucket: Identifiable {
    let id: Int
    let startSec: Double
    let endSec: Double
    let total: Int
    let topEmoji: String
    let intensity: Double    // 0–1 normalized
}

// MARK: - Service

@MainActor
final class LiveReactionsTimelineService: ObservableObject {
    static let shared = LiveReactionsTimelineService()
    private init() {}

    @Published private(set) var reactions: [VideoReaction] = []
    @Published private(set) var heatmap: [ReactionBucket] = []
    @Published var floatingEmojis: [(id: String, emoji: String, x: CGFloat)] = []

    func loadReactions(videoId: String) async throws {
        guard AppConfig.Features.enableLiveReactionsTimeline else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("video_reactions")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "timestampSec")
            .getDocuments()
        reactions = snap.documents.compactMap { doc in
            let d = doc.data()
            return VideoReaction(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                uid: d["uid"] as? String ?? "", emoji: d["emoji"] as? String ?? "👍",
                timestampSec: d["timestampSec"] as? Double ?? 0,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        buildHeatmap()
        #endif
    }

    func react(videoId: String, uid: String, emoji: String, timestampSec: Double) async throws {
        guard AppConfig.Features.enableLiveReactionsTimeline else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("video_reactions").document().setData([
            "videoId": videoId, "uid": uid, "emoji": emoji,
            "timestampSec": timestampSec, "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
        let reaction = VideoReaction(id: UUID().uuidString, videoId: videoId, uid: uid,
                                     emoji: emoji, timestampSec: timestampSec, createdAt: Date())
        reactions.append(reaction)
        buildHeatmap()
        showFloatingEmoji(emoji)
    }

    func updateFloating(currentTime: Double) {
        guard AppConfig.Features.enableLiveReactionsTimeline else { return }
        let nearby = reactions.filter { abs($0.timestampSec - currentTime) < 0.5 }
        for r in nearby {
            showFloatingEmoji(r.emoji)
        }
    }

    private func showFloatingEmoji(_ emoji: String) {
        let entry = (id: UUID().uuidString, emoji: emoji, x: CGFloat.random(in: 0.1...0.9))
        floatingEmojis.append(entry)
        if floatingEmojis.count > 20 { floatingEmojis.removeFirst(10) }
    }

    private func buildHeatmap() {
        let bucketSize = 5.0
        let grouped = Dictionary(grouping: reactions) { Int($0.timestampSec / bucketSize) }
        let maxCount = grouped.values.map(\.count).max() ?? 1
        heatmap = grouped.map { bucket, group in
            let emojiCounts = Dictionary(grouping: group, by: \.emoji).mapValues(\.count)
            let topEmoji = emojiCounts.max(by: { $0.value < $1.value })?.key ?? "👍"
            return ReactionBucket(
                id: bucket, startSec: Double(bucket) * bucketSize,
                endSec: Double(bucket + 1) * bucketSize,
                total: group.count, topEmoji: topEmoji,
                intensity: Double(group.count) / Double(maxCount)
            )
        }.sorted { $0.startSec < $1.startSec }
    }
}
