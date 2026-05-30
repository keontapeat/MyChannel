import UIKit
import AVFoundation

/// Phase 85: Hardware Keyboard & Trackpad Support
/// Handles UIKeyCommand overrides for iPadOS/macOS power users.
@MainActor
final class HardwareKeyboardHandler: UIResponder {
    static let shared = HardwareKeyboardHandler()
    
    private weak var activePlayer: AVPlayer?
    
    // We must return true for canBecomeFirstResponder to receive key commands
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(togglePlayPause), discoverabilityTitle: "Play/Pause"),
            UIKeyCommand(input: "j", modifierFlags: [], action: #selector(skipBackward), discoverabilityTitle: "Skip Back 10s"),
            UIKeyCommand(input: "l", modifierFlags: [], action: #selector(skipForward), discoverabilityTitle: "Skip Forward 10s"),
            UIKeyCommand(input: "k", modifierFlags: [], action: #selector(togglePlayPause), discoverabilityTitle: "Play/Pause (K)"),
            UIKeyCommand(input: "f", modifierFlags: [], action: #selector(toggleFullScreen), discoverabilityTitle: "Full Screen"),
            UIKeyCommand(input: "m", modifierFlags: [], action: #selector(toggleMute), discoverabilityTitle: "Mute/Unmute")
        ]
    }
    
    func attach(to player: AVPlayer) {
        self.activePlayer = player
        self.becomeFirstResponder()
        print("⌨️ [HardwareKeyboard] Attached to player. Ready for commands.")
    }
    
    func detach() {
        self.activePlayer = nil
        self.resignFirstResponder()
    }
    
    @objc private func togglePlayPause() {
        guard let p = activePlayer else { return }
        if p.rate == 0 {
            p.play()
            print("⌨️ [HardwareKeyboard] Play")
        } else {
            p.pause()
            print("⌨️ [HardwareKeyboard] Pause")
        }
    }
    
    @objc private func skipForward() {
        guard let p = activePlayer else { return }
        let newTime = p.currentTime().seconds + 10.0
        p.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        print("⌨️ [HardwareKeyboard] Skip Forward")
    }
    
    @objc private func skipBackward() {
        guard let p = activePlayer else { return }
        let newTime = max(p.currentTime().seconds - 10.0, 0)
        p.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        print("⌨️ [HardwareKeyboard] Skip Backward")
    }
    
    @objc private func toggleMute() {
        guard let p = activePlayer else { return }
        p.isMuted.toggle()
        print("⌨️ [HardwareKeyboard] Mute toggled: \(p.isMuted)")
    }
    
    @objc private func toggleFullScreen() {
        print("⌨️ [HardwareKeyboard] Toggle FullScreen Requested (Needs UI Router hook)")
    }
}
