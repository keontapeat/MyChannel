import Foundation
import AVFoundation

/// Phase 29: Multi-Language Dubbing Engine
/// Dynamically synthesizes speech for localized subtitles if a native dub isn't available.
@MainActor
final class DubbingEngine: ObservableObject {
    static let shared = DubbingEngine()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isDubbingEnabled: Bool = false
    @Published var currentLanguageCode: String = "es-ES" // Default mock
    
    private init() {}
    
    /// Reads a string of text aloud in the specified language, muting the main video momentarily if desired.
    func dubText(_ text: String, languageCode: String? = nil) {
        guard isDubbingEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode ?? currentLanguageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        // In a real app, you might pause or duck the AVPlayer's volume here via AVAudioSession ducking options
        speechSynthesizer.speak(utterance)
    }
    
    func stopDubbing() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
}
