//
//  EdgeFunctionsService.swift
//  MyChannel
//
//  🌐 EDGE FUNCTIONS - CLOUDFLARE WORKERS!
//  Run code in user's city (<10ms latency)
//  FREE: 100K requests/day! ⚡
//

import Foundation

class EdgeFunctionsService {
    static let shared = EdgeFunctionsService()
    
    private let cloudflareAccountId = "YOUR_ACCOUNT_ID"
    private let apiToken = "YOUR_API_TOKEN"
    
    private init() {}
    
    /// Execute function at the edge
    func execute(function: EdgeFunction, params: [String: String]) async throws -> EdgeResponse {
        print("🌐 [Edge] Executing: \(function.rawValue)")
        
        // Call Cloudflare Worker
        let url = URL(string: "https://mychannel.workers.dev/\(function.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(params)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        // Note: POST requests are not cached, but NetworkOptimizer handles deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        let response = try JSONDecoder().decode(EdgeResponse.self, from: data)
        
        return response
    }
    
    enum EdgeFunction: String {
        case botDetection = "bot-detection"
        case geoRouting = "geo-routing"
        case rateLimit = "rate-limit"
        case auth = "auth"
    }
}

struct EdgeResponse: Codable {
    let success: Bool
    let data: [String: String]
    let latency: Double
}



