import Foundation
import AVFoundation
import UIKit

struct ViewabilityMetrics {
    let adId: String
    let impressionId: String
    let viewableTime: TimeInterval
    let totalDuration: TimeInterval
    let viewabilityPercentage: Double
    let isViewable: Bool
    let geometryData: GeometryData
    
    struct GeometryData {
        let adViewBounds: CGRect
        let screenBounds: CGRect
        let visiblePercentage: Double
    }
}

@MainActor
final class OMIDViewabilityService: ObservableObject {
    static let shared = OMIDViewabilityService()
    private init() {}
    
    private var activeImpressions: [String: ViewabilitySession] = [:]
    
    private struct ViewabilitySession {
        let adId: String
        let impressionId: String
        let startTime: Date
        var lastViewableCheck: Date
        var viewableTime: TimeInterval
        let adView: UIView?
    }
    
    func startImpression(adId: String, adView: UIView?) -> String {
        let impressionId = UUID().uuidString
        let session = ViewabilitySession(
            adId: adId,
            impressionId: impressionId,
            startTime: Date(),
            lastViewableCheck: Date(),
            viewableTime: 0,
            adView: adView
        )
        
        activeImpressions[impressionId] = session
        
        // Start viewability tracking
        startViewabilityTracking(for: impressionId)
        
        return impressionId
    }
    
    func endImpression(impressionId: String) -> ViewabilityMetrics? {
        guard let session = activeImpressions.removeValue(forKey: impressionId) else { return nil }
        
        let totalDuration = Date().timeIntervalSince(session.startTime)
        let viewabilityPercentage = totalDuration > 0 ? session.viewableTime / totalDuration : 0
        let isViewable = viewabilityPercentage >= 0.5 && session.viewableTime >= 1.0 // IAB standard
        
        let geometryData = ViewabilityMetrics.GeometryData(
            adViewBounds: session.adView?.bounds ?? .zero,
            screenBounds: (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds ?? CGRect(x: 0, y: 0, width: 390, height: 844),
            visiblePercentage: calculateVisiblePercentage(adView: session.adView)
        )
        
        let metrics = ViewabilityMetrics(
            adId: session.adId,
            impressionId: impressionId,
            viewableTime: session.viewableTime,
            totalDuration: totalDuration,
            viewabilityPercentage: viewabilityPercentage,
            isViewable: isViewable,
            geometryData: geometryData
        )
        
        // Report to analytics
        Task {
            await reportViewabilityMetrics(metrics)
        }
        
        return metrics
    }
    
    private func startViewabilityTracking(for impressionId: String) {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            guard var session = self.activeImpressions[impressionId] else {
                timer.invalidate()
                return
            }
            
            if self.isAdViewable(session.adView) {
                let now = Date()
                let timeSinceLastCheck = now.timeIntervalSince(session.lastViewableCheck)
                session.viewableTime += timeSinceLastCheck
                session.lastViewableCheck = now
                self.activeImpressions[impressionId] = session
            } else {
                session.lastViewableCheck = Date()
                self.activeImpressions[impressionId] = session
            }
        }
    }
    
    private func isAdViewable(_ adView: UIView?) -> Bool {
        guard let adView = adView else { return false }
        guard let window = adView.window else { return false }
        
        // Check if view is on screen
        let visibleRect = adView.convert(adView.bounds, to: window)
        let screenBounds = window.bounds
        let intersection = visibleRect.intersection(screenBounds)
        
        // IAB viewability standard: 50% of pixels in view
        let visibleArea = intersection.width * intersection.height
        let totalArea = adView.bounds.width * adView.bounds.height
        
        return totalArea > 0 && (visibleArea / totalArea) >= 0.5
    }
    
    private func calculateVisiblePercentage(adView: UIView?) -> Double {
        guard let adView = adView else { return 0 }
        guard let window = adView.window else { return 0 }
        
        let visibleRect = adView.convert(adView.bounds, to: window)
        let screenBounds = window.bounds
        let intersection = visibleRect.intersection(screenBounds)
        
        let visibleArea = intersection.width * intersection.height
        let totalArea = adView.bounds.width * adView.bounds.height
        
        return totalArea > 0 ? visibleArea / totalArea : 0
    }
    
    private func reportViewabilityMetrics(_ metrics: ViewabilityMetrics) async {
        // Report to backend analytics
        do {
            let data = [
                "adId": metrics.adId,
                "impressionId": metrics.impressionId,
                "viewableTime": metrics.viewableTime,
                "totalDuration": metrics.totalDuration,
                "viewabilityPercentage": metrics.viewabilityPercentage,
                "isViewable": metrics.isViewable,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            // Would send to analytics endpoint
            print("📊 OMID Metrics: \(data)")
        }
    }
}
