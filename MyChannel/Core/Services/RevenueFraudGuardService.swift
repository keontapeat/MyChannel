import Foundation
import Combine

@MainActor
final class RevenueFraudGuardService: ObservableObject {
    static let shared = RevenueFraudGuardService()

    struct FraudCase: Identifiable, Codable {
        let id: String
        let source: String
        let riskScore: Double
        let suspectedPattern: String
        let enforcementAction: String
        let createdAt: Date
    }

    @Published private(set) var fraudCases: [FraudCase] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableRevenueFraudGuard else { return }

        fraudCases = [
            FraudCase(id: UUID().uuidString, source: "invalid_traffic", riskScore: 0.91, suspectedPattern: "burst impressions", enforcementAction: "hold revenue", createdAt: Date()),
            FraudCase(id: UUID().uuidString, source: "gift abuse", riskScore: 0.74, suspectedPattern: "self-gifting ring", enforcementAction: "manual review", createdAt: Date())
        ]
    }
}
