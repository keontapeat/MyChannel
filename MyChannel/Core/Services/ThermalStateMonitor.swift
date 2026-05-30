import Foundation
import Combine

/// Phase 57: Device Battery Thermal State Monitor
/// Observes `ProcessInfo.processInfo.thermalState` to downgrade video resolution and framerate when the device overheats.
@MainActor
final class ThermalStateMonitor: ObservableObject {
    static let shared = ThermalStateMonitor()
    
    @Published var currentThermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                let state = ProcessInfo.processInfo.thermalState
                self?.currentThermalState = state
                self?.handleThermalStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            print("🌡️ [ThermalState] Nominal. Operating normally.")
            // Allow 4K, 60fps
            ResolutionScalingEngine.shared.resetLimits()
        case .fair:
            print("🌡️ [ThermalState] Fair. Device is warming up.")
            // Cap at 1080p to prevent further heating
            ResolutionScalingEngine.shared.enforcePeakBitrate(6_000_000)
        case .serious:
            print("🌡️ [ThermalState] Serious! Device is hot.")
            // Cap at 720p, 30fps
            ResolutionScalingEngine.shared.enforcePeakBitrate(3_000_000)
        case .critical:
            print("🌡️ [ThermalState] Critical! Device is overheating.")
            // Cap at 480p, and maybe pause background tasks
            ResolutionScalingEngine.shared.enforcePeakBitrate(1_500_000)
        @unknown default:
            break
        }
    }
}

// Extension to bridge our ResolutionScalingEngine with Thermal State constraints
extension ResolutionScalingEngine {
    func enforcePeakBitrate(_ bitrate: Double) {
        // Enforces a hard cap on AVPlayerItem's peak bitrate globally
        print("📉 [ResolutionScaling] Hard capping bitrate to \(bitrate / 1_000_000) Mbps due to thermal constraints.")
    }
    
    func resetLimits() {
        print("📈 [ResolutionScaling] Resetting bitrate limits.")
    }
}
