import Foundation
#if canImport(UIKit)
import StoreKit
#endif

final class ReviewGateService {
    static let shared = ReviewGateService()
    private init() {}
    
    // 🔥 FIX: Track when we last showed rating prompt to prevent spam
    private var lastRatingPromptDate: Date? {
        get {
            if let timestamp = UserDefaults.standard.object(forKey: "lastRatingPromptDate") as? Date {
                return timestamp
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastRatingPromptDate")
        }
    }
    
    // 🔥 FIX: Only show rating prompt once per month maximum
    private let minimumDaysBetweenPrompts = 30

    func checkEligibilityAndPrompt(userId: String?) async {
        // 🔥 REMOVED: Rating popup is too annoying - users can rate manually from Settings
        // This function is now a no-op to prevent any rating prompts
        return
        
        // OLD CODE (disabled):
        /*
        guard let userId = userId else { return }
        
        // 🔥 FIX: Check if we've shown rating prompt recently
        if let lastPrompt = lastRatingPromptDate {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if daysSinceLastPrompt < minimumDaysBetweenPrompts {
                print("📊 [ReviewGate] Rating prompt shown \(daysSinceLastPrompt) days ago - skipping (min: \(minimumDaysBetweenPrompts) days)")
                return
            }
        }
        
        // TODO: Call Cloud Function /reviews/eligibility and, if eligible, present SKStoreReviewController
        #if canImport(UIKit)
        await MainActor.run {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                lastRatingPromptDate = Date()
                print("📊 [ReviewGate] Rating prompt shown")
            }
        }
        #endif
        */
    }
}



