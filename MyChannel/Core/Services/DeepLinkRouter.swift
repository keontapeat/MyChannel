import Foundation
import Combine

/// Phase 63: Video Deep Linking & Universal Links
/// Parses incoming URLs (e.g., https://mychannel.app/watch?v=123&t=120) and routes the app state.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var targetVideoId: String?
    @Published var targetTimestamp: Double?
    @Published var targetVSMatchId: String?
    @Published var targetMovieId: String?
    
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

        // Example: https://mychannel.app/medals/vs-match?id=MATCH123
        //          mychannel://vs-match?id=MATCH123
        if components.path == "/medals/vs-match" || components.path == "/vs-match" {
            let queryItems = components.queryItems ?? []
            if let matchId = queryItems.first(where: { $0.name == "id" })?.value {
                targetVSMatchId = matchId
                print("🔗 [DeepLinkRouter] Routing to VS Match \(matchId)")
                return true
            }
        }

        // Example: https://mychannel.app/movie?id=tmdb-12345
        if components.path == "/movie" {
            let queryItems = components.queryItems ?? []
            if let movieId = queryItems.first(where: { $0.name == "id" })?.value {
                targetMovieId = movieId
                print("🔗 [DeepLinkRouter] Routing to movie \(movieId)")
                return true
            }
        }
        
        return false
    }
    
    func clearRoutingState() {
        targetVideoId = nil
        targetTimestamp = nil
        targetVSMatchId = nil
        targetMovieId = nil
    }
}
