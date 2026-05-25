import Foundation
import Combine

@MainActor
final class PurchaseIntentService: ObservableObject {
    static let shared = PurchaseIntentService()

    struct PurchaseIntentSignal: Identifiable, Codable {
        let id: String
        let viewerId: String
        let category: String
        let intentScore: Double
        let readinessWindow: String
        let recommendedAction: String
    }

    @Published private(set) var signals: [PurchaseIntentSignal] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enablePurchaseIntent else { return }

        signals = [
            PurchaseIntentSignal(id: UUID().uuidString, viewerId: "viewer_1", category: "Creator Gear", intentScore: 0.79, readinessWindow: "48h", recommendedAction: "show bundle offer"),
            PurchaseIntentSignal(id: UUID().uuidString, viewerId: "viewer_2", category: "Fitness", intentScore: 0.66, readinessWindow: "7d", recommendedAction: "delay promotion")
        ]
    }
}
