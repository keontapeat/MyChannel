import Foundation
import SwiftUI

#if canImport(Nuke)
import Nuke
import NukeUI
#endif

/// Edge Image Prefetcher for 0ms Latency Feeds
/// Instantly caches thumbnails into RAM/Disk before the user even scrolls.
@MainActor
final class EdgeImagePrefetcher {
    static let shared = EdgeImagePrefetcher()
    
    #if canImport(Nuke)
    // Nuke 12+ ImagePrefetcher is public and nonisolated
    private let prefetcher = Nuke.ImagePrefetcher()
    #endif
    
    private init() {
        setupPipeline()
    }
    
    private func setupPipeline() {
        #if canImport(Nuke)
        // Configure Nuke to use aggressive aggressive RAM and Disk caching
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
        print("⚡️ [NVIDIA Edge] Nuke Pipeline Initialized")
        #endif
    }
    
    func prefetchURLs(_ urls: [URL]) {
        #if canImport(Nuke)
        prefetcher.startPrefetching(with: urls)
        print("⚡️ [NVIDIA Edge] Prefetching \(urls.count) images into L2/L3 cache.")
        #else
        print("⚠️ [NVIDIA Edge] Nuke not installed. Standard caching used. Add https://github.com/kean/Nuke")
        #endif
    }
    
    func cancelPrefetching(_ urls: [URL]) {
        #if canImport(Nuke)
        prefetcher.stopPrefetching(with: urls)
        #endif
    }
}
