import Foundation
import Combine

@MainActor
final class SubscriptionRetentionService: ObservableObject {
    static let shared = SubscriptionRetentionService()

    struct RetentionCohort: Identifiable, Codable {
        let id: String
        let cohort: String
        let renewalRate: Double
        let churnRisk: Double
        let averageTenureMonths: Double
    }

    @Published private(set) var cohorts: [RetentionCohort] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableSubscriptionRetention else { return }

        cohorts = [
            RetentionCohort(id: UUID().uuidString, cohort: "Monthly - 0 to 3 months", renewalRate: 0.63, churnRisk: 0.31, averageTenureMonths: 2.1),
            RetentionCohort(id: UUID().uuidString, cohort: "Annual - 12+ months", renewalRate: 0.84, churnRisk: 0.11, averageTenureMonths: 16.4)
        ]
    }
}
