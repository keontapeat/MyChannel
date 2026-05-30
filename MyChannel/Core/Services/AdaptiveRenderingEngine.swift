import Foundation
import Combine
import QuartzCore

/// Phase 61: Low-Power Mode Adaptive Rendering
/// Monitors Low Power Mode and dynamically drops CADisplayLink framerates to save battery.
@MainActor
final class AdaptiveRenderingEngine: ObservableObject {
    static let shared = AdaptiveRenderingEngine()
    
    @Published var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var cancellables = Set<AnyCancellable>()
    
    private var displayLink: CADisplayLink?
    
    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.isLowPowerModeEnabled = isLowPower
                self?.handlePowerStateChange(isLowPower)
            }
            .store(in: &cancellables)
            
        setupDisplayLink()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
        applyFramerateLimits()
    }
    
    private func handlePowerStateChange(_ isLowPower: Bool) {
        if isLowPower {
            print("🔋 [AdaptiveRendering] Low Power Mode ON. Dropping UI framerates and disabling heavy animations.")
        } else {
            print("⚡️ [AdaptiveRendering] Low Power Mode OFF. Restoring maximum framerates.")
        }
        applyFramerateLimits()
    }
    
    private func applyFramerateLimits() {
        guard let link = displayLink else { return }
        
        if isLowPowerModeEnabled {
            // Cap UI rendering to 30 FPS
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
            } else {
                link.preferredFramesPerSecond = 30
            }
        } else {
            // Uncapped up to 120Hz (ProMotion)
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            } else {
                link.preferredFramesPerSecond = 60
            }
        }
    }
    
    @objc private func tick() {
        // Global hook for custom UI animations that need to respect framerate bounds
    }
}
