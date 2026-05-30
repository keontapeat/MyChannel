import Foundation
import Combine

/// Phase 63: Video Deep Linking & Universal Links
/// Parses incoming URLs (e.g., https://mychannel.app/watch?v=123&t=120) and routes the app state.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var targetVideoId: String?
    @Published var targetTimestamp: Double?
    
    private init() {}
    
    /// Called from SwiftUI's `.onOpenURL` or AppDelegate/SceneDelegate
    func handle(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        // Example: https://mychannel.app/watch?v=ABC123XYZ&t=45
        if components.path == "/watch" {
            let queryItems = components.queryItems ?? []
            
            if let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                self.targetVideoId = videoId
                
                if let timestampString = queryItems.first(where: { $0.name == "t" })?.value,
                   let timestamp = Double(timestampString) {
                    self.targetTimestamp = timestamp
                }
                
                print("🔗 [DeepLinkRouter] Routing to video \(videoId) at t=\(targetTimestamp ?? 0)s")
                return true
            }
        }
        
        return false
    }
    
    func clearRoutingState() {
        targetVideoId = nil
        targetTimestamp = nil
    }
}
