import Foundation
import Combine
import StoreKit

/// Phase 82: App Clip Support
/// Entry point handler for when the user launches an App Clip via NFC or QR Code.
@MainActor
final class AppClipRouter: ObservableObject {
    static let shared = AppClipRouter()
    
    @Published var isRunningInAppClip: Bool = false
    @Published var targetVideoId: String?
    
    private init() {
        // We can check if we are in an app clip by checking if the main bundle ID ends with .Clip
        if let bundleId = Bundle.main.bundleIdentifier, bundleId.hasSuffix(".Clip") {
            isRunningInAppClip = true
        }
    }
    
    /// Handles the incoming URL from the App Clip invocation
    func handleInvocation(url: URL) {
        guard isRunningInAppClip else { return }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        // e.g. https://mychannel.app/clip?v=123
        if components.path == "/clip" {
            let queryItems = components.queryItems ?? []
            if let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                self.targetVideoId = videoId
                print("✂️ [AppClip] Invoked App Clip for video: \(videoId)")
            }
        }
    }
    
    /// Presents the SKOverlay to prompt the user to download the full app
    func presentFullAppDownloadOverlay(in scene: UIWindowScene) {
        guard isRunningInAppClip else { return }
        
        let config = SKOverlay.AppClipConfiguration(position: .bottom)
        let overlay = SKOverlay(configuration: config)
        overlay.present(in: scene)
        print("✂️ [AppClip] Prompting user to download full app.")
    }
}
