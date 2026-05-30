import Foundation
import Network
import AVFoundation

/// Phase 62: Network Reachability & Bandwidth Estimator
/// Uses NWPathMonitor to detect connection changes and AVPlayerItemAccessLog to estimate real-world download bandwidth.
@MainActor
final class NetworkBandwidthEstimator: ObservableObject {
    static let shared = NetworkBandwidthEstimator()
    
    @Published var isConnected: Bool = true
    @Published var isCellular: Bool = false
    @Published var estimatedBandwidthMbps: Double = -1 // -1 means unknown
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mychannel.network.monitor")
    
    private var accessLogObserver: NSObjectProtocol?
    
    private init() {
        startMonitoringPath()
    }
    
    private func startMonitoringPath() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.usesInterfaceType(.cellular)
                
                if path.status == .satisfied {
                    print("🌐 [NetworkMonitor] Connected via \(path.usesInterfaceType(.cellular) ? "Cellular" : "WiFi/Ethernet").")
                } else {
                    print("⚠️ [NetworkMonitor] Connection lost.")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    /// Attach to an AVPlayerItem to track true throughput from access logs
    func attach(to item: AVPlayerItem) {
        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self] notification in
            self?.parseAccessLog(from: item)
        }
    }
    
    func detach() {
        if let obs = accessLogObserver {
            NotificationCenter.default.removeObserver(obs)
            accessLogObserver = nil
        }
    }
    
    private func parseAccessLog(from item: AVPlayerItem) {
        guard let accessLog = item.accessLog(), let lastEvent = accessLog.events.last else { return }
        
        // observedBitrate is in bits per second
        let bps = lastEvent.observedBitrate
        guard bps > 0 else { return }
        
        let mbps = bps / 1_000_000
        self.estimatedBandwidthMbps = mbps
        
        // E.g., dynamically adjust our resolution scaler
        ResolutionScalingEngine.shared.enforcePeakBitrate(bps)
        
        print("📶 [NetworkMonitor] Estimated bandwidth: \(String(format: "%.2f", mbps)) Mbps")
    }
}
