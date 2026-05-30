import Foundation

/// Phase 47: Edge Caching & CDN Routing Node
/// Builds a smart routing engine that selects the lowest latency video URL.
final class CDNRouter {
    static let shared = CDNRouter()
    
    // In a real scenario, these would be fetched dynamically from a backend DNS
    private let edgeNodes = [
        "https://us-east.cdn.mychannel.app",
        "https://us-west.cdn.mychannel.app",
        "https://eu-central.cdn.mychannel.app",
        "https://ap-northeast.cdn.mychannel.app"
    ]
    
    private var optimalNodeCache: String?
    
    private init() {}
    
    /// Rewrites the given URL to use the fastest edge node
    func route(videoURL: String) async -> URL? {
        guard let url = URL(string: videoURL) else { return nil }
        
        // Only route if it's our own domain
        guard url.host?.contains("mychannel") == true else { return url }
        
        let node = await getOptimalNode()
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = URL(string: node)?.host
        
        return components?.url ?? url
    }
    
    private func getOptimalNode() async -> String {
        if let cached = optimalNodeCache {
            return cached
        }
        
        // Simulating ping tests across all edge nodes
        print("🌍 [CDNRouter] Testing edge node latencies...")
        
        let bestNode = await withTaskGroup(of: (String, TimeInterval).self) { group in
            for node in edgeNodes {
                group.addTask {
                    let latency = await self.ping(node: node)
                    return (node, latency)
                }
            }
            
            var lowestLatency: TimeInterval = .greatestFiniteMagnitude
            var winner: String = self.edgeNodes[0]
            
            for await result in group {
                if result.1 < lowestLatency {
                    lowestLatency = result.1
                    winner = result.0
                }
            }
            
            return winner
        }
        
        print("🚀 [CDNRouter] Selected optimal node: \(bestNode)")
        optimalNodeCache = bestNode
        return bestNode
    }
    
    private func ping(node: String) async -> TimeInterval {
        // [SIMULATION] Random latency between 10ms and 150ms
        let latency = Double.random(in: 0.01...0.15)
        try? await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        return latency
    }
}
