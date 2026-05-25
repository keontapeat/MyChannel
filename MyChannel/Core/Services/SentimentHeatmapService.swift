//
//  SentimentHeatmapService.swift
//  MyChannel
//
//  Phase 154: Sentiment Heatmap.
//  Audience engagement heatmap on scrubber, most-replayed segments.
//  Uses `sentiment-analysis` Cloud Run.
//

import Foundation

// MARK: - Models

struct EngagementSegment: Codable, Identifiable {
    let id: Int
    let startSec: Double
    let endSec: Double
    let replayIntensity: Double    // 0–1
    let skipRate: Double           // 0–1
    let retentionPercent: Double
    let sentiment: SegmentSentiment
}

enum SegmentSentiment: String, Codable { case positive, neutral, negative, mixed }

struct MostReplayedMoment: Codable, Identifiable {
    let id: String
    let startSec: Double
    let endSec: Double
    let replayCount: Int
    let label: String
}

// MARK: - Service

@MainActor
final class SentimentHeatmapService: ObservableObject {
    static let shared = SentimentHeatmapService()
    private init() {}

    @Published private(set) var segments: [EngagementSegment] = []
    @Published private(set) var mostReplayed: [MostReplayedMoment] = []
    @Published var showHeatmap: Bool = true

    private var cache: [String: [EngagementSegment]] = [:]

    func loadHeatmap(videoId: String) async throws {
        guard AppConfig.Features.enableSentimentHeatmap else { return }
        if let cached = cache[videoId] { segments = cached; return }

        struct Request: Encodable { let task: String; let videoId: String }
        struct RawSeg: Decodable { let start: Double; let end: Double; let replay: Double; let skip: Double; let retention: Double; let sentiment: String }
        struct RawMoment: Decodable { let start: Double; let end: Double; let count: Int; let label: String }
        struct Raw: Decodable { let segments: [RawSeg]?; let most_replayed: [RawMoment]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .commentAnalyzer, path: "/predict",
            body: Request(task: "engagement_heatmap", videoId: videoId), timeout: 30
        )
        segments = (r.segments ?? []).enumerated().map { idx, s in
            EngagementSegment(id: idx, startSec: s.start, endSec: s.end,
                            replayIntensity: s.replay, skipRate: s.skip,
                            retentionPercent: s.retention,
                            sentiment: SegmentSentiment(rawValue: s.sentiment) ?? .neutral)
        }
        mostReplayed = (r.most_replayed ?? []).map {
            MostReplayedMoment(id: UUID().uuidString, startSec: $0.start, endSec: $0.end,
                              replayCount: $0.count, label: $0.label)
        }
        cache[videoId] = segments
    }

    func intensityAt(fraction: Double, duration: Double) -> Double {
        guard !segments.isEmpty, duration > 0 else { return 0 }
        let time = fraction * duration
        return segments.first { time >= $0.startSec && time < $0.endSec }?.replayIntensity ?? 0
    }

    func heatmapColors(count: Int, duration: Double) -> [Double] {
        guard !segments.isEmpty, duration > 0 else { return Array(repeating: 0, count: count) }
        return (0..<count).map { i in
            let fraction = Double(i) / Double(count)
            return intensityAt(fraction: fraction, duration: duration)
        }
    }
}
