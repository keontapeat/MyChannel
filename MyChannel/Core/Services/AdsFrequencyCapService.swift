//
//  AdsFrequencyCapService.swift
//  MyChannel
//
//  Ad frequency capping per user, per session, per placement.
//  Prevents ad fatigue, enforces cooldowns, tracks exposure.
//

import Foundation

struct AdExposure: Codable, Identifiable {
    let id: String
    let userId: String
    let adUnit: String
    let placement: String
    let shownAt: Date
    let duration: TimeInterval
    let wasSkippable: Bool
    let wasCompleted: Bool
}

struct FrequencyCap: Codable {
    let adUnit: String
    let maxPerHour: Int
    let maxPerDay: Int
    let maxPerSession: Int
    let minIntervalSec: Double
}

@MainActor
final class AdsFrequencyCapService: ObservableObject {
    static let shared = AdsFrequencyCapService()
    private init() {}
    @Published private(set) var exposures: [AdExposure] = []
    private let caps: [FrequencyCap] = [
        FrequencyCap(adUnit: "pre_roll", maxPerHour: 3, maxPerDay: 12, maxPerSession: 5, minIntervalSec: 120),
        FrequencyCap(adUnit: "mid_roll", maxPerHour: 2, maxPerDay: 8, maxPerSession: 3, minIntervalSec: 300),
        FrequencyCap(adUnit: "banner", maxPerHour: 10, maxPerDay: 40, maxPerSession: 15, minIntervalSec: 60),
        FrequencyCap(adUnit: "overlay", maxPerHour: 4, maxPerDay: 16, maxPerSession: 6, minIntervalSec: 180)
    ]

    func canShow(userId: String, adUnit: String) -> Bool {
        guard let cap = caps.first(where: { $0.adUnit == adUnit }) else { return true }
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let dayAgo = now.addingTimeInterval(-86400)
        let sessionExposures = exposures.filter { $0.userId == userId && $0.adUnit == adUnit }
        let hourly = sessionExposures.filter { $0.shownAt > hourAgo }.count
        let daily = sessionExposures.filter { $0.shownAt > dayAgo }.count
        if hourly >= cap.maxPerHour { return false }
        if daily >= cap.maxPerDay { return false }
        if let last = sessionExposures.last?.shownAt, now.timeIntervalSince(last) < cap.minIntervalSec { return false }
        return true
    }

    func recordExposure(userId: String, adUnit: String, placement: String, duration: TimeInterval, skippable: Bool, completed: Bool) {
        let exp = AdExposure(id: UUID().uuidString, userId: userId, adUnit: adUnit, placement: placement,
            shownAt: Date(), duration: duration, wasSkippable: skippable, wasCompleted: completed)
        exposures.append(exp)
        if exposures.count > 1000 { exposures = Array(exposures.suffix(500)) }
    }

    func hourlyCount(userId: String, adUnit: String) -> Int {
        exposures.filter { $0.userId == userId && $0.adUnit == adUnit && $0.shownAt > Date().addingTimeInterval(-3600) }.count
    }

    func dailyCount(userId: String, adUnit: String) -> Int {
        exposures.filter { $0.userId == userId && $0.adUnit == adUnit && $0.shownAt > Date().addingTimeInterval(-86400) }.count
    }

    func resetForSession() { exposures.removeAll() }
}
