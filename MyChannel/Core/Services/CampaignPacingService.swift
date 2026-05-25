import Foundation
import Combine

@MainActor
final class CampaignPacingService: ObservableObject {
    static let shared = CampaignPacingService()

    struct CampaignPacingSnapshot: Identifiable, Codable {
        let id: String
        let campaignName: String
        let spendProgress: Double
        let deliveryProgress: Double
        let pacingStatus: String
        let recoveryAction: String
    }

    @Published private(set) var campaigns: [CampaignPacingSnapshot] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableCampaignPacing else { return }

        campaigns = [
            CampaignPacingSnapshot(id: UUID().uuidString, campaignName: "Summer Launch", spendProgress: 0.44, deliveryProgress: 0.39, pacingStatus: "underdelivering", recoveryAction: "increase eligible inventory"),
            CampaignPacingSnapshot(id: UUID().uuidString, campaignName: "Brand Burst", spendProgress: 0.68, deliveryProgress: 0.71, pacingStatus: "on_track", recoveryAction: "none")
        ]
    }
}
