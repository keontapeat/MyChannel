//
//  EdgePersonalizationService.swift
//  MyChannel
//
//  Phase 3.2: Edge Functions for sub-50ms personalization.
//  Runs personalization at CDN edge (Cloudflare Workers) instead of origin.
//  Falls back to Cloud Run when edge is unavailable.
//

import Foundation
import Combine

// MARK: - Models

struct EdgePersonalization: Codable {
    let userId: String
    let personalizedFeed: [EdgeFeedItem]
    let personalizedRecommendations: [EdgeFeedItem]
    let region: String
    let edgeLocation: String
    let latencyMs: Int
    let computedAt: Date
}

struct EdgeFeedItem: Codable, Identifiable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let creatorName: String
    let viewCount: Int
    let duration: Double
    let relevanceScore: Double
    let reason: String // "trending_in_region", "similar_to_watched", "subscription", etc.
}

struct EdgeABTest: Codable {
    let experimentId: String
    let variant: String
    let config: [String: String]
}

struct EdgeFeatureFlags: Codable {
    let flags: [String: Bool]
    let region: String
    let fetchedAt: Date
}

// MARK: - Edge Personalization Service

@MainActor
final class EdgePersonalizationService: ObservableObject {
    static let shared = EdgePersonalizationService()
    
    @Published var personalization: EdgePersonalization?
    @Published var currentABTests: [String: EdgeABTest] = [:]
    @Published var edgeFeatureFlags: EdgeFeatureFlags?
    @Published var isEdgeAvailable = false
    
    private let redisCache = RedisCacheService.shared
    
    // Edge endpoints (Cloudflare Workers)
    private let edgeBaseURL = "https://edge.mychannel.app"
    private let fallbackCloudRun = CloudRunService.myChannelAI
    
    private init() {
        checkEdgeAvailability()
    }
    
    // MARK: - 🔥 EDGE PERSONALIZED FEED (<50ms)
    
    func getPersonalizedFeed(userId: String, limit: Int = 20) async throws -> EdgePersonalization {
        // Check Redis cache first (1ms)
        if let cached: EdgePersonalization = await redisCache.get("edge:feed:\(userId)", type: EdgePersonalization.self) {
            self.personalization = cached
            return cached
        }
        
        if isEdgeAvailable {
            // 🔥 EDGE PATH: Sub-50ms via Cloudflare Workers
            let result: EdgePersonalization? = await fetchFromEdge(path: "/feed", userId: userId, params: ["limit": String(limit)])
            if let result = result {
                await redisCache.set("edge:feed:\(userId)", value: result, ttl: 120) // 2 min
                self.personalization = result
                return result
            }
        }
        
        // Fallback: Cloud Run origin (~200ms)
        return try await fetchFromOrigin(userId: userId, limit: limit)
    }
    
    // MARK: - 🧪 EDGE A/B TESTING
    
    func getABTestVariant(experimentId: String, userId: String) async throws -> EdgeABTest {
        // Check local cache
        if let cached = currentABTests[experimentId] { return cached }
        
        if isEdgeAvailable {
            let result: EdgeABTest? = await fetchFromEdge(path: "/ab-test", userId: userId, params: ["experimentId": experimentId])
            if let result = result {
                currentABTests[experimentId] = result
                return result
            }
        }
        
        // Fallback: Cloud Run
        struct Request: Encodable { let task: String; let experimentId: String; let userId: String }
        struct Response: Decodable { let experimentId: String?; let variant: String?; let config: [String: String]? }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelAI, path: "/predict",
            body: Request(task: "ab_test_variant", experimentId: experimentId, userId: userId)
        )
        
        let test = EdgeABTest(
            experimentId: r.experimentId ?? experimentId,
            variant: r.variant ?? "control",
            config: r.config ?? [:]
        )
        currentABTests[experimentId] = test
        return test
    }
    
    // MARK: - 🚩 EDGE FEATURE FLAGS
    
    func getFeatureFlags(userId: String) async throws -> EdgeFeatureFlags {
        // Redis cache for feature flags (1ms)
        if let cached: EdgeFeatureFlags = await redisCache.get("edge:flags:\(userId)", type: EdgeFeatureFlags.self) {
            self.edgeFeatureFlags = cached
            return cached
        }
        
        if isEdgeAvailable {
            let result: EdgeFeatureFlags? = await fetchFromEdge(path: "/flags", userId: userId, params: [:])
            if let result = result {
                await redisCache.set("edge:flags:\(userId)", value: result, ttl: 300) // 5 min
                self.edgeFeatureFlags = result
                return result
            }
        }
        
        // Fallback: use local AppConfig
        return EdgeFeatureFlags(
            flags: [
                "enableFlicks": AppConfig.Features.enableFlicks,
                "enableLiveStreaming": AppConfig.Features.enableLiveStreaming,
                "enableAds": AppConfig.Features.enableAds,
                "enableOfflineDownload": AppConfig.Features.enableOfflineDownload
            ],
            region: "local",
            fetchedAt: Date()
        )
    }
    
    // MARK: - 🔧 EDGE INFRASTRUCTURE
    
    private func checkEdgeAvailability() {
        Task {
            let url = URL(string: "\(edgeBaseURL)/health")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                isEdgeAvailable = (response as? HTTPURLResponse)?.statusCode == 200
                print("🌐 [Edge] Availability: \(isEdgeAvailable ? "✅ Online" : "❌ Offline")")
            } catch {
                isEdgeAvailable = false
                print("🌐 [Edge] Unavailable: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchFromEdge<T: Decodable>(path: String, userId: String, params: [String: String]) async -> T? {
        var components = URLComponents(string: "\(edgeBaseURL)\(path)")!
        var queryItems = [URLQueryItem(name: "userId", value: userId)]
        queryItems += params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = queryItems
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2 // 🔥 2s edge timeout (should be <50ms)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(T.self, from: data)
            print("🌐 [Edge] Fetched \(path) in \(latency)ms")
            return result
        } catch {
            print("🌐 [Edge] Failed: \(error.localizedDescription)")
            isEdgeAvailable = false
            return nil
        }
    }
    
    private func fetchFromOrigin(userId: String, limit: Int) async throws -> EdgePersonalization {
        struct Request: Encodable { let task: String; let userId: String; let limit: Int }
        struct RawItem: Decodable {
            let videoId: String?; let title: String?; let thumbnailUrl: String?
            let creatorName: String?; let viewCount: Int?; let duration: Double?
            let relevanceScore: Double?; let reason: String?
        }
        struct Response: Decodable {
            let feed: [RawItem]?; let recommendations: [RawItem]?
            let region: String?; let edgeLocation: String?
        }
        
        let r: Response = try await CloudRunAgentRouter.post(
            .myChannelAI, path: "/predict",
            body: Request(task: "personalized_feed", userId: userId, limit: limit)
        )
        
        let feedItems = (r.feed ?? []).compactMap { raw -> EdgeFeedItem? in
            guard let vid = raw.videoId, let title = raw.title else { return nil }
            return EdgeFeedItem(
                id: vid, videoId: vid, title: title,
                thumbnailUrl: raw.thumbnailUrl ?? "",
                creatorName: raw.creatorName ?? "",
                viewCount: raw.viewCount ?? 0,
                duration: raw.duration ?? 0,
                relevanceScore: raw.relevanceScore ?? 0,
                reason: raw.reason ?? "recommended"
            )
        }
        
        let recItems = (r.recommendations ?? []).compactMap { raw -> EdgeFeedItem? in
            guard let vid = raw.videoId, let title = raw.title else { return nil }
            return EdgeFeedItem(
                id: vid, videoId: vid, title: title,
                thumbnailUrl: raw.thumbnailUrl ?? "",
                creatorName: raw.creatorName ?? "",
                viewCount: raw.viewCount ?? 0,
                duration: raw.duration ?? 0,
                relevanceScore: raw.relevanceScore ?? 0,
                reason: raw.reason ?? "recommended"
            )
        }
        
        let result = EdgePersonalization(
            userId: userId,
            personalizedFeed: feedItems,
            personalizedRecommendations: recItems,
            region: r.region ?? "us-central1",
            edgeLocation: r.edgeLocation ?? "cloud_run",
            latencyMs: 200, // Origin is ~200ms
            computedAt: Date()
        )
        
        await redisCache.set("edge:feed:\(userId)", value: result, ttl: 120)
        self.personalization = result
        return result
    }
}
