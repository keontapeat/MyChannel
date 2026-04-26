import Foundation
import Combine

@MainActor
final class CheckoutRecoveryService: ObservableObject {
    static let shared = CheckoutRecoveryService()

    struct CheckoutRecoveryCase: Identifiable, Codable {
        let id: String
        let checkoutId: String
        let abandonmentStage: String
        let frictionReason: String
        let rescueStrategy: String
        let recoveryProbability: Double
    }

    @Published private(set) var recoveryCases: [CheckoutRecoveryCase] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableCheckoutRecovery else { return }

        recoveryCases = [
            CheckoutRecoveryCase(id: UUID().uuidString, checkoutId: "co_1", abandonmentStage: "payment", frictionReason: "high price sensitivity", rescueStrategy: "offer bundle", recoveryProbability: 0.41),
            CheckoutRecoveryCase(id: UUID().uuidString, checkoutId: "co_2", abandonmentStage: "shipping", frictionReason: "address friction", rescueStrategy: "save cart reminder", recoveryProbability: 0.28)
        ]
    }
}
