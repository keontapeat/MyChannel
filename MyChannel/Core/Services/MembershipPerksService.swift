import Foundation
import Combine

@MainActor
final class MembershipPerksService: ObservableObject {
    static let shared = MembershipPerksService()

    struct MembershipPerk: Identifiable, Codable {
        let id: String
        let tierName: String
        let perkName: String
        let entitlementState: String
        let usageRate: Double
        let fulfillmentStatus: String
    }

    @Published private(set) var perks: [MembershipPerk] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableMembershipPerks else { return }

        perks = [
            MembershipPerk(id: UUID().uuidString, tierName: "Gold", perkName: "Member badges", entitlementState: "active", usageRate: 0.74, fulfillmentStatus: "healthy"),
            MembershipPerk(id: UUID().uuidString, tierName: "Platinum", perkName: "Exclusive posts", entitlementState: "active", usageRate: 0.58, fulfillmentStatus: "healthy")
        ]
    }
}
