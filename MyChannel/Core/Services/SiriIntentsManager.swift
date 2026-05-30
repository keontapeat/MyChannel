import Foundation
import Intents

/// Phase 77: Siri Intents & Shortcuts Integration
/// Manages Siri Shortcuts for the app.
@MainActor
final class SiriIntentsManager {
    static let shared = SiriIntentsManager()
    
    private init() {}
    
    /// Donates a shortcut to iOS so it appears in Spotlight and Siri Suggestions
    func donatePlayRecommendedIntent() {
        // Note: In a real project, you define a custom INIntent in an .intentdefinition file.
        // E.g., PlayRecommendedVideoIntent
        // For this implementation without the graphical Xcode editor, we use NSUserActivity as a fallback.
        
        let activity = NSUserActivity(activityType: "com.mychannel.playRecommended")
        activity.title = "Play Recommended Videos"
        activity.userInfo = ["action": "playFeed"]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        // activity.suggestedInvocationPhrase = "Play MyChannel"
        
        activity.becomeCurrent()
        print("🎙️ [SiriIntents] Donated 'Play Recommended Videos' shortcut to Siri.")
    }
    
    /// Handles incoming intents from AppDelegate or SceneDelegate
    func handle(userActivity: NSUserActivity) -> Bool {
        if userActivity.activityType == "com.mychannel.playRecommended" {
            print("🎙️ [SiriIntents] Siri requested to play recommended videos. Routing...")
            // Route to the feed...
            return true
        }
        return false
    }
}
