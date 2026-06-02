//
//  FlicksCaptionService.swift
//  MyChannel
//
//  On-device automatic caption generation for Flicks using the Speech framework.
//  Transcribes a video's audio into timed caption cues so the player can show
//  YouTube Shorts-style auto-captions. Results are cached per video id.
//

import Foundation
import Speech
import AVFoundation

/// A single timed caption cue.
struct CaptionCue: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let start: TimeInterval
    let end: TimeInterval

    func isActive(at time: TimeInterval) -> Bool {
        time >= start && time <= end
    }
}

@MainActor
final class FlicksCaptionService: ObservableObject {
    static let shared = FlicksCaptionService()
    private init() {}

    /// In-memory cache of generated cues keyed by flick id.
    private var cache: [String: [CaptionCue]] = [:]
    /// In-flight generations to avoid duplicate work.
    private var inFlight: Set<String> = []

    enum CaptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case noAudio
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition permission was not granted."
            case .recognizerUnavailable: return "Speech recognition is unavailable on this device."
            case .noAudio: return "This video has no audio track to caption."
            case .failed(let msg): return msg
            }
        }
    }

    /// Returns cached cues if present.
    func cachedCaptions(for flickId: String) -> [CaptionCue]? {
        cache[flickId]
    }

    /// Requests Speech authorization (idempotent).
    func requestAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }

    /// Generates (or returns cached) captions for a flick's video URL.
    /// Uses on-device recognition when available for privacy and offline support.
    func generateCaptions(for flickId: String, videoURL: String) async throws -> [CaptionCue] {
        if let cached = cache[flickId] { return cached }
        guard !inFlight.contains(flickId) else {
            // Another request is already running; wait briefly and return whatever lands.
            return cache[flickId] ?? []
        }
        guard let url = URL(string: videoURL) else {
            throw CaptionError.failed("Invalid video URL")
        }

        guard await requestAuthorization() else { throw CaptionError.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw CaptionError.recognizerUnavailable
        }

        inFlight.insert(flickId)
        defer { inFlight.remove(flickId) }

        // Extract audio to a local file the recognizer can read.
        let audioURL = try await extractAudio(from: url)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.taskHint = .dictation

        let cues: [CaptionCue] = try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: CaptionError.failed(error.localizedDescription))
                    return
                }
                guard let result = result, result.isFinal else { return }
                let cues = Self.buildCues(from: result.bestTranscription)
                cont.resume(returning: cues)
            }
        }

        cache[flickId] = cues
        return cues
    }

    // MARK: - Helpers

    /// Groups recognized segments into readable, time-bounded caption cues
    /// (roughly one short phrase per cue, like Shorts captions).
    private static func buildCues(from transcription: SFTranscription) -> [CaptionCue] {
        var cues: [CaptionCue] = []
        var currentWords: [String] = []
        var cueStart: TimeInterval = 0
        var lastEnd: TimeInterval = 0
        let maxWordsPerCue = 6
        let maxCueDuration: TimeInterval = 2.5

        for (index, segment) in transcription.segments.enumerated() {
            if currentWords.isEmpty {
                cueStart = segment.timestamp
            }
            currentWords.append(segment.substring)
            lastEnd = segment.timestamp + segment.duration

            let reachedWordLimit = currentWords.count >= maxWordsPerCue
            let reachedTimeLimit = (lastEnd - cueStart) >= maxCueDuration
            let isLast = index == transcription.segments.count - 1

            if reachedWordLimit || reachedTimeLimit || isLast {
                let text = currentWords.joined(separator: " ")
                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    cues.append(CaptionCue(text: text, start: cueStart, end: lastEnd))
                }
                currentWords.removeAll()
            }
        }
        return cues
    }

    /// Exports just the audio track of a (possibly remote) video to a local m4a.
    private func extractAudio(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
        guard hasAudio else { throw CaptionError.noAudio }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CaptionError.failed("Could not create audio export session")
        }
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("caption_audio_\(UUID().uuidString).m4a")
        exportSession.outputURL = outURL
        exportSession.outputFileType = .m4a

        await exportSession.export()
        guard exportSession.status == .completed else {
            throw CaptionError.failed(exportSession.error?.localizedDescription ?? "Audio export failed")
        }
        return outURL
    }
}
