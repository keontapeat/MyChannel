import Foundation
import AVKit

/// Premium Feature Manager
/// Handles PiP and Background Audio gated behind MyChannel Plus+
@MainActor
final class PremiumFeatureService: ObservableObject {
    static let shared = PremiumFeatureService()
    
    @Published var isPiPEnabled: Bool = false
    @Published var isBackgroundAudioEnabled: Bool = false
    
    private init() {}
    
    func configurePremiumPlayback(for player: AVPlayer, isPremiumUser: Bool) {
        if isPremiumUser {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                self.isBackgroundAudioEnabled = true
                self.isPiPEnabled = true
                print("💎 [Premium] Background Audio & PiP Unlocked")
            } catch {
                print("⚠️ [Premium] Failed to set audio session: \(error)")
            }
        } else {
            self.isBackgroundAudioEnabled = false
            self.isPiPEnabled = false
        }
    }
}
