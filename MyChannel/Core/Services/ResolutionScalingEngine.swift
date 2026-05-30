import Foundation
import AVFoundation
import UIKit

/// Phase 51: Dynamic Resolution Scaling Engine
/// Monitors AVPlayerItem.presentationSize to dynamically cap maximum bitrate and resolution based on actual rendered view size.
@MainActor
final class ResolutionScalingEngine: ObservableObject {
    static let shared = ResolutionScalingEngine()
    
    private var presentationSizeObserver: NSKeyValueObservation?
    private weak var currentItem: AVPlayerItem?
    
    private init() {}
    
    /// Starts monitoring the size of the given player item and adjusts bitrate constraints dynamically
    func attach(to item: AVPlayerItem) {
        // Remove existing observer
        presentationSizeObserver?.invalidate()
        self.currentItem = item
        
        presentationSizeObserver = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, change in
            Task { @MainActor in
                self?.handlePresentationSizeChange(item: item)
            }
        }
    }
    
    func detach() {
        presentationSizeObserver?.invalidate()
        presentationSizeObserver = nil
        currentItem = nil
    }
    
    private func handlePresentationSizeChange(item: AVPlayerItem) {
        let size = item.presentationSize
        
        guard size.width > 0 && size.height > 0 else { return }
        
        let screenScale = UIScreen.main.scale
        // Estimate the maximum pixels being rendered physically on screen
        let maxRenderedPixels = size.width * size.height * screenScale * screenScale
        
        // Dynamically cap bitrate based on the bounds:
        // E.g., if rendering in a tiny PiP window, don't download 4K streams
        var maxBitrate: Double = 0
        
        if maxRenderedPixels < 400_000 {
            // Smaller than 480p roughly -> Cap at 1.5 Mbps
            maxBitrate = 1_500_000
        } else if maxRenderedPixels < 1_000_000 {
            // Smaller than 720p roughly -> Cap at 3.0 Mbps
            maxBitrate = 3_000_000
        } else if maxRenderedPixels < 2_500_000 {
            // Smaller than 1080p roughly -> Cap at 6.0 Mbps
            maxBitrate = 6_000_000
        } else {
            // 4K or above -> No cap or 20 Mbps cap
            maxBitrate = 20_000_000
        }
        
        if item.preferredPeakBitRate != maxBitrate {
            item.preferredPeakBitRate = maxBitrate
            print("📉 [ResolutionScaling] Capped peak bitrate to \(maxBitrate / 1_000_000) Mbps based on presentation size: \(size)")
        }
    }
}
