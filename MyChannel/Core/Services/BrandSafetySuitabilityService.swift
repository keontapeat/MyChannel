import Foundation
import Combine

@MainActor
final class BrandSafetySuitabilityService: ObservableObject {
    static let shared = BrandSafetySuitabilityService()

    struct SuitabilityDecision: Identifiable, Codable {
        let id: String
        let contentId: String
        let safetyTier: String
        let suitabilityScore: Double
        let routingDecision: String
        let reasons: [String]
    }

    @Published private(set) var decisions: [SuitabilityDecision] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableBrandSafetySuitability else { return }

        decisions = [
            SuitabilityDecision(id: UUID().uuidString, contentId: "video-home-1", safetyTier: "standard", suitabilityScore: 0.92, routingDecision: "full_monetization", reasons: ["safe topic", "trusted creator"]),
            SuitabilityDecision(id: UUID().uuidString, contentId: "video-news-7", safetyTier: "limited", suitabilityScore: 0.58, routingDecision: "sensitive_only", reasons: ["breaking news context"])
        ]
    }
}
