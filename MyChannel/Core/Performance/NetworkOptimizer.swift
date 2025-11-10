//
//  NetworkOptimizer.swift
//  MyChannel
//
//  Network performance optimization and request management
//

import Foundation
import Network
import Combine
import SwiftUI
import UIKit

// MARK: - Network Optimizer
class NetworkOptimizer: ObservableObject {
    static let shared = NetworkOptimizer()
    
    @Published var connectionQuality: ConnectionQuality = .excellent
    @Published var isOnline = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Request optimization
    private let requestQueue = OperationQueue()
    private var pendingRequests: [String: URLSessionDataTask] = [:]
    
    // Caching
    private let urlCache: URLCache
    private let imageRequestCache = NSCache<NSString, CachedResponse>()
    
    private init() {
        // Configure URL cache for better performance
        urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50MB memory
            diskCapacity: 200 * 1024 * 1024,     // 200MB disk
            diskPath: "MyChannelCache"
        )
        URLCache.shared = urlCache
        
        setupNetworkMonitoring()
        configureRequestQueue()
        setupMemoryWarningObserver()
    }
    
    // ⚡ PERFORMANCE: Clear caches on memory warning
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ [NetworkOptimizer] Memory warning - clearing caches")
            self?.clearCaches()
        }
    }
    
    private func clearCaches() {
        urlCache.removeAllCachedResponses()
        imageRequestCache.removeAllObjects()
        pendingRequests.values.forEach { $0.cancel() }
        pendingRequests.removeAll()
        print("✅ [NetworkOptimizer] Caches cleared")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.updateConnectionQuality(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionQuality(_ path: NWPath) {
        if path.isExpensive {
            connectionQuality = .poor
        } else if path.usesInterfaceType(.cellular) {
            connectionQuality = .good
        } else if path.usesInterfaceType(.wifi) {
            connectionQuality = .excellent
        } else {
            connectionQuality = .poor
        }
        
        adjustRequestBehavior()
    }
    
    private func adjustRequestBehavior() {
        switch connectionQuality {
        case .poor:
            requestQueue.maxConcurrentOperationCount = 2
            // Reduce image quality requests
            ImageQualityManager.shared.setMaxQuality(NetworkImageQuality.low)
        case .good:
            requestQueue.maxConcurrentOperationCount = 4
            ImageQualityManager.shared.setMaxQuality(NetworkImageQuality.medium)
        case .excellent:
            requestQueue.maxConcurrentOperationCount = 8
            ImageQualityManager.shared.setMaxQuality(NetworkImageQuality.high)
        }
    }
    
    // MARK: - Request Queue Configuration
    private func configureRequestQueue() {
        requestQueue.maxConcurrentOperationCount = 6
        requestQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Optimized Request Methods
    func optimizedRequest(
        for url: URL,
        priority: RequestPriority = .normal,
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
    ) async throws -> Data {
        
        // Check cache first
        let request = URLRequest(url: url, cachePolicy: cachePolicy)
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            return cachedResponse.data
        }
        
        // Create optimized request
        var optimizedRequest = request
        optimizedRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        optimizedRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
        optimizedRequest.timeoutInterval = timeoutForPriority(priority)
        
        // Execute request with retry logic
        return try await executeWithRetry(optimizedRequest, priority: priority)
    }
    
    // ⚡ PERFORMANCE: Overload for custom requests (POST, headers, body)
    func optimizedRequest(
        for request: URLRequest,
        priority: RequestPriority = .normal
    ) async throws -> Data {
        // POST requests shouldn't be cached
        if request.httpMethod == "POST" {
            var optimizedRequest = request
            optimizedRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
            optimizedRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
            optimizedRequest.timeoutInterval = timeoutForPriority(priority)
            optimizedRequest.cachePolicy = .reloadIgnoringLocalCacheData
            
            return try await executeWithRetry(optimizedRequest, priority: priority)
        }
        
        // For GET requests, check cache first
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            return cachedResponse.data
        }
        
        // Create optimized request
        var optimizedRequest = request
        optimizedRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        optimizedRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
        optimizedRequest.timeoutInterval = timeoutForPriority(priority)
        
        return try await executeWithRetry(optimizedRequest, priority: priority)
    }
    
    private func executeWithRetry(
        _ request: URLRequest,
        priority: RequestPriority,
        maxRetries: Int = 3
    ) async throws -> Data {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse,
                      200...299 ~= httpResponse.statusCode else {
                    throw NetworkOptimizerError.invalidResponse
                }
                
                return data
            } catch {
                lastError = error
                
                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkOptimizerError.unknown
    }
    
    private func timeoutForPriority(_ priority: RequestPriority) -> TimeInterval {
        switch priority {
        case .critical: return 5.0
        case .high: return 10.0
        case .normal: return 15.0
        case .low: return 30.0
        }
    }
    
    // MARK: - Image Loading Optimization
    func optimizedImageRequest(
        for url: URL,
        targetSize: CGSize? = nil
    ) async throws -> UIImage {
        
        let cacheKey = NSString(string: url.absoluteString)
        
        // Check memory cache
        if let cached = imageRequestCache.object(forKey: cacheKey) {
            if let image = UIImage(data: cached.data) {
                return image
            }
        }
        
        // Optimize image URL based on connection quality
        let optimizedURL = optimizeImageURL(url, targetSize: targetSize)
        
        let data = try await optimizedRequest(for: optimizedURL, priority: .high)
        
        guard let image = UIImage(data: data) else {
            throw NetworkOptimizerError.invalidImageData
        }
        
        // Cache the response
        let cachedResponse = CachedResponse(data: data, timestamp: Date())
        imageRequestCache.setObject(cachedResponse, forKey: cacheKey)
        
        return image
    }
    
    private func optimizeImageURL(_ url: URL, targetSize: CGSize?) -> URL {
        // For services that support dynamic resizing (like YouTube thumbnails)
        if url.host?.contains("ytimg.com") == true {
            switch connectionQuality {
            case .poor:
                return url.appendingPathComponent("mqdefault.jpg")
            case .good:
                return url.appendingPathComponent("hqdefault.jpg")
            case .excellent:
                return url.appendingPathComponent("maxresdefault.jpg")
            }
        }
        
        return url
    }
    
    // MARK: - Request Cancellation
    func cancelRequest(for identifier: String) {
        pendingRequests[identifier]?.cancel()
        pendingRequests.removeValue(forKey: identifier)
    }
    
    func cancelAllRequests() {
        pendingRequests.values.forEach { $0.cancel() }
        pendingRequests.removeAll()
    }
    
    // MARK: - Batch Requests
    func batchRequests<T>(
        urls: [URL],
        transform: @escaping (Data) throws -> T
    ) async throws -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { group in
            var results: [T] = []
            
            for url in urls {
                group.addTask {
                    let data = try await self.optimizedRequest(for: url)
                    return try transform(data)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Preloading
    func preloadResources(_ urls: [URL]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(5) { // Limit concurrent preloads
                    group.addTask {
                        do {
                            let _ = try await self.optimizedRequest(
                                for: url,
                                priority: .low,
                                cachePolicy: .returnCacheDataDontLoad
                            )
                        } catch {
                            // Ignore preload errors
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types
enum ConnectionQuality {
    case poor, good, excellent
}

enum RequestPriority {
    case critical, high, normal, low
}

enum NetworkOptimizerError: Error {
    case invalidResponse
    case invalidImageData
    case timeout
    case unknown
}

class CachedResponse {
    let data: Data
    let timestamp: Date
    
    init(data: Data, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - Image Quality Manager
class ImageQualityManager {
    static let shared = ImageQualityManager()
    
    private var maxQuality: NetworkImageQuality = .high
    
    func setMaxQuality(_ quality: NetworkImageQuality) {
        maxQuality = quality
    }
    
    func getOptimalSize(for originalSize: CGSize) -> CGSize {
        let scale = UIScreen.main.scale
        
        switch maxQuality {
        case .low:
            return CGSize(
                width: min(originalSize.width, 320 * scale),
                height: min(originalSize.height, 240 * scale)
            )
        case .medium:
            return CGSize(
                width: min(originalSize.width, 640 * scale),
                height: min(originalSize.height, 480 * scale)
            )
        case .high:
            return originalSize
        }
    }
}

enum NetworkImageQuality {
    case low, medium, high
}

// MARK: - Network-Aware View Modifier
struct NetworkAwareModifier: ViewModifier {
    @StateObject private var networkOptimizer = NetworkOptimizer.shared
    
    func body(content: Content) -> some View {
        content
            .onChange(of: networkOptimizer.connectionQuality) { quality in
                adjustViewForNetworkQuality(quality)
            }
    }
    
    private func adjustViewForNetworkQuality(_ quality: ConnectionQuality) {
        switch quality {
        case .poor:
            // Disable animations, reduce image quality
            UIView.setAnimationsEnabled(false)
        case .good:
            // Enable basic animations
            UIView.setAnimationsEnabled(true)
        case .excellent:
            // Enable all features
            UIView.setAnimationsEnabled(true)
        }
    }
}

extension View {
    func networkAware() -> some View {
        modifier(NetworkAwareModifier())
    }
}
