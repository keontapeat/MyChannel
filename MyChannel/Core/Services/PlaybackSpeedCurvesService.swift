//
//  PlaybackSpeedCurvesService.swift
//  MyChannel
//
//  Phase 145: Playback Speed Curves.
//  Variable speed regions, auto-skip silence, custom speed presets.
//  Uses `watch-time-predictor` Cloud Run for silence detection.
//

import Foundation
import AVFoundation

// MARK: - Models

struct SpeedPreset: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let rate: Float
    let icon: String
}

struct SpeedRegion: Codable, Identifiable {
    let id: String
    let startSec: Double
    let endSec: Double
    let rate: Float
    let reason: String     // "silence", "intro", "outro", "custom"
}

struct SilenceSegment: Codable, Identifiable {
    let id: String
    let startSec: Double
    let endSec: Double
    let durationSec: Double
}

// MARK: - Service

@MainActor
final class PlaybackSpeedCurvesService: ObservableObject {
    static let shared = PlaybackSpeedCurvesService()
    private init() {}

    @Published var currentRate: Float = 1.0
    @Published var presets: [SpeedPreset] = [
        SpeedPreset(id: "0.25", name: "0.25x", rate: 0.25, icon: "tortoise"),
        SpeedPreset(id: "0.5", name: "0.5x", rate: 0.5, icon: "tortoise.fill"),
        SpeedPreset(id: "0.75", name: "0.75x", rate: 0.75, icon: "hare"),
        SpeedPreset(id: "1.0", name: "Normal", rate: 1.0, icon: "play"),
        SpeedPreset(id: "1.25", name: "1.25x", rate: 1.25, icon: "hare.fill"),
        SpeedPreset(id: "1.5", name: "1.5x", rate: 1.5, icon: "forward"),
        SpeedPreset(id: "1.75", name: "1.75x", rate: 1.75, icon: "forward.fill"),
        SpeedPreset(id: "2.0", name: "2x", rate: 2.0, icon: "forward.fill"),
    ]
    @Published var speedRegions: [SpeedRegion] = []
    @Published var silenceSegments: [SilenceSegment] = []
    @Published var autoSkipSilence: Bool = false
    @Published var smartSpeedEnabled: Bool = false

    func setRate(_ rate: Float, on player: AVPlayer?) {
        guard AppConfig.Features.enablePlaybackSpeedCurves else { return }
        currentRate = rate
        player?.rate = rate
    }

    func detectSilence(videoId: String) async throws {
        guard AppConfig.Features.enablePlaybackSpeedCurves else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawSilence: Decodable { let start: Double; let end: Double }
        struct Raw: Decodable { let silences: [RawSilence]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .watchTimeOptimizer, path: "/predict",
            body: Request(task: "detect_silence", videoId: videoId), timeout: 30
        )
        silenceSegments = (r.silences ?? []).map {
            SilenceSegment(id: UUID().uuidString, startSec: $0.start, endSec: $0.end, durationSec: $0.end - $0.start)
        }
        if autoSkipSilence {
            speedRegions = silenceSegments.map {
                SpeedRegion(id: UUID().uuidString, startSec: $0.startSec, endSec: $0.endSec, rate: 4.0, reason: "silence")
            }
        }
    }

    func applySmartSpeed(at currentTime: Double, on player: AVPlayer?) {
        guard AppConfig.Features.enablePlaybackSpeedCurves, smartSpeedEnabled else { return }
        if let region = speedRegions.first(where: { currentTime >= $0.startSec && currentTime <= $0.endSec }) {
            if player?.rate != region.rate { player?.rate = region.rate }
        } else {
            if player?.rate != currentRate { player?.rate = currentRate }
        }
    }

    func addCustomRegion(start: Double, end: Double, rate: Float) {
        guard AppConfig.Features.enablePlaybackSpeedCurves else { return }
        let region = SpeedRegion(id: UUID().uuidString, startSec: start, endSec: end, rate: rate, reason: "custom")
        speedRegions.append(region)
    }

    func removeRegion(_ id: String) {
        speedRegions.removeAll { $0.id == id }
    }

    func addCustomPreset(name: String, rate: Float) {
        guard AppConfig.Features.enablePlaybackSpeedCurves else { return }
        let preset = SpeedPreset(id: UUID().uuidString, name: name, rate: rate, icon: "slider.horizontal.3")
        presets.append(preset)
    }
}
