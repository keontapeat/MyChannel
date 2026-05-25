import Foundation
import Combine

@MainActor
final class RefundRiskService: ObservableObject {
    static let shared = RefundRiskService()

    struct RefundRiskSnapshot: Identifiable, Codable {
        let id: String
        let productName: String
        let refundRate: Double
        let riskScore: Double
        let rootCause: String
        let recommendation: String
    }

    @Published private(set) var snapshots: [RefundRiskSnapshot] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableRefundRisk else { return }

        snapshots = [
            RefundRiskSnapshot(id: UUID().uuidString, productName: "Annual Membership", refundRate: 0.032, riskScore: 0.27, rootCause: "expectation mismatch", recommendation: "improve perks messaging"),
            RefundRiskSnapshot(id: UUID().uuidString, productName: "Gift Membership", refundRate: 0.018, riskScore: 0.15, rootCause: "accidental purchase", recommendation: "confirm intent before purchase")
        ]
    }
}
