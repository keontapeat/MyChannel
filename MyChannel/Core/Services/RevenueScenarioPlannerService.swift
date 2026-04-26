import Foundation
import Combine

@MainActor
final class RevenueScenarioPlannerService: ObservableObject {
    static let shared = RevenueScenarioPlannerService()

    struct RevenueScenario: Identifiable, Codable {
        let id: String
        let name: String
        let adRevenue: Double
        let subscriptionRevenue: Double
        let commerceRevenue: Double
        let totalRevenue: Double
    }

    @Published private(set) var scenarios: [RevenueScenario] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableRevenueScenarioPlanner else { return }

        scenarios = [
            RevenueScenario(id: UUID().uuidString, name: "Base Case", adRevenue: 12400, subscriptionRevenue: 4200, commerceRevenue: 1800, totalRevenue: 18400),
            RevenueScenario(id: UUID().uuidString, name: "Growth Push", adRevenue: 14100, subscriptionRevenue: 5600, commerceRevenue: 2400, totalRevenue: 22100)
        ]
    }
}
