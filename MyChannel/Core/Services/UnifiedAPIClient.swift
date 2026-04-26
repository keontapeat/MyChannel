//
//  UnifiedAPIClient.swift
//  MyChannel
//
//  Phase 3.3: Unified API Client — single entry point for all API calls.
//  Centralizes auth, retry, caching, logging, and routing.
//  Replaces scattered direct CloudRunAgentRouter calls with consistent patterns.
//

import Foundation
import Combine

// MARK: - API Client Configuration

struct APIClientConfig {
    let baseURL: String
    let timeout: TimeInterval
    let retryCount: Int
    let retryDelay: TimeInterval
    let cachePolicy: CachePolicy
    let authRequired: Bool
    
    enum CachePolicy {
        case networkOnly          // Always fetch from network
        case cacheFirst          // Check cache, fall back to network
        case networkFirst        // Try network, fall back to cache
        case staleWhileRevalidate // Return cache, refresh in background
    }
    
    static let `default` = APIClientConfig(
        baseURL: AppConfig.API.cloudRunBaseURL,
        timeout: 15,
        retryCount: 3,
        retryDelay: 1.0,
        cachePolicy: .cacheFirst,
        authRequired: false
    )
    
    static let authenticated = APIClientConfig(
        baseURL: AppConfig.API.cloudRunBaseURL,
        timeout: 15,
        retryCount: 3,
        retryDelay: 1.0,
        cachePolicy: .cacheFirst,
        authRequired: true
    )
    
    static let realtime = APIClientConfig(
        baseURL: AppConfig.API.cloudRunBaseURL,
        timeout: 5,
        retryCount: 1,
        retryDelay: 0.5,
        cachePolicy: .networkOnly,
        authRequired: false
    )
}

// MARK: - API Response

struct UnifiedAPIResponse<T: Codable> {
    let data: T
    let fromCache: Bool
    let latencyMs: Int
    let statusCode: Int
    let timestamp: Date
}

// MARK: - API Error

enum UnifiedAPIError: LocalizedError {
    case networkUnavailable
    case timeout
    case unauthorized
    case notFound(String)
    case serverError(Int, String)
    case decodingError(String)
    case rateLimited(retryAfter: TimeInterval?)
    case cacheMiss
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "Network unavailable"
        case .timeout: return "Request timed out"
        case .unauthorized: return "Authentication required"
        case .notFound(let resource): return "Not found: \(resource)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .rateLimited(let retryAfter): return "Rate limited, retry after \(retryAfter ?? 60)s"
        case .cacheMiss: return "Cache miss"
        }
    }
}

// MARK: - Unified API Client

@MainActor
final class UnifiedAPIClient {
    static let shared = UnifiedAPIClient()
    
    private let redisCache = RedisCacheService.shared
    private let session: URLSession
    
    // Request metrics
    private var requestCount: Int = 0
    private var cacheHitCount: Int = 0
    private var errorCount: Int = 0
    private var totalLatencyMs: Int = 0
    
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 20
        config.timeoutIntervalForRequest = 15
        config.httpShouldUsePipelining = true
        session = URLSession(configuration: config)
    }
    
    // MARK: - 🔥 PRIMARY REQUEST METHOD
    
    func request<T: Codable>(
        _ service: CloudRunService,
        path: String = "/predict",
        body: Encodable,
        config: APIClientConfig = .default,
        cacheKey: String? = nil,
        cacheTTL: TimeInterval = 300
    ) async throws -> UnifiedAPIResponse<T> {
        let startTime = Date()
        requestCount += 1
        
        let effectiveCacheKey = cacheKey ?? "api:\(service.rawValue):\(path)"
        
        // 🔥 CACHE POLICY: Check cache first if configured
        switch config.cachePolicy {
        case .cacheFirst:
            if let cached: T = await redisCache.get(effectiveCacheKey, type: T.self) {
                cacheHitCount += 1
                return UnifiedAPIResponse(data: cached, fromCache: true, latencyMs: 1, statusCode: 200, timestamp: Date())
            }
        case .networkFirst:
            break // Try network first
        case .staleWhileRevalidate:
            if let cached: T = await redisCache.get(effectiveCacheKey, type: T.self) {
                cacheHitCount += 1
                // Return cached immediately, refresh in background
                Task { [weak self] in
                    let _: UnifiedAPIResponse<T>? = try? await self?.executeNetworkRequest(service, path: path, body: body, config: config, cacheKey: effectiveCacheKey, cacheTTL: cacheTTL)
                }
                return UnifiedAPIResponse(data: cached, fromCache: true, latencyMs: 1, statusCode: 200, timestamp: Date())
            }
        case .networkOnly:
            break // Always go to network
        }
        
        // Execute with retry logic
        var lastError: Error?
        for attempt in 0..<config.retryCount {
            do {
                let result: UnifiedAPIResponse<T> = try await executeNetworkRequest(
                    service, path: path, body: body, config: config,
                    cacheKey: effectiveCacheKey, cacheTTL: cacheTTL
                )
                let totalLatency = Int(Date().timeIntervalSince(startTime) * 1000)
                totalLatencyMs += totalLatency
                return UnifiedAPIResponse(data: result.data, fromCache: false, latencyMs: totalLatency, statusCode: result.statusCode, timestamp: Date())
            } catch {
                lastError = error
                if attempt < config.retryCount - 1 {
                    let delay = config.retryDelay * Double(attempt + 1) // Exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        errorCount += 1
        
        // 🔥 FALLBACK: Try cache on error
        if config.cachePolicy != .networkOnly,
           let cached: T = await redisCache.get(effectiveCacheKey, type: T.self) {
            print("⚠️ [API] Network failed, returning stale cache for: \(effectiveCacheKey)")
            return UnifiedAPIResponse(data: cached, fromCache: true, latencyMs: 0, statusCode: 200, timestamp: Date())
        }
        
        throw lastError ?? UnifiedAPIError.networkUnavailable
    }
    
    // MARK: - 🔥 BATCH REQUEST (Multiple services in parallel)
    
    func batchRequest<T1: Codable, T2: Codable>(
        _ request1: BatchRequestItem<T1>,
        _ request2: BatchRequestItem<T2>
    ) async throws -> (UnifiedAPIResponse<T1>, UnifiedAPIResponse<T2>) {
        async let r1: UnifiedAPIResponse<T1> = request(request1.service, path: request1.path, body: request1.body, config: request1.config, cacheKey: request1.cacheKey, cacheTTL: request1.cacheTTL)
        async let r2: UnifiedAPIResponse<T2> = request(request2.service, path: request2.path, body: request2.body, config: request2.config, cacheKey: request2.cacheKey, cacheTTL: request2.cacheTTL)
        return try await (r1, r2)
    }
    
    struct BatchRequestItem<T: Codable> {
        let service: CloudRunService
        let path: String
        let body: Encodable
        let config: APIClientConfig
        let cacheKey: String?
        let cacheTTL: TimeInterval
        
        init(service: CloudRunService, path: String = "/predict", body: Encodable, config: APIClientConfig = .default, cacheKey: String? = nil, cacheTTL: TimeInterval = 300) {
            self.service = service; self.path = path; self.body = body; self.config = config; self.cacheKey = cacheKey; self.cacheTTL = cacheTTL
        }
    }
    
    // MARK: - 📊 CLIENT METRICS
    
    struct ClientMetrics {
        let totalRequests: Int
        let cacheHitRate: Double
        let errorRate: Double
        let avgLatencyMs: Int
    }
    
    func getMetrics() -> ClientMetrics {
        let hitRate = requestCount > 0 ? Double(cacheHitCount) / Double(requestCount) : 0
        let errRate = requestCount > 0 ? Double(errorCount) / Double(requestCount) : 0
        let avgLatency = requestCount > 0 ? totalLatencyMs / requestCount : 0
        return ClientMetrics(totalRequests: requestCount, cacheHitRate: hitRate, errorRate: errRate, avgLatencyMs: avgLatency)
    }
    
    func resetMetrics() {
        requestCount = 0; cacheHitCount = 0; errorCount = 0; totalLatencyMs = 0
    }
    
    // MARK: - 🔧 PRIVATE
    
    private func executeNetworkRequest<T: Codable>(
        _ service: CloudRunService,
        path: String,
        body: Encodable,
        config: APIClientConfig,
        cacheKey: String,
        cacheTTL: TimeInterval
    ) async throws -> UnifiedAPIResponse<T> {
        let result: T = try await CloudRunAgentRouter.post(service, path: path, body: body, timeout: config.timeout)
        
        // Cache the result
        await redisCache.set(cacheKey, value: result, ttl: cacheTTL)
        
        return UnifiedAPIResponse(data: result, fromCache: false, latencyMs: 0, statusCode: 200, timestamp: Date())
    }
}
