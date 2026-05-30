import Foundation
import Speech
import AVFoundation

/// Phase 26: Machine Learning Auto-Captioning
/// Uses SFSpeechRecognizer to perform on-device speech-to-text analysis.
@MainActor
final class AutoCaptionEngine: ObservableObject {
    static let shared = AutoCaptionEngine()
    
    @Published var currentCaption: String = ""
    @Published var isEnabled: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private init() {}
    
    /// Requests authorization from the user for Speech Recognition
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Starts analyzing an active audio tap from an AVPlayer or engine
    func startGeneratingCaptions(from audioEngine: AVAudioEngine) throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw CaptionError.recognizerUnavailable
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { fatalError("Unable to create request") }
        request.shouldReportPartialResults = true
        
        // Use Apple's on-device processing if available
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = true
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            if let result = result {
                self.currentCaption = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopGeneratingCaptions()
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        isEnabled = true
    }
    
    func stopGeneratingCaptions() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isEnabled = false
        currentCaption = ""
    }
    
    enum CaptionError: Error {
        case recognizerUnavailable
    }
}
