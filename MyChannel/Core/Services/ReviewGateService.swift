import Foundation
#if canImport(UIKit)
import StoreKit
#endif

final class ReviewGateService {
    static let shared = ReviewGateService()
    private init() {}

    func checkEligibilityAndPrompt(userId: String?) async {
        guard let userId = userId else { return }
        // TODO: Call Cloud Function /reviews/eligibility and, if eligible, present SKStoreReviewController
        #if canImport(UIKit)
        await MainActor.run {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
        #endif
    }
}



