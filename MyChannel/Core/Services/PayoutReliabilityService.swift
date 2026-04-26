import Foundation
import Combine

@MainActor
final class PayoutReliabilityService: ObservableObject {
    static let shared = PayoutReliabilityService()

    struct PayoutHealth: Identifiable, Codable {
        let id: String
        let provider: String
        let queueDepth: Int
        let averageSettlementHours: Double
        let sLAStatus: String
        let incidentState: String
    }

    @Published private(set) var payoutHealth: [PayoutHealth] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enablePayoutReliability else { return }

        payoutHealth = [
            PayoutHealth(id: UUID().uuidString, provider: "Primary Processor", queueDepth: 12, averageSettlementHours: 18, sLAStatus: "healthy", incidentState: "none"),
            PayoutHealth(id: UUID().uuidString, provider: "Backup Processor", queueDepth: 4, averageSettlementHours: 26, sLAStatus: "warning", incidentState: "degraded" )
        ]
    }
}
