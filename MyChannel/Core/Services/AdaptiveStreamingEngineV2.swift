// AdaptiveStreamingEngineV2.swift - 📶 PERFECT QUALITY!
import Foundation
class AdaptiveStreamingEngineV2 {
    static let shared = AdaptiveStreamingEngineV2()
    func adaptQuality(networkSpeed: Double) -> String {
        if networkSpeed > 10 { return "4K" }
        else if networkSpeed > 5 { return "1080p" }
        else { return "720p" }
    }
}
