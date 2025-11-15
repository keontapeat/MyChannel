//
//  VideoPlaybackReadinessService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation
import UIKit

@MainActor
final class VideoPlaybackReadinessService {
    static let shared = VideoPlaybackReadinessService()
    private init() {}
    
    func prepareForPlayback(video: Video) async {
        guard !video.videoURL.isEmpty else { return }
        
        do {
            try await pollUntilPlayable(videoURL: video.videoURL)
        } catch {
            print("⚠️ [PlaybackReady] Timed out waiting for playable stream: \(error)")
        }
        
        await preloadThumbnailIfNeeded(video.thumbnailURL)
        VideoPlayerManager.prewarm(urlString: video.videoURL)
    }
    
    private func pollUntilPlayable(videoURL: String, attempts: Int = 5) async throws {
        guard let url = URL(string: videoURL) else { return }
        for attempt in 0..<attempts {
            if await isPlayable(url: url) {
                print("✅ [PlaybackReady] Stream ready after \(attempt + 1) checks")
                return
            }
            
            let delay = pow(2.0, Double(attempt)) * 0.5 // exponential backoff (0.5s, 1s, 2s, 4s…)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        throw PlaybackReadinessError.timeout
    }
    
    private func isPlayable(url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            return playable
        } catch {
            return false
        }
    }
    
    private func preloadThumbnailIfNeeded(_ urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15
        _ = try? await URLSession.shared.data(for: request)
    }
}

enum PlaybackReadinessError: Error {
    case timeout
}

