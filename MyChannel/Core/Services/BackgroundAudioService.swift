import Foundation
import AVFoundation

/// Phase 65: Background Audio Mode
/// Configures AVAudioSession to allow podcast-like listening when the user locks their screen.
@MainActor
final class BackgroundAudioService {
    static let shared = BackgroundAudioService()
    
    private init() {}
    
    /// Configures the app to play audio in the background and show controls on the lock screen.
    func enableBackgroundAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback category is required for background audio
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            print("🎧 [BackgroundAudio] Successfully enabled background audio session.")
        } catch {
            print("⚠️ [BackgroundAudio] Failed to enable background audio: \(error)")
        }
    }
    
    func disableBackgroundAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Revert back to default mix behavior if needed
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("🎧 [BackgroundAudio] Disabled background audio.")
        } catch {
            print("⚠️ [BackgroundAudio] Failed to disable background audio: \(error)")
        }
    }
}
