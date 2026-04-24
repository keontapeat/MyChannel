//
//  WatchTimeOptimizerService.swift
//  MyChannel
//
//  Phase 6 supplement: Watch-time optimizer for Creator Studio analytics.
//

import Foundation

struct WatchTimeInsight: Codable {
    let videoId: String
    let avgWatchTime: Double
    let completionRate: Double
    let dropOffPoints: [DropOffPoint]
    let suggestions: [String]

    struct DropOffPoint: Codable, Identifiable {
        let id: String
        let timestamp: Double
        let dropOffPercentage: Double

        init(id: String = UUID().uuidString, timestamp: Double, dropOffPercentage: Double) {
            self.id = id; self.timestamp = timestamp; self.dropOffPercentage = dropOffPercentage
        }
    }

    init(videoId: String, avgWatchTime: Double = 0, completionRate: Double = 0,
         dropOffPoints: [DropOffPoint] = [], suggestions: [String] = []) {
        self.videoId = videoId; self.avgWatchTime = avgWatchTime
        self.completionRate = completionRate; self.dropOffPoints = dropOffPoints
        self.suggestions = suggestions
    }
}

@MainActor
final class WatchTimeOptimizerService: ObservableObject {
    static let shared = WatchTimeOptimizerService()
    private init() {}

    @Published var isAnalyzing: Bool = false

    func analyze(videoId: String, durationSeconds: Double) async -> WatchTimeInsight {
        isAnalyzing = true
        defer { isAnalyzing = false }

        struct Request: Encodable {
            let video_id: String; let duration: Double
        }
        struct RawDropOff: Decodable {
            let timestamp: Double?; let drop_off_percentage: Double?
        }
        struct Response: Decodable {
            let avg_watch_time: Double?; let completion_rate: Double?
            let drop_off_points: [RawDropOff]?; let suggestions: [String]?
        }

        do {
            let raw: Response = try await CloudRunAgentRouter.post(
                .watchTimeOptimizer, path: "/predict",
                body: Request(video_id: videoId, duration: durationSeconds), timeout: 20
            )
            return WatchTimeInsight(
                videoId: videoId,
                avgWatchTime: raw.avg_watch_time ?? 0,
                completionRate: raw.completion_rate ?? 0,
                dropOffPoints: (raw.drop_off_points ?? []).compactMap { d in
                    guard let ts = d.timestamp, let pct = d.drop_off_percentage else { return nil }
                    return .init(timestamp: ts, dropOffPercentage: pct)
                },
                suggestions: raw.suggestions ?? []
            )
        } catch {
            return WatchTimeInsight(videoId: videoId)
        }
    }
}
