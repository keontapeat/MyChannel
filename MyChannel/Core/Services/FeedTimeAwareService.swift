//
//  FeedTimeAwareService.swift
//  MyChannel
//
//  Phase 269: Feed Time-Aware Scheduling — time-of-day content adaptation,
//  weekend vs weekday mix, seasonal content boost, circadian patterns.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct TimeContext: Codable {
    let timeSlot: String
    let isWeekend: Bool
    let season: String
    let localHour: Int
    let timezone: String
    let contentBias: [String: Double]
}

@MainActor
final class FeedTimeAwareService: ObservableObject {
    static let shared = FeedTimeAwareService()
    private init() {}
    @Published private(set) var context: TimeContext?

    func detectContext() {
        guard AppConfig.Features.enableFeedTimeAware else { return }
        let cal = Calendar.current; let now = Date(); let hour = cal.component(.hour, from: now)
        let weekday = cal.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7
        let month = cal.component(.month, from: now)
        let season = month <= 2 || month == 12 ? "winter" : month <= 5 ? "spring" : month <= 8 ? "summer" : "fall"
        let slot: String; var bias: [String: Double]
        switch hour {
        case 6..<10: slot = "morning"; bias = ["news": 1.3, "education": 1.2, "music": 1.1]
        case 10..<14: slot = "midday"; bias = ["howto": 1.2, "tech": 1.1, "cooking": 1.3]
        case 14..<18: slot = "afternoon"; bias = ["gaming": 1.2, "sports": 1.1, "comedy": 1.15]
        case 18..<22: slot = "evening"; bias = ["entertainment": 1.3, "movies": 1.2, "music": 1.15]
        default: slot = "night"; bias = ["asmr": 1.3, "music": 1.2, "lofi": 1.4]
        }
        if isWeekend { bias["entertainment"] = (bias["entertainment"] ?? 1.0) * 1.15 }
        context = TimeContext(timeSlot: slot, isWeekend: isWeekend, season: season, localHour: hour,
            timezone: TimeZone.current.identifier, contentBias: bias)
    }

    func fetchBias(userId: String) async throws {
        struct Req: Encodable { let task: String; let userId: String; let hour: Int; let weekend: Bool }
        struct Raw: Decodable { let bias: [String: Double]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_time_bias", userId: userId, hour: context?.localHour ?? 12, weekend: context?.isWeekend ?? false))
        if let old = context {
            context = TimeContext(timeSlot: old.timeSlot, isWeekend: old.isWeekend, season: old.season,
                localHour: old.localHour, timezone: old.timezone, contentBias: r.bias ?? old.contentBias)
        }
    }
}
