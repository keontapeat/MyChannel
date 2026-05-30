import Foundation

/// Phase 64: Smart Pre-caching based on ML Recommendations
/// Pre-downloads the first 3 seconds (or a specific byte range) of recommended videos into URLCache.
@MainActor
final class SmartPrecacheEngine {
    static let shared = SmartPrecacheEngine()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        // Create a large disk cache for our video chunks (500 MB)
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 500 * 1024 * 1024, diskPath: "video_precache")
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }
    
    /// Pre-caches the initial byte range of the given URLs
    func prefetchTopRecommendations(urls: [URL]) {
        for url in urls {
            Task.detached {
                await self.downloadInitialChunk(for: url)
            }
        }
    }
    
    private func downloadInitialChunk(for url: URL) async {
        var request = URLRequest(url: url)
        // Request the first 2 MB (roughly 3-5 seconds of 1080p video)
        request.setValue("bytes=0-2000000", forHTTPHeaderField: "Range")
        
        // Check if already cached
        if session.configuration.urlCache?.cachedResponse(for: request) != nil {
            print("⚡️ [SmartPrecache] Already cached initial chunk for \(url.lastPathComponent)")
            return
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 206 || httpResponse.statusCode == 200 {
                print("📥 [SmartPrecache] Successfully pre-cached initial chunk for \(url.lastPathComponent)")
            }
        } catch {
            print("⚠️ [SmartPrecache] Failed to pre-cache \(url.lastPathComponent): \(error)")
        }
    }
}
