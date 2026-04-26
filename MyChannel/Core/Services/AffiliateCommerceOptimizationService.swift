import Foundation
import Combine

@MainActor
final class AffiliateCommerceOptimizationService: ObservableObject {
    static let shared = AffiliateCommerceOptimizationService()

    struct AffiliateOffer: Identifiable, Codable {
        let id: String
        let merchant: String
        let category: String
        let conversionRate: Double
        let liftEstimate: Double
        let recommendation: String
    }

    @Published private(set) var offers: [AffiliateOffer] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableAffiliateCommerceOptimization else { return }

        offers = [
            AffiliateOffer(id: UUID().uuidString, merchant: "GearHub", category: "Creator Tech", conversionRate: 0.038, liftEstimate: 0.14, recommendation: "feature in setup videos"),
            AffiliateOffer(id: UUID().uuidString, merchant: "FitFuel", category: "Lifestyle", conversionRate: 0.024, liftEstimate: 0.09, recommendation: "bundle with shorts CTA")
        ]
    }
}
