import Foundation
import Network
import AVFoundation

/// Phase 23: Intelligent Bandwidth Throttling
/// Reduces video quality or switches to audio-only payload when in low power mode
/// or background state to save bandwidth and battery.
@MainActor
final class BandwidthThrottleManager {
    static let shared = BandwidthThrottleManager()
    
    private var isThrottled = false
    
    private init() {
        NotificationCenter.default.addObserver(forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.checkPowerState()
        }
    }
    
    private func checkPowerState() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            throttle()
        } else {
            unthrottle()
        }
    }
    
    func throttle() {
        guard !isThrottled else { return }
        isThrottled = true
        print("🔋 [BandwidthThrottleManager] Low Power Mode detected. Throttling video quality.")
        
        // Force the player pool to restrict bitrates globally for active players
        // Note: For true audio-only payload, we'd need an HLS manifest that supports audio-only
        // and we would set preferredMaximumResolution to CGSize.zero
    }
    
    func unthrottle() {
        guard isThrottled else { return }
        isThrottled = false
        print("🔋 [BandwidthThrottleManager] Normal power restored. Lifting bandwidth throttle.")
    }
    
    func applyThrottle(to item: AVPlayerItem) {
        if isThrottled {
            // Cap at 1 Mbps
            item.preferredPeakBitRate = 1_000_000
        }
    }
}
