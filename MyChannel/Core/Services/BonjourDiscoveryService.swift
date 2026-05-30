import Foundation

/// Phase 71: Zero-Configuration Network Service Discovery
/// Uses NetServiceBrowser (Bonjour) to discover local smart TVs or casting devices.
@MainActor
final class BonjourDiscoveryService: NSObject, ObservableObject {
    static let shared = BonjourDiscoveryService()
    
    @Published var discoveredDevices: [NetService] = []
    
    private var serviceBrowser: NetServiceBrowser
    private let serviceType = "_mychannel-cast._tcp."
    private let domain = "local."
    
    private override init() {
        self.serviceBrowser = NetServiceBrowser()
        super.init()
        self.serviceBrowser.delegate = self
    }
    
    func startScanning() {
        discoveredDevices.removeAll()
        serviceBrowser.searchForServices(ofType: serviceType, inDomain: domain)
        print("🔍 [Bonjour] Scanning for local casting devices...")
    }
    
    func stopScanning() {
        serviceBrowser.stop()
        print("🛑 [Bonjour] Stopped scanning.")
    }
    
    func cast(videoURL: String, to device: NetService) {
        guard let hostName = device.hostName else { return }
        let port = device.port
        
        // Simulating a network POST request to the discovered IP/Port
        print("📺 [Bonjour] Casting video to \(device.name) at \(hostName):\(port)")
        
        // In a real FAANG app, we'd open a URLSession data task to the discovered IP.
        let targetURLString = "http://\(hostName):\(port)/cast"
        guard let url = URL(string: targetURLString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(["videoURL": videoURL])
        
        Task.detached {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    print("✅ [Bonjour] Successfully beamed video to TV.")
                }
            } catch {
                print("⚠️ [Bonjour] Casting failed: \(error)")
            }
        }
    }
}

extension BonjourDiscoveryService: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            // Resolve the service to get IP/Port
            service.delegate = self
            service.resolve(withTimeout: 5.0)
            self.discoveredDevices.append(service)
            print("📺 [Bonjour] Found device: \(service.name)")
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            self.discoveredDevices.removeAll { $0 == service }
            print("📺 [Bonjour] Lost device: \(service.name)")
        }
    }
}

extension BonjourDiscoveryService: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        print("📍 [Bonjour] Resolved address for: \(sender.name) (Port: \(sender.port))")
    }
}
