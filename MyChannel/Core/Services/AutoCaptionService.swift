import Speech
import AVFoundation
import Foundation

/// Generates real-time captions for live streams and auto-transcribes uploaded videos using Apple Speech.
@MainActor
final class AutoCaptionService: ObservableObject {
    static let shared = AutoCaptionService()

    @Published var liveCaptions: String = ""
    @Published var isTranscribing: Bool = false
    @Published var fullTranscript: String = ""
    @Published var captionSegments: [CaptionSegment] = []
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    struct CaptionSegment: Identifiable {
        let id = UUID()
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
    }

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private init() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    cont.resume(returning: status == .authorized)
                }
            }
        }
    }

    // MARK: - Live Caption (microphone)

    func startLiveCaptions(locale: Locale = .current) throws {
        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isTranscribing = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.liveCaptions = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self?.stopLiveCaptions()
                }
            }
        }
    }

    func stopLiveCaptions() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
    }

    // MARK: - Transcribe audio file (uploaded videos)

    func transcribeFile(url: URL, locale: Locale = .current) async -> [CaptionSegment] {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return [] }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { return [] }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return await withCheckedContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                guard let result, error == nil else {
                    cont.resume(returning: [])
                    return
                }
                let segments = result.bestTranscription.segments.map { seg in
                    CaptionSegment(
                        text: seg.substring,
                        startTime: seg.timestamp,
                        endTime: seg.timestamp + seg.duration,
                        confidence: seg.confidence
                    )
                }
                Task { @MainActor in self.captionSegments = segments }
                cont.resume(returning: segments)
            }
        }
    }

    // MARK: - Export SRT

    func exportSRT(from segments: [CaptionSegment]) -> String {
        segments.enumerated().map { index, seg in
            """
            \(index + 1)
            \(formatSRTTime(seg.startTime)) --> \(formatSRTTime(seg.endTime))
            \(seg.text)

            """
        }.joined()
    }

    private func formatSRTTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((seconds * 1000).truncatingRemainder(dividingBy: 1000))
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}
