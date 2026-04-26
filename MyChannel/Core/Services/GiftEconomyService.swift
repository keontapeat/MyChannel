import Foundation
import Combine

@MainActor
final class GiftEconomyService: ObservableObject {
    static let shared = GiftEconomyService()

    struct GiftMoment: Identifiable, Codable {
        let id: String
        let creatorId: String
        let momentType: String
        let giftCount: Int
        let fraudRisk: Double
        let conversionLift: Double
    }

    @Published private(set) var giftMoments: [GiftMoment] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableGiftEconomy else { return }

        giftMoments = [
            GiftMoment(id: UUID().uuidString, creatorId: "creator_1", momentType: "livestream milestone", giftCount: 43, fraudRisk: 0.03, conversionLift: 0.18),
            GiftMoment(id: UUID().uuidString, creatorId: "creator_2", momentType: "member celebration", giftCount: 17, fraudRisk: 0.02, conversionLift: 0.11)
        ]
    }
}
