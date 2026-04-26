import Foundation
import Combine

@MainActor
final class OfferPersonalizationService: ObservableObject {
    static let shared = OfferPersonalizationService()

    struct PersonalizedOffer: Identifiable, Codable {
        let id: String
        let viewerId: String
        let offerTitle: String
        let rankScore: Double
        let discountSensitivity: Double
        let fatigueRisk: Double
    }

    @Published private(set) var offers: [PersonalizedOffer] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableOfferPersonalization else { return }

        offers = [
            PersonalizedOffer(id: UUID().uuidString, viewerId: "viewer_1", offerTitle: "Creator bundle", rankScore: 0.84, discountSensitivity: 0.62, fatigueRisk: 0.14),
            PersonalizedOffer(id: UUID().uuidString, viewerId: "viewer_2", offerTitle: "Annual membership", rankScore: 0.77, discountSensitivity: 0.48, fatigueRisk: 0.21)
        ]
    }
}
