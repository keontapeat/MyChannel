import Foundation
import Combine

/// Phase 28: Interactive Video Overlays
/// Triggers interactive UI elements (Polls, Links, Annotations) at specific video timestamps.
@MainActor
final class InteractiveOverlayEngine: ObservableObject {
    static let shared = InteractiveOverlayEngine()
    
    @Published var activeOverlay: VideoOverlay?
    
    private var allOverlays: [VideoOverlay] = []
    
    private init() {}
    
    /// Load overlays for a specific video
    func loadOverlays(for videoId: String) {
        // Mock data for Phase 28
        allOverlays = [
            VideoOverlay(id: UUID().uuidString, videoId: videoId, startTime: 15.0, endTime: 25.0, type: .poll("What happens next?", ["Explosion", "Nothing", "A kiss"])),
            VideoOverlay(id: UUID().uuidString, videoId: videoId, startTime: 60.0, endTime: 70.0, type: .link("Buy Merch!", "https://merch.example.com"))
        ]
    }
    
    /// Call this inside the video player's time observer
    func checkTime(_ currentTime: Double) {
        if let current = activeOverlay {
            if currentTime < current.startTime || currentTime > current.endTime {
                activeOverlay = nil
            }
        }
        
        if activeOverlay == nil {
            if let match = allOverlays.first(where: { currentTime >= $0.startTime && currentTime <= $0.endTime }) {
                activeOverlay = match
            }
        }
    }
    
    func clear() {
        activeOverlay = nil
        allOverlays.removeAll()
    }
}

struct VideoOverlay: Identifiable {
    let id: String
    let videoId: String
    let startTime: Double
    let endTime: Double
    let type: OverlayType
    
    enum OverlayType {
        case poll(String, [String]) // Question, Options
        case link(String, String) // Title, URL
        case infoCard(String) // Text
    }
}
