//
//  LoadBalancerService.swift
//  MyChannel
//
//  ⚖️ LOAD BALANCER - INTELLIGENT REQUEST ROUTING!
//  Distributes load across servers for optimal performance
//  Google Cloud Load Balancing + custom algorithms 🔥
//

import Foundation

class LoadBalancerService {
    static let shared = LoadBalancerService()
    
    private var servers: [Server] = []
    private var requestCounts: [String: Int] = [:]
    private var roundRobinIndex: Int = 0
    private let healthCheckInterval: TimeInterval = 30
    private var healthCheckTimer: Timer?
    
    private init() {
        initializeServers()
        startHealthChecks()
    }
    
    // MARK: - 🚀 ROUTING
    
    /// Route request to optimal server based on strategy
    func route(request: Request, strategy: RoutingStrategy = .leastConnections) -> Server {
        let availableServers = servers.filter { $0.isHealthy && !$0.isOverloaded }
        
        guard !availableServers.isEmpty else {
            // Fallback to any server if all are unavailable
            print("⚠️ [LoadBalancer] All servers busy, using fallback")
            return servers.first ?? Server.default
        }
        
        let selectedServer: Server
        
        switch strategy {
        case .roundRobin:
            selectedServer = roundRobinRouting(servers: availableServers)
            
        case .leastConnections:
            selectedServer = leastConnectionsRouting(servers: availableServers)
            
        case .weightedRoundRobin:
            selectedServer = weightedRoundRobinRouting(servers: availableServers)
            
        case .ipHash:
            selectedServer = ipHashRouting(servers: availableServers, clientIP: request.clientIP)
            
        case .leastResponseTime:
            selectedServer = leastResponseTimeRouting(servers: availableServers)
        }
        
        // Update metrics
        requestCounts[selectedServer.id, default: 0] += 1
        
        print("📍 [LoadBalancer] Routed to \(selectedServer.id) (Load: \(Int(selectedServer.load * 100))%)")
        
        return selectedServer
    }
    
    // MARK: - 📊 ROUTING STRATEGIES
    
    enum RoutingStrategy {
        case roundRobin          // Simple rotation
        case leastConnections    // Route to server with fewest connections
        case weightedRoundRobin  // Consider server capacity
        case ipHash              // Sticky sessions based on IP
        case leastResponseTime   // Route to fastest server
    }
    
    /// Round Robin: Simple rotation through servers
    private func roundRobinRouting(servers: [Server]) -> Server {
        guard !servers.isEmpty else { return Server.default }
        
        let server = servers[roundRobinIndex % servers.count]
        roundRobinIndex += 1
        
        return server
    }
    
    /// Least Connections: Route to server with fewest active connections
    private func leastConnectionsRouting(servers: [Server]) -> Server {
        return servers.min(by: { $0.activeConnections < $1.activeConnections }) ?? Server.default
    }
    
    /// Weighted Round Robin: Consider server capacity
    private func weightedRoundRobinRouting(servers: [Server]) -> Server {
        let weightedServers = servers.flatMap { server in
            Array(repeating: server, count: server.weight)
        }
        
        guard !weightedServers.isEmpty else { return Server.default }
        
        let server = weightedServers[roundRobinIndex % weightedServers.count]
        roundRobinIndex += 1
        
        return server
    }
    
    /// IP Hash: Sticky sessions - same client always goes to same server
    private func ipHashRouting(servers: [Server], clientIP: String) -> Server {
        let hash = abs(clientIP.hashValue)
        let index = hash % servers.count
        
        return servers[index]
    }
    
    /// Least Response Time: Route to server with lowest latency
    private func leastResponseTimeRouting(servers: [Server]) -> Server {
        return servers.min(by: { $0.averageResponseTime < $1.averageResponseTime }) ?? Server.default
    }
    
    // MARK: - 🏥 HEALTH CHECKS
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performHealthChecks()
        }
    }
    
    private func performHealthChecks() {
        for i in 0..<servers.count {
            Task {
                let isHealthy = await checkServerHealth(servers[i])
                servers[i].isHealthy = isHealthy
                
                if !isHealthy {
                    print("🚨 [LoadBalancer] Server \(servers[i].id) is unhealthy!")
                }
            }
        }
    }
    
    private func checkServerHealth(_ server: Server) async -> Bool {
        // Simulate health check (ping server endpoint)
        do {
            let url = URL(string: "\(server.endpoint)/health")!
            let (_, response) = try await URLSession.configured.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ [LoadBalancer] Health check failed for \(server.id): \(error)")
        }
        
        return false
    }
    
    // MARK: - 📈 METRICS
    
    func updateServerLoad(_ serverId: String, load: Double) {
        if let index = servers.firstIndex(where: { $0.id == serverId }) {
            servers[index].load = load
        }
    }
    
    func updateServerConnections(_ serverId: String, connections: Int) {
        if let index = servers.firstIndex(where: { $0.id == serverId }) {
            servers[index].activeConnections = connections
        }
    }
    
    func updateServerResponseTime(_ serverId: String, responseTime: TimeInterval) {
        if let index = servers.firstIndex(where: { $0.id == serverId }) {
            servers[index].averageResponseTime = responseTime
        }
    }
    
    /// Get load balancer statistics
    func getStatistics() -> LoadBalancerStatistics {
        let totalRequests = requestCounts.values.reduce(0, +)
        let healthyServers = servers.filter { $0.isHealthy }.count
        let averageLoad = servers.map { $0.load }.reduce(0, +) / Double(servers.count)
        let totalConnections = servers.map { $0.activeConnections }.reduce(0, +)
        
        return LoadBalancerStatistics(
            totalServers: servers.count,
            healthyServers: healthyServers,
            totalRequests: totalRequests,
            averageLoad: averageLoad,
            totalConnections: totalConnections,
            requestDistribution: requestCounts
        )
    }
    
    struct LoadBalancerStatistics {
        let totalServers: Int
        let healthyServers: Int
        let totalRequests: Int
        let averageLoad: Double
        let totalConnections: Int
        let requestDistribution: [String: Int]
    }
    
    // MARK: - 🔧 SERVER MANAGEMENT
    
    func addServer(_ server: Server) {
        servers.append(server)
        print("➕ [LoadBalancer] Added server: \(server.id)")
    }
    
    func removeServer(serverId: String) {
        servers.removeAll { $0.id == serverId }
        print("➖ [LoadBalancer] Removed server: \(serverId)")
    }
    
    private func initializeServers() {
        // Initialize default server pool
        servers = [
            Server(
                id: "server-1",
                endpoint: "https://api1.mychannel.app",
                region: "us-central1",
                weight: 10
            ),
            Server(
                id: "server-2",
                endpoint: "https://api2.mychannel.app",
                region: "us-east1",
                weight: 10
            ),
            Server(
                id: "server-3",
                endpoint: "https://api3.mychannel.app",
                region: "europe-west1",
                weight: 8
            )
        ]
    }
    
    // MARK: - 🧹 CLEANUP
    
    deinit {
        healthCheckTimer?.invalidate()
    }
}

// MARK: - 📊 DATA STRUCTURES

struct Request {
    let path: String
    let method: HTTPMethod
    let clientIP: String
    let headers: [String: String]
    let timestamp: Date
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
    
    static func example() -> Request {
        return Request(
            path: "/api/videos",
            method: .get,
            clientIP: "192.168.1.1",
            headers: [:],
            timestamp: Date()
        )
    }
}

struct Server {
    let id: String
    let endpoint: String
    let region: String
    var weight: Int
    var load: Double = 0.0
    var activeConnections: Int = 0
    var averageResponseTime: TimeInterval = 0.1
    var isHealthy: Bool = true
    
    var isOverloaded: Bool {
        return load > 0.9 || activeConnections > 1000
    }
    
    static let `default` = Server(
        id: "default",
        endpoint: "https://api.mychannel.app",
        region: "us-central1",
        weight: 10
    )
}

// MARK: - 📱 USAGE EXAMPLES

/*
 
 ⚖️ LOAD BALANCER USAGE:
 
 let lb = LoadBalancerService.shared
 
 // Create request
 let request = Request(
     path: "/api/videos",
     method: .get,
     clientIP: "192.168.1.100",
     headers: ["User-Agent": "MyChannel/1.0"],
     timestamp: Date()
 )
 
 // Route with different strategies
 let server1 = lb.route(request: request, strategy: .roundRobin)
 let server2 = lb.route(request: request, strategy: .leastConnections)
 let server3 = lb.route(request: request, strategy: .ipHash)
 
 // Update server metrics
 lb.updateServerLoad("server-1", load: 0.75)
 lb.updateServerConnections("server-1", connections: 250)
 lb.updateServerResponseTime("server-1", responseTime: 0.05)
 
 // Get statistics
 let stats = lb.getStatistics()
 print("📊 \(stats.healthyServers)/\(stats.totalServers) servers healthy")
 print("📊 \(stats.totalRequests) total requests")
 print("📊 \(Int(stats.averageLoad * 100))% average load")
 
 🎯 BENEFITS:
 - Distributes traffic evenly
 - Automatic failover
 - Health monitoring
 - Multiple routing strategies
 - Scales to millions of requests
 
 */
