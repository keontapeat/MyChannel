//
//  LiveCaptionsService.swift
//  MyChannel
//
//  Phase 174: Live Captions & Sign Language.
//  Real-time ASR captioning, sign language avatar overlay.
//  Uses `translation-ai-v2` Cloud Run.
//

import Foundation
import Speech
import AVFoundation

// MARK: - Models

struct LiveCaption: Identifiable {
    let id: String
    let text: String
    let language: String
    let timestampSec: Double
    let isFinal: Bool
    let confidence: Double
}

struct SignLanguageOverlay: Codable {
    let avatarURL: URL?
    let language: String
    let isActive: Bool
}

// MARK: - Service

@MainActor
final class LiveCaptionsService: ObservableObject {
    static let shared = LiveCaptionsService()
    private init() {}

    @Published private(set) var captions: [LiveCaption] = []
    @Published var isEnabled: Bool = false
    @Published var targetLanguage: String = "en"
    @Published var signLanguageOverlay: SignLanguageOverlay?
    @Published var fontSize: CGFloat = 16

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let maxCaptions = 50

    func startCaptioning() {
        guard AppConfig.Features.enableLiveCaptions else { return }
        isEnabled = true
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: targetLanguage))

        guard let recognizer, recognizer.isAvailable else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self, status == .authorized else { return }
            DispatchQueue.main.async {
                self.startRecognitionLoop()
            }
        }
    }

    private func startRecognitionLoop() {
        guard isEnabled, let recognizer else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor in
                    let confidence = Double(result.bestTranscription.segments.last?.confidence ?? 1.0)
                    self.addCaption(transcript, isFinal: result.isFinal, confidence: confidence)
                }
            }
            if error != nil || result?.isFinal == true {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                // Restart for continuous captioning
                Task { @MainActor in
                    if self.isEnabled { self.startRecognitionLoop() }
                }
            }
        }
    }

    func stopCaptioning() {
        isEnabled = false
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    func addCaption(_ text: String, isFinal: Bool, confidence: Double = 1.0) {
        guard AppConfig.Features.enableLiveCaptions, isEnabled else { return }
        let caption = LiveCaption(
            id: UUID().uuidString, text: text, language: targetLanguage,
            timestampSec: Date().timeIntervalSince1970, isFinal: isFinal, confidence: confidence
        )
        captions.append(caption)
        if captions.count > maxCaptions { captions.removeFirst(captions.count - maxCaptions) }
    }

    func translateCaption(_ text: String, to language: String) async throws -> String {
        guard AppConfig.Features.enableLiveCaptions else { return text }
        struct Request: Encodable { let task: String; let text: String; let target_lang: String }
        struct Raw: Decodable { let translated: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .translationAI, path: "/predict",
            body: Request(task: "translate_live", text: text, target_lang: language)
        )
        return r.translated ?? text
    }

    func enableSignLanguage(language: String = "asl") {
        guard AppConfig.Features.enableLiveCaptions else { return }
        signLanguageOverlay = SignLanguageOverlay(avatarURL: nil, language: language, isActive: true)
    }

    func disableSignLanguage() {
        signLanguageOverlay = nil
    }

    func setFontSize(_ size: CGFloat) {
        fontSize = max(12, min(32, size))
    }
}
