//
//  OptimizedSeekManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation
import UIKit

/// ⚡ YouTube-Level Optimized Seeking
/// Fast seeking with thumbnail previews
@MainActor
class OptimizedSeekManager {
    static let shared = OptimizedSeekManager()
    
    // MARK: - Properties
    private var isSeeking = false
    private var thumbnailCache: [String: [TimeInterval: UIImage]] = [:]
    private var imageGenerators: [String: AVAssetImageGenerator] = [:]
    
    // MARK: - Initialization
    private init() {
        print("✅ [Seek] OptimizedSeekManager initialized")
    }
    
    // MARK: - Seeking
    
    /// Optimized seek to specific time
    func seek(player: AVPlayer, to time: TimeInterval, completion: (() -> Void)? = nil) {
        guard !isSeeking else {
            print("⏭️ [Seek] Already seeking, skipping")
            return
        }
        
        isSeeking = true
        print("⏩ [Seek] Seeking to \(String(format: "%.1f", time))s")
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Seek to nearest keyframe for speed (2 second tolerance)
        player.seek(
            to: cmTime,
            toleranceBefore: .zero,
            toleranceAfter: CMTime(seconds: 2, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self = self, finished else {
                self?.isSeeking = false
                return
            }
            
            print("✅ [Seek] Completed to \(String(format: "%.1f", time))s")
            self.isSeeking = false
            completion?()
        }
    }
    
    /// Precise seek (slower, for exact positioning)
    func preciseSeek(player: AVPlayer, to time: TimeInterval, completion: (() -> Void)? = nil) {
        guard !isSeeking else { return }
        
        isSeeking = true
        print("🎯 [Seek] Precise seek to \(String(format: "%.1f", time))s")
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Precise seek (no tolerance)
        player.seek(
            to: cmTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard let self = self, finished else {
                self?.isSeeking = false
                return
            }
            
            print("✅ [Seek] Precise seek completed")
            self.isSeeking = false
            completion?()
        }
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generate thumbnail for scrubbing preview
    func generateThumbnail(player: AVPlayer, at time: TimeInterval) async -> UIImage? {
        guard let asset = player.currentItem?.asset else {
            print("❌ [Thumbnail] No asset available")
            return nil
        }
        
        // Check cache first
        if let cached = getCachedThumbnail(asset: asset, time: time) {
            return cached
        }
        
        print("🖼️ [Thumbnail] Generating for \(String(format: "%.1f", time))s")
        
        // Get or create image generator
        let generator = getImageGenerator(for: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 90) // Thumbnail size
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        do {
            let (cgImage, _) = try await generator.image(at: cmTime)
            let uiImage = UIImage(cgImage: cgImage)
            
            // Cache thumbnail
            cacheThumbnail(uiImage, for: asset, at: time)
            
            print("✅ [Thumbnail] Generated successfully")
            return uiImage
        } catch {
            print("❌ [Thumbnail] Generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generate multiple thumbnails for scrubbing track
    func generateThumbnails(player: AVPlayer, count: Int = 10) async -> [TimeInterval: UIImage] {
        guard let asset = player.currentItem?.asset else {
            print("❌ [Thumbnails] No asset available")
            return [:]
        }
        
        let duration = try? await asset.load(.duration)
        guard let duration = duration else {
            print("❌ [Thumbnails] Could not get duration")
            return [:]
        }
        
        let durationSeconds = CMTimeGetSeconds(duration)
        let interval = durationSeconds / Double(count)
        
        print("🖼️ [Thumbnails] Generating \(count) thumbnails")
        
        var thumbnails: [TimeInterval: UIImage] = [:]
        
        for i in 0..<count {
            let time = interval * Double(i)
            if let thumbnail = await generateThumbnail(player: player, at: time) {
                thumbnails[time] = thumbnail
            }
        }
        
        print("✅ [Thumbnails] Generated \(thumbnails.count) thumbnails")
        return thumbnails
    }
    
    // MARK: - Cache Management
    
    private func getImageGenerator(for asset: AVAsset) -> AVAssetImageGenerator {
        let assetId = "\(asset.hashValue)"
        
        if let generator = imageGenerators[assetId] {
            return generator
        }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        imageGenerators[assetId] = generator
        return generator
    }
    
    private func cacheThumbnail(_ image: UIImage, for asset: AVAsset, at time: TimeInterval) {
        let assetId = "\(asset.hashValue)"
        
        if thumbnailCache[assetId] == nil {
            thumbnailCache[assetId] = [:]
        }
        
        thumbnailCache[assetId]?[time] = image
    }
    
    private func getCachedThumbnail(asset: AVAsset, time: TimeInterval) -> UIImage? {
        let assetId = "\(asset.hashValue)"
        return thumbnailCache[assetId]?[time]
    }
    
    /// Clear thumbnail cache
    func clearCache() {
        thumbnailCache.removeAll()
        imageGenerators.removeAll()
        print("🧹 [Seek] Thumbnail cache cleared")
    }
    
    /// Clear cache for specific asset
    func clearCache(for asset: AVAsset) {
        let assetId = "\(asset.hashValue)"
        thumbnailCache.removeValue(forKey: assetId)
        imageGenerators.removeValue(forKey: assetId)
        print("🗑️ [Seek] Cleared cache for asset")
    }
    
    deinit {
        clearCache()
    }
}

