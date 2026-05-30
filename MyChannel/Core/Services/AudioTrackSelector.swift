import Foundation
import AVFoundation

/// Phase 59: Multi-track Audio Language Selector
/// Intercepts AVMediaSelectionGroup to list available audio tracks and swap spoken languages.
@MainActor
final class AudioTrackSelector: ObservableObject {
    static let shared = AudioTrackSelector()
    
    @Published var availableAudioTracks: [AVMediaSelectionOption] = []
    @Published var selectedTrack: AVMediaSelectionOption?
    
    private weak var currentItem: AVPlayerItem?
    
    private init() {}
    
    /// Parses the AVPlayerItem for available audio languages
    func loadAudioOptions(for item: AVPlayerItem) async {
        self.currentItem = item
        
        guard let asset = item.asset as? AVURLAsset else { return }
        
        do {
            if let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) {
                self.availableAudioTracks = audioGroup.options
                
                // Get currently selected
                if let currentSelection = item.currentMediaSelection.selectedMediaOption(in: audioGroup) {
                    self.selectedTrack = currentSelection
                } else {
                    self.selectedTrack = audioGroup.defaultOption
                }
                
                print("🗣️ [AudioTrackSelector] Found \(audioGroup.options.count) audio tracks.")
            }
        } catch {
            print("⚠️ [AudioTrackSelector] Failed to load audio options: \(error)")
        }
    }
    
    /// Hot-swaps the audio language during playback
    func selectTrack(_ option: AVMediaSelectionOption) async {
        guard let item = currentItem, let asset = item.asset as? AVURLAsset else { return }
        
        do {
            if let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) {
                item.select(option, in: audioGroup)
                self.selectedTrack = option
                print("🗣️ [AudioTrackSelector] Switched to audio track: \(option.displayName)")
            }
        } catch {
            print("⚠️ [AudioTrackSelector] Failed to select audio track: \(error)")
        }
    }
}
