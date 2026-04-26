//
//  HapticTimelineService.swift
//  MyChannel
//
//  Phase 157: Haptic Timeline.
//  Taptic feedback per chapter boundary, beat-synced haptics.
//  Uses `ai-music-v2` for beat detection.
//

import Foundation
import UIKit

// MARK: - Models

struct HapticMarker: Identifiable, Equatable {
    let id: String
    let timestampSec: Double
    let type: HapticType
    let intensity: CGFloat      // 0–1
}

enum HapticType: String, CaseIterable {
    case chapter, beat, highlight, transition
}

struct BeatPattern: Codable {
    let bpm: Int
    let timestamps: [Double]
    let strongBeats: [Double]
}

// MARK: - Service

@MainActor
final class HapticTimelineService: ObservableObject {
    static let shared = HapticTimelineService()
    private init() {}

    @Published var isEnabled: Bool = true
    @Published var hapticIntensity: CGFloat = 0.7
    @Published private(set) var markers: [HapticMarker] = []
    @Published private(set) var beatPattern: BeatPattern?

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var lastFiredTimestamp: Double = -1

    func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
    }

    func buildMarkers(chapters: [Video.Chapter]?) {
        guard AppConfig.Features.enableHapticTimeline else { return }
        var result: [HapticMarker] = []
        if let chapters = chapters {
            for ch in chapters {
                result.append(HapticMarker(id: "ch-\(ch.start)", timestampSec: ch.start,
                                          type: .chapter, intensity: 0.8))
            }
        }
        if let bp = beatPattern {
            for (idx, ts) in bp.timestamps.enumerated() {
                let isStrong = bp.strongBeats.contains(ts)
                result.append(HapticMarker(
                    id: "beat-\(idx)", timestampSec: ts,
                    type: .beat, intensity: isStrong ? 1.0 : 0.4
                ))
            }
        }
        markers = result.sorted { $0.timestampSec < $1.timestampSec }
    }

    func fireIfNeeded(at currentTime: Double) {
        guard AppConfig.Features.enableHapticTimeline, isEnabled else { return }
        for marker in markers {
            let diff = abs(currentTime - marker.timestampSec)
            if diff < 0.15 && marker.timestampSec != lastFiredTimestamp {
                lastFiredTimestamp = marker.timestampSec
                fire(marker)
                break
            }
        }
    }

    private func fire(_ marker: HapticMarker) {
        let adjusted = marker.intensity * hapticIntensity
        switch marker.type {
        case .chapter:
            mediumGenerator.impactOccurred(intensity: adjusted)
        case .beat:
            if adjusted > 0.7 { heavyGenerator.impactOccurred(intensity: adjusted) }
            else { lightGenerator.impactOccurred(intensity: adjusted) }
        case .highlight:
            heavyGenerator.impactOccurred(intensity: adjusted)
        case .transition:
            lightGenerator.impactOccurred(intensity: adjusted)
        }
    }

    func detectBeats(videoId: String) async throws {
        guard AppConfig.Features.enableHapticTimeline else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let bpm: Int?; let timestamps: [Double]?; let strong_beats: [Double]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiMusicv2, path: "/predict",
            body: Request(task: "detect_beats", videoId: videoId), timeout: 30
        )
        beatPattern = BeatPattern(bpm: r.bpm ?? 0, timestamps: r.timestamps ?? [], strongBeats: r.strong_beats ?? [])
    }

    func setIntensity(_ value: CGFloat) {
        hapticIntensity = max(0, min(1, value))
    }
}
