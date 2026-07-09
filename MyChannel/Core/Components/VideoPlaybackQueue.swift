//
//  VideoPlaybackQueue.swift
//  MyChannel
//
//  Extracted queue + preload coordination from GlobalVideoPlayerManager.
//  Keeps Up Next / previous / next logic testable without the full player stack.
//

import Foundation
import AVFoundation

/// Value-type queue for Up Next navigation. Owned by `GlobalVideoPlayerManager`.
struct VideoPlaybackQueue: Equatable {
    var videos: [Video] = []
    var index: Int = 0

    var current: Video? {
        guard index >= 0, index < videos.count else { return nil }
        return videos[index]
    }

    var upNext: Video? {
        guard index + 1 < videos.count else { return nil }
        return videos[index + 1]
    }

    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index + 1 < videos.count }

    mutating func set(queue: [Video], startingAt video: Video) {
        if queue.isEmpty {
            videos = [video]
            index = 0
            return
        }
        videos = queue
        if let found = queue.firstIndex(where: { $0.id == video.id }) {
            index = found
        } else {
            videos.insert(video, at: 0)
            index = 0
        }
    }

    mutating func append(_ video: Video) {
        guard !videos.contains(where: { $0.id == video.id }) else { return }
        if videos.isEmpty {
            videos = [video]
            index = 0
        } else {
            videos.append(video)
        }
    }

    @discardableResult
    mutating func advance() -> Video? {
        guard hasNext else { return nil }
        index += 1
        return current
    }

    @discardableResult
    mutating func retreat() -> Video? {
        guard hasPrevious else { return nil }
        index -= 1
        return current
    }

    mutating func reset() {
        videos = []
        index = 0
    }
}

/// Lightweight asset preloader used by the global player for instant Up Next.
@MainActor
final class VideoAssetPreloader {
    private(set) var preloadedAsset: AVURLAsset?
    private var preloadTask: Task<Void, Never>?

    func cancel() {
        preloadTask?.cancel()
        preloadTask = nil
        preloadedAsset = nil
    }

    func takePreloadedAsset() -> AVURLAsset? {
        let asset = preloadedAsset
        preloadedAsset = nil
        return asset
    }

    func preload(urlString: String) {
        guard let assetURL = URL(string: urlString) else { return }
        preloadTask?.cancel()
        preloadTask = Task { [weak self] in
            let options: [String: Any] = [
                AVURLAssetPreferPreciseDurationAndTimingKey: false,
                "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-524287"]
            ]
            let asset = AVURLAsset(url: assetURL, options: options)
            asset.resourceLoader.preloadsEligibleContentKeys = true
            async let tracks = asset.load(.tracks)
            async let isPlayable = asset.load(.isPlayable)
            _ = try? await (tracks, isPlayable)
            await MainActor.run { [weak self] in
                self?.preloadedAsset = asset
            }
        }
    }
}
