import Foundation
import ShazamKit
import AVFoundation

/// Phase 98: ShazamKit Audio Recognition
/// Identifies copyrighted songs playing in the background of a video.
@MainActor
final class AudioRecognitionEngine: NSObject, ObservableObject, SHSessionDelegate {
    static let shared = AudioRecognitionEngine()
    
    @Published var recognizedSongTitle: String?
    @Published var recognizedArtist: String?
    @Published var appleMusicURL: URL?
    
    private let session = SHSession()
    private let signatureGenerator = SHSignatureGenerator()
    private var isRecognizing = false
    
    private override init() {
        super.init()
        session.delegate = self
    }
    
    /// Called with audio CMSampleBuffers from an AVPlayer tap or microphone
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard !isRecognizing else { return }
        
        do {
            try signatureGenerator.append(buffer, at: time)
            
            // Generate signature and match
            let signature = signatureGenerator.signature()
            
            // Only try to match once we have a long enough signature (e.g. 5 seconds)
            if signature.duration > 5.0 {
                isRecognizing = true
                session.match(signature)
            }
        } catch {
            print("⚠️ [ShazamKit] Failed to append buffer: \(error)")
        }
    }
    
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        Task { @MainActor in
            if let firstItem = match.mediaItems.first {
                self.recognizedSongTitle = firstItem.title
                self.recognizedArtist = firstItem.artist
                self.appleMusicURL = firstItem.appleMusicURL
                print("🎵 [ShazamKit] Found match: \(firstItem.title ?? "Unknown") by \(firstItem.artist ?? "Unknown")")
            }
            // Reset to allow future matching
            self.isRecognizing = false
        }
    }
    
    nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        Task { @MainActor in
            print("⚠️ [ShazamKit] No match found.")
            self.isRecognizing = false
        }
    }
}
